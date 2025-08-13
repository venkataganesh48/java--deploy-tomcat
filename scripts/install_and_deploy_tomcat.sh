#!/bin/bash
set -e
set -x

# Variables
TOMCAT_VERSION=9.0.88
TOMCAT_DIR=/opt/tomcat
WAR_NAME=Ecomm.war
SOURCE_WAR=/home/ec2-user/$WAR_NAME
TOMCAT_USERS_SRC=/home/ec2-user/tomcat-users.xml

echo "======== Installing Java 11 (Amazon Corretto) ========="
if ! java -version &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto
else
  echo "Java is already installed."
fi

echo "======== Installing Tomcat ========="
if [ ! -d "$TOMCAT_DIR" ]; then
  sudo mkdir -p /opt
  cd /opt
  echo "Downloading Tomcat ${TOMCAT_VERSION}..."
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
  sudo chmod +x $TOMCAT_DIR/bin/*.sh
  sudo chown -R ec2-user:ec2-user $TOMCAT_DIR
else
  echo "Tomcat is already installed. Skipping installation."
fi

echo "======== Configuring tomcat-users.xml ========="
if [ -f "$TOMCAT_USERS_SRC" ]; then
  sudo cp "$TOMCAT_USERS_SRC" $TOMCAT_DIR/conf/tomcat-users.xml
  sudo chown ec2-user:ec2-user $TOMCAT_DIR/conf/tomcat-users.xml
  echo "tomcat-users.xml copied from repo."
else
  echo "tomcat-users.xml not found in repo, exiting."
  exit 1
fi

echo "======== Creating Tomcat systemd service ========="
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
Environment=CATALINA_PID=${TOMCAT_DIR}/temp/tomcat.pid
Environment=CATALINA_HOME=${TOMCAT_DIR}
Environment=CATALINA_BASE=${TOMCAT_DIR}

ExecStart=${TOMCAT_DIR}/bin/startup.sh
ExecStop=${TOMCAT_DIR}/bin/shutdown.sh

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
else
  echo "Tomcat systemd service already exists. Skipping creation."
fi

echo "======== Stopping Tomcat to deploy WAR file ========="
sudo systemctl stop tomcat || true

echo "======== Deploying WAR file ========="
TARGET_WAR=${TOMCAT_DIR}/webapps/$WAR_NAME
APP_DIR=${TOMCAT_DIR}/webapps/Ecomm

# Clean previous deployment
sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "WAR file deployed to Tomcat."
else
  echo "WAR file not found at $SOURCE_WAR, exiting."
  exit 1
fi

echo "======== Starting and enabling Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

echo "======== Deployment Complete ========="

