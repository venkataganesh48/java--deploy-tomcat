#!/bin/bash
set -e
set -x

echo "======== Installing AWS CodeDeploy Agent ========="
sudo yum update -y
sudo yum install -y ruby wget

cd /home/ec2-user
wget https://aws-codedeploy-ap-northeast-3.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent
sudo systemctl status codedeploy-agent

echo "======== Installing Java 11 if Needed ========="
if ! java -version &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto
fi

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
TOMCAT_DIR="/opt/tomcat"
cd /opt/
if [ ! -d "$TOMCAT_DIR" ]; then
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} "$TOMCAT_DIR"
fi
sudo chown -R ec2-user:ec2-user "$TOMCAT_DIR"
sudo chmod +x "$TOMCAT_DIR"/bin/*.sh

echo "======== Creating Tomcat systemd service ========="
TOMCAT_SERVICE="/etc/systemd/system/tomcat.service"
JAVA_HOME_PATH="/usr/lib/jvm/java-11-amazon-corretto"
if [ ! -f "$TOMCAT_SERVICE" ]; then
  sudo tee "$TOMCAT_SERVICE" > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user
Environment=JAVA_HOME=${JAVA_HOME_PATH}
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
fi

echo "======== Stopping Tomcat Before Deployment ========="
sudo systemctl stop tomcat || true
sudo pkill -f 'org.apache.catalina.startup.Bootstrap' || true

echo "======== Deploying Ecomm.war to Tomcat ========="
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/${WAR_NAME}"
TARGET_WAR="${TOMCAT_DIR}/webapps/${WAR_NAME}"
APP_DIR="${TOMCAT_DIR}/webapps/Ecomm"
sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"
if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
else
  echo "WAR file not found: $SOURCE_WAR"
  exit 1
fi

echo "======== Configuring Tomcat Users and Manager Access ========="
TOMCAT_USERS_FILE="${TOMCAT_DIR}/conf/tomcat-users.xml"
if ! grep -q 'manager-gui' "$TOMCAT_USERS_FILE"; then
  sudo sed -i '/<\/tomcat-users>/i \
<role rolename="manager-gui"/>\n\
<user username="admin" password="admin" roles="manager-gui"/>' "$TOMCAT_USERS_FILE"
fi

MANAGER_CONTEXT_FILE="${TOMCAT_DIR}/webapps/manager/META-INF/context.xml"
if [ -f "$MANAGER_CONTEXT_FILE" ] && grep -q 'RemoteAddrValve' "$MANAGER_CONTEXT_FILE"; then
  sudo sed -i 's/<Valve /<!-- <Valve /' "$MANAGER_CONTEXT_FILE"
  sudo sed -i 's/\/>$/\/> -->/' "$MANAGER_CONTEXT_FILE"
fi

echo "======== Starting Tomcat ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

if sudo systemctl is-active --quiet tomcat; then
  echo "✅ Tomcat started successfully."
else
  echo "❌ Tomcat failed to start. Check with: sudo journalctl -xeu tomcat"
  exit 1
fi

echo "======== Deployment Complete ========="
