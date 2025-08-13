#!/bin/bash
set -e

TOMCAT_DIR="/opt/tomcat"
WAR_FILE="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_FILE"
SOURCE_TOMCAT_USERS="/home/ec2-user/tomcat-users.xml"

TOMCAT_VERSION="9.0.86"
TOMCAT_ARCHIVE="apache-tomcat-$TOMCAT_VERSION.tar.gz"
TOMCAT_URL="https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/$TOMCAT_ARCHIVE"

echo "======== Updating system ========="
sudo yum update -y

echo "======== Installing Java 11 and tools ========="
sudo yum install -y java-11-amazon-corretto wget tar

# Install Tomcat if missing
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "======== Installing Tomcat $TOMCAT_VERSION ========="
    cd /opt
    sudo wget $TOMCAT_URL
    sudo tar -xzf $TOMCAT_ARCHIVE
    sudo mv "apache-tomcat-$TOMCAT_VERSION" tomcat
    sudo chmod +x $TOMCAT_DIR/bin/*.sh

    echo "======== Creating systemd service ========="
    sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking
User=ec2-user
ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat
fi

echo "======== Copying tomcat-users.xml ========="
sudo cp "$SOURCE_TOMCAT_USERS" "$TOMCAT_DIR/conf/tomcat-users.xml"

echo "======== Deploying WAR file ========="
sudo cp "$SOURCE_WAR" "$TOMCAT_DIR/webapps/$WAR_FILE"

echo "======== Restarting Tomcat ========="
sudo systemctl restart tomcat

echo "======== Deployment completed successfully! ========"
