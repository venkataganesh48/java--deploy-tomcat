#!/bin/bash
set -e
set -x

# -----------------------------
# 1. Update system and install Java
# -----------------------------
echo "======== Updating system ========="
sudo yum update -y || true

echo "======== Installing Java 11 ========="
if ! java -version &>/dev/null; then
    sudo yum install -y java-11-amazon-corretto
else
    echo "Java is already installed."
fi

# -----------------------------
# 2. Install Tomcat 9.0.86
# -----------------------------
TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat

echo "======== Installing Tomcat ========="
if [ ! -d "$TOMCAT_DIR" ]; then
    sudo mkdir -p $TOMCAT_DIR
    cd /opt/
    sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
    sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
    sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
    sudo chmod +x $TOMCAT_DIR/bin/*.sh
    sudo chown -R ec2-user:ec2-user $TOMCAT_DIR
else
    echo "Tomcat already installed. Skipping installation."
fi

# -----------------------------
# 3. Copy tomcat-users.xml from repo
# -----------------------------
if [ -f /home/ec2-user/tomcat-users.xml ]; then
    sudo cp /home/ec2-user/tomcat-users.xml $TOMCAT_DIR/conf/tomcat-users.xml
    sudo chown ec2-user:ec2-user $TOMCAT_DIR/conf/tomcat-users.xml
    echo "tomcat-users.xml copied from repo."
else
    echo "tomcat-users.xml not found in repo!"
    exit 1
fi

# -----------------------------
# 4. Create systemd service for Tomcat
# -----------------------------
if [ ! -f /etc/systemd/system/tomcat.service ]; then
    echo "======== Creating Tomcat systemd service ========="
    sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
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

# -----------------------------
# 5. Stop Tomcat (if running)
# -----------------------------
sudo systemctl stop tomcat || true

# -----------------------------
# 6. Deploy WAR file
# -----------------------------
WAR_NAME="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_NAME"
TARGET_WAR="$TOMCAT_DIR/webapps/$WAR_NAME"
APP_DIR="$TOMCAT_DIR/webapps/Ecomm"

# Remove old deployment
sudo rm -rf "$APP_DIR"
sudo rm -f "$TARGET_WAR"

if [ -f "$SOURCE_WAR" ]; then
    sudo cp "$SOURCE_WAR" "$TARGET_WAR"
    echo "✅ WAR file copied to Tomcat webapps."
else
    echo "❌ WAR file not found at $SOURCE_WAR"
    exit 1
fi

# -----------------------------
# 7. Start Tomcat
# -----------------------------
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

echo "======== Deployment Complete ========"
echo "Tomcat homepage: http://<EC2-PUBLIC-IP>:8080"
echo "Ecomm app: http://<EC2-PUBLIC-IP>:8080/Ecomm (login required)"
