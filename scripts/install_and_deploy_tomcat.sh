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

echo "======== Installing Java 11 ========="
sudo yum install -y java-11-amazon-corretto

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
sudo mkdir -p /opt
cd /opt/

if [ ! -d "/opt/tomcat" ]; then
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
  sudo chmod +x /opt/tomcat/bin/*.sh
  sudo chown -R ec2-user:ec2-user /opt/tomcat
else
  echo "✅ Tomcat already exists. Skipping download."
fi

echo "======== Creating tomcat-users.xml ========="
sudo tee /opt/tomcat/conf/tomcat-users.xml > /dev/null <<EOF
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <user username="admin" password="admin" roles="manager-gui,manager-script"/>
</tomcat-users>
EOF

echo "======== Creating working Tomcat systemd service (foreground mode) ========="
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

ExecStart=/opt/tomcat/bin/catalina.sh run
ExecStop=/opt/tomcat/bin/shutdown.sh

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "======== Stopping Tomcat (if running) ========="
sudo systemctl stop tomcat || true

echo "======== Deploying WAR ========="
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_NAME"
TARGET_WAR="/opt/tomcat/webapps/$WAR_NAME"
APP_DIR="/opt/tomcat/webapps/Ecomm"

sudo rm -rf "$APP_DIR" "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "✅ WAR deployed."
else
  echo "❌ WAR file not found at $SOURCE_WAR"
  exit 1
fi

echo "======== Starting Tomcat via systemd ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

if systemctl is-active --quiet tomcat; then
  echo "✅ Tomcat is running"
else
  echo "❌ Tomcat failed to start"
  sudo journalctl -xeu tomcat.service
  exit 1
fi

echo "======== ✅ Deployment Complete ========="
