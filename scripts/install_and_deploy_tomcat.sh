#!/bin/bash
set -e   # Exit immediately if a command fails

# Paths
TOMCAT_DIR="/opt/tomcat"
WAR_FILE="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_FILE"
SOURCE_TOMCAT_USERS="/home/ec2-user/tomcat-users.xml"

# Set the Tomcat version to a valid current version
TOMCAT_VERSION="9.0.96"
TOMCAT_ARCHIVE="apache-tomcat-$TOMCAT_VERSION.tar.gz"
TOMCAT_URL="https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/$TOMCAT_ARCHIVE"

echo "======== Updating system ========="
sudo yum update -y

echo "======== Installing Java 11 and tools ========="
sudo yum install -y java-11-amazon-corretto wget tar

# Install Tomcat if not already installed
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "======== Installing Tomcat $TOMCAT_VERSION ========="
    cd /opt/
    sudo wget $TOMCAT_URL
    sudo tar -xzf $TOMCAT_ARCHIVE
    sudo mv "apache-tomcat-$TOMCAT_VERSION" tomcat
    sudo chmod +x $TOMCAT_DIR/bin/*.sh

    # Check if systemd exists
    if command -v systemctl >/dev/null 2>&1; then
        echo "======== Creating Tomcat systemd service ========="
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
    else
        echo "Systemd not found, using init.d for Tomcat"
        sudo cp $TOMCAT_DIR/bin/catalina.sh /etc/init.d/tomcat
        sudo chmod +x /etc/init.d/tomcat
        sudo chkconfig --add tomcat
    fi
fi

echo "======== Copying tomcat-users.xml ========="
if [ -f "$SOURCE_TOMCAT_USERS" ]; then
    sudo cp "$SOURCE_TOMCAT_USERS" "$TOMCAT_DIR/conf/tomcat-users.xml"
    echo "tomcat-users.xml copied to Tomcat conf directory."
else
    echo "ERROR: tomcat-users.xml not found at $SOURCE_TOMCAT_USERS"
    exit 1
fi

echo "======== Deploying WAR file ========="
if [ -f "$SOURCE_WAR" ]; then
    sudo cp "$SOURCE_WAR" "$TOMCAT_DIR/webapps/$WAR_FILE"
    echo "WAR file deployed to Tomcat."
else
    echo "ERROR: WAR file not found at $SOURCE_WAR"
    exit 1
fi

echo "======== Restarting Tomcat ========="
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl restart tomcat
else
    sudo service tomcat stop || true
    sudo service tomcat start
fi

echo "======== Deployment completed successfully! ========"
