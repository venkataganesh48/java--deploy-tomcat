#!/bin/bash
set -e

TOMCAT_DIR="/opt/tomcat"
WAR_FILE="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_FILE"
SOURCE_TOMCAT_USERS="/home/ec2-user/tomcat-users.xml"
TOMCAT_VERSION="9.0.109"
TOMCAT_ARCHIVE="apache-tomcat-$TOMCAT_VERSION.tar.gz"
TOMCAT_URL="https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/$TOMCAT_ARCHIVE"

sudo yum update -y
sudo yum install -y java-11-amazon-corretto wget tar

if [ ! -d "$TOMCAT_DIR" ]; then
    cd /opt/
    sudo wget $TOMCAT_URL
    sudo tar -xzf $TOMCAT_ARCHIVE
    sudo mv "apache-tomcat-$TOMCAT_VERSION" tomcat
    sudo chmod +x $TOMCAT_DIR/bin/*.sh
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

if [ ! -f "$SOURCE_TOMCAT_USERS" ]; then
    echo "ERROR: tomcat-users.xml missing"
    exit 1
fi
sudo cp "$SOURCE_TOMCAT_USERS" "$TOMCAT_DIR/conf/tomcat-users.xml"

if [ ! -f "$SOURCE_WAR" ]; then
    echo "ERROR: WAR file missing"
    exit 1
fi
sudo cp "$SOURCE_WAR" "$TOMCAT_DIR/webapps/"

sudo systemctl restart tomcat
echo "Deployment completed successfully!"
