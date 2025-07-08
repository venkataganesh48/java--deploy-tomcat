#!/bin/bash
set -e
set -x

echo "======== Installing AWS CodeDeploy Agent ========="
sudo yum update -y
sudo yum install -y ruby wget dos2unix

cd /home/ec2-user
wget https://aws-codedeploy-us-west-2.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl enable codedeploy-agent
sudo systemctl start codedeploy-agent
sudo systemctl status codedeploy-agent || true

echo "======== Installing Java 11 ========="
if ! java -version &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto
else
  echo "✅ Java already installed"
fi

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
TOMCAT_DIR="/opt/tomcat"
if [ ! -d "$TOMCAT_DIR" ]; then
  cd /opt/
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat

  # ✅ Fix permissions
  sudo chmod +x $TOMCAT_DIR/bin/*.sh
  sudo chmod +x $TOMCAT_DIR/bin/*.jar || true
  sudo chmod -R 755 $TOMCAT_DIR
  sudo dos2unix $TOMCAT_DIR/bin/*.sh || true
  sudo chown -R ec2-user:ec2-user $TOMCAT_DIR
else
  echo "✅ Tomcat already installed, skipping."
fi

echo "======== Creating tomcat-users.xml ========="
sudo tee $TOMCAT_DIR/conf/tomcat-users.xml > /dev/null <<EOF
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <user username="admin" password="admin" roles="manager-gui,manager-script,manager-jmx,manager-status"/>
</tomcat-users>
EOF

echo "======== Creating systemd Tomcat service ========="
if [ ! -f "/etc/systemd/system/tomcat.service" ]; then
  sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_HOME=$TOMCAT_DIR
Environment=CATALINA_BASE=$TOMCAT_DIR
ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
fi

echo "======== Stopping Tomcat if running ========="
sudo systemctl stop tomcat || true

echo "======== Deploying WAR file ========="
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/${WAR_NAME}"
TARGET_WAR="$TOMCAT_DIR/webapps/${WAR_NAME}"
APP_DIR="$TOMCAT_DIR/webapps/Ecomm"

sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  sudo chown ec2-user:ec2-user "$TARGET_WAR"
  echo "✅ WAR file deployed."
else
  echo "❌ WAR file not found at $SOURCE_WAR"
  exit 1
fi

echo "======== Starting Tomcat ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

echo "======== ✅ Deployment Complete and Tomcat Running ========="
