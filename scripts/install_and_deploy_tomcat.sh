#!/bin/bash
set -e
set -x

echo "======== Installing AWS CodeDeploy Agent ========="
sudo yum update -y
sudo yum install -y ruby wget unzip

cd /home/ec2-user
wget https://aws-codedeploy-us-west-2.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent

echo "======== Checking and Installing Java 11 ========="
if ! java -version &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto
else
  echo "✅ Java is already installed"
fi

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
sudo mkdir -p /opt
cd /opt/

if [ ! -d "/opt/tomcat" ]; then
  echo "Downloading Tomcat..."
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
  sudo chmod -R +x /opt/tomcat/bin
  sudo chown -R ec2-user:ec2-user /opt/tomcat
else
  echo "✅ Tomcat already installed. Skipping installation."
fi

echo "======== Creating tomcat-users.xml with BASIC auth ========="
sudo tee /opt/tomcat/conf/tomcat-users.xml > /dev/null <<EOF
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <user username="admin" password="admin" roles="manager-gui,manager-script"/>
</tomcat-users>
EOF

echo "======== Creating Tomcat systemd service ========="
if [ ! -f "/etc/systemd/system/tomcat.service" ]; then
  sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user

Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
ExecStart=/usr/lib/jvm/java-11-amazon-corretto/bin/java -Djava.security.egd=file:/dev/./urandom -classpath "/opt/tomcat/bin/bootstrap.jar:/opt/tomcat/bin/tomcat-juli.jar" -Dcatalina.base=/opt/tomcat -Dcatalina.home=/opt/tomcat -Djava.io.tmpdir=/opt/tomcat/temp org.apache.catalina.startup.Bootstrap start
ExecStop=/opt/tomcat/bin/shutdown.sh

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
else
  echo "✅ Tomcat systemd service already exists. Skipping."
fi

echo "======== Stopping Tomcat for fresh WAR deployment ========="
sudo systemctl stop tomcat || true

echo "======== Deploying WAR file ========="
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/${WAR_NAME}"
TARGET_WAR="/opt/tomcat/webapps/${WAR_NAME}"
APP_DIR="/opt/tomcat/webapps/Ecomm"

sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "✅ WAR file deployed successfully."
else
  echo "❌ WAR file not found at $SOURCE_WAR"
  exit 1
fi

echo "======== Restarting Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

if systemctl is-active --quiet tomcat; then
  echo "✅ Tomcat is running successfully."
else
  echo "❌ Tomcat failed to start. Check logs using:"
  echo "   sudo journalctl -xeu tomcat.service"
  exit 1
fi

echo "======== ✅ Deployment Complete ========="
