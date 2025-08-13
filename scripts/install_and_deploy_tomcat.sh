#!/bin/bash
set -e
set -x

TOMCAT_VERSION=9.0.88
TOMCAT_DIR=/opt/tomcat

# 1️⃣ Install Java 11 if missing
if ! java -version &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto
fi

# 2️⃣ Install Tomcat if missing
sudo mkdir -p /opt
cd /opt/
if [ ! -d "$TOMCAT_DIR" ]; then
  sudo curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
  sudo chmod +x /opt/tomcat/bin/*.sh
  sudo chown -R ec2-user:ec2-user /opt/tomcat
fi

sudo mkdir -p /opt/tomcat/temp
sudo chown -R ec2-user:ec2-user /opt/tomcat/temp

# 3️⃣ Copy tomcat-users.xml from repo
sudo cp /home/ec2-user/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml
sudo chown ec2-user:ec2-user /opt/tomcat/conf/tomcat-users.xml

# 4️⃣ Create systemd service
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
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
fi

# 5️⃣ Stop Tomcat
sudo systemctl stop tomcat || true

# 6️⃣ Deploy WAR
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/${WAR_NAME}"
TARGET_WAR="/opt/tomcat/webapps/${WAR_NAME}"
APP_DIR="/opt/tomcat/webapps/Ecomm"

sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
else
  echo "WAR file not found!"
  exit 1
fi

# 7️⃣ Start Tomcat
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat
