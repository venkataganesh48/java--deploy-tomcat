#!/bin/bash
set -e
set -x
# Variables
TOMCAT_VERSION=9.0.88
TOMCAT_DIR=/opt/tomcat
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_NAME"
TOMCAT_USER="ec2-user"
echo "======== Updating system ========="
sudo yum update -y

echo "======== Installing Java 11 ========="
if ! java -version &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto
else
  echo "Java already installed."
fi

# Automatically detect JAVA_HOME
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "Detected JAVA_HOME=$JAVA_HOME_PATH"

echo "======== Installing Tomcat ========="
if [ ! -d "$TOMCAT_DIR" ]; then
    sudo mkdir -p /opt
    cd /opt
    echo "Downloading Tomcat $TOMCAT_VERSION..."
    sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
    sudo tar -xzf apache-tomcat-$TOMCAT_VERSION.tar.gz
    sudo mv apache-tomcat-$TOMCAT_VERSION tomcat
    sudo chmod +x $TOMCAT_DIR/bin/*.sh
    sudo chown -R $TOMCAT_USER:$TOMCAT_USER $TOMCAT_DIR
else
    echo "Tomcat already installed. Skipping installation."
fi

echo "======== Configuring Tomcat Manager and Users ========="
# Deploy tomcat-users.xml
cat <<EOL > /tmp/tomcat-users.xml
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <user username="admin" password="admin" roles="manager-gui,manager-script,manager-jmx,manager-status"/>
</tomcat-users>
EOL

sudo cp /tmp/tomcat-users.xml $TOMCAT_DIR/conf/tomcat-users.xml
sudo chown $TOMCAT_USER:$TOMCAT_USER $TOMCAT_DIR/conf/tomcat-users.xml
echo "✅ tomcat-users.xml deployed correctly."

# Remove RemoteAddrValve for remote access
MANAGER_CONTEXT="$TOMCAT_DIR/webapps/manager/META-INF/context.xml"
sudo sed -i '/RemoteAddrValve/d' "$MANAGER_CONTEXT"
echo "✅ RemoteAddrValve removed for remote manager access."

# Ensure temp and logs directories exist with correct permissions
sudo mkdir -p $TOMCAT_DIR/temp
sudo mkdir -p $TOMCAT_DIR/logs
sudo chown -R $TOMCAT_USER:$TOMCAT_USER $TOMCAT_DIR

echo "======== Creating Tomcat systemd service ========="
if [ ! -f /etc/systemd/system/tomcat.service ]; then
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER

Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=CATALINA_PID=$TOMCAT_DIR/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_DIR
Environment=CATALINA_BASE=$TOMCAT_DIR

ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh

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
TARGET_WAR="$TOMCAT_DIR/webapps/$WAR_NAME"
APP_DIR="$TOMCAT_DIR/webapps/Ecomm"

sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
    sudo cp "$SOURCE_WAR" "$TARGET_WAR"
    echo "✅ WAR file copied to Tomcat webapps."
else
    echo "❌ WAR file not found at $SOURCE_WAR"
    exit 1
fi

echo "======== Starting and Enabling Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

echo "======== Deployment Complete ========="
echo "Tomcat homepage: http://<EC2_PUBLIC_IP>:8080/"
echo "Manager app: http://<EC2_PUBLIC_IP>:8080/manager/html"
echo "Use credentials: username='admin', password='admin'"
