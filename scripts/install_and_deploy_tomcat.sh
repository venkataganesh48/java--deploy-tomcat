#!/bin/bash
set -e
set -x

# -----------------------------
# 1️⃣ Install Java 11 if missing
# -----------------------------
echo "======== Checking and Installing Java 11 ========="
if ! java -version &>/dev/null; then
  echo "Installing Java 11..."
  sudo yum install -y java-11-amazon-corretto
else
  echo "Java is already installed."
fi

# -----------------------------
# 2️⃣ Install Tomcat if missing
# -----------------------------
TOMCAT_VERSION=9.0.88
sudo mkdir -p /opt
cd /opt/

if [ ! -d "/opt/tomcat" ]; then
  echo "Downloading and installing Tomcat..."
  sudo curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
  sudo chmod +x /opt/tomcat/bin/*.sh
  sudo chown -R ec2-user:ec2-user /opt/tomcat
else
  echo "Tomcat is already installed. Skipping installation."
fi

# Make sure temp folder exists
sudo mkdir -p /opt/tomcat/temp
sudo chown -R ec2-user:ec2-user /opt/tomcat/temp

# -----------------------------
# 3️⃣ Copy your tomcat-users.xml from repo
# -----------------------------
echo "======== Copying tomcat-users.xml from repo ========="
if [ -f /home/ec2-user/tomcat-users.xml ]; then
  sudo cp /home/ec2-user/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml
  sudo chown ec2-user:ec2-user /opt/tomcat/conf/tomcat-users.xml
  echo "✅ tomcat-users.xml copied"
else
  echo "❌ tomcat-users.xml not found in /home/ec2-user/"
  exit 1
fi

# -----------------------------
# 4️⃣ Create systemd service for Tomcat
# -----------------------------
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
else
  echo "Tomcat systemd service already exists. Skipping creation."
fi

# -----------------------------
# 5️⃣ Stop Tomcat before deployment
# -----------------------------
echo "======== Stopping Tomcat to deploy WAR file ========="
sudo systemctl stop tomcat || true

# -----------------------------
# 6️⃣ Deploy WAR
# -----------------------------
echo "======== Deploying WAR file to Tomcat ========="
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/${WAR_NAME}"
TARGET_WAR="/opt/tomcat/webapps/${WAR_NAME}"
APP_DIR="/opt/tomcat/webapps/Ecomm"

# Remove old deployment
sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "✅ WAR file copied to Tomcat webapps"
else
  echo "❌ WAR file not found at $SOURCE_WAR"
  exit 1
fi

# -----------------------------
# 7️⃣ Start & enable Tomcat
# -----------------------------
echo "======== Starting Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

echo "======== Deployment Complete ========="
