#!/bin/bash
set -e

TOMCAT_VERSION="10.1.73"
TOMCAT_DIR="/opt/apache-tomcat-$TOMCAT_VERSION"
WAR_SOURCE="/home/ec2-user/artifact/Ecomm.war"
TOMCAT_USERS="/home/ec2-user/artifact/tomcat-users.xml"
APP_NAME="Ecomm"
DEST_DIR="$TOMCAT_DIR/webapps/$APP_NAME"

# 1. Install Java and dependencies
echo "[INFO] Installing Java and required packages..."
yum install -y java-17-amazon-corretto wget tar || true

# 2. Install Tomcat if not installed
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "[INFO] Installing Tomcat $TOMCAT_VERSION..."
    wget https://archive.apache.org/dist/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -P /tmp
    tar -xzf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C /opt
    chmod +x $TOMCAT_DIR/bin/*.sh

    # Create systemd service if missing
    if [ ! -f /etc/systemd/system/tomcat.service ]; then
        cat <<EOF >/etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking
User=root
ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable tomcat
    fi
fi

# 3. Stop Tomcat
echo "[INFO] Stopping Tomcat..."
if pgrep -f tomcat; then
    $TOMCAT_DIR/bin/shutdown.sh || true
    sleep 5
fi

# 4. Deploy WAR (only if changed)
mkdir -p $DEST_DIR
if [ ! -f $DEST_DIR/ROOT.war ] || ! cmp -s $WAR_SOURCE $DEST_DIR/ROOT.war; then
    rm -rf $DEST_DIR/*
    cp $WAR_SOURCE $DEST_DIR/ROOT.war
    chown -R root:root $DEST_DIR
    echo "[INFO] WAR deployed/updated."
else
    echo "[INFO] WAR unchanged. Skipping copy."
fi

# 5. Update tomcat-users.xml (only if changed)
if [ ! -f $TOMCAT_DIR/conf/tomcat-users.xml ] || ! cmp -s $TOMCAT_USERS $TOMCAT_DIR/conf/tomcat-users.xml; then
    cp $TOMCAT_USERS $TOMCAT_DIR/conf/tomcat-users.xml
    echo "[INFO] tomcat-users.xml updated."
else
    echo "[INFO] tomcat-users.xml unchanged."
fi

# 6. Start Tomcat
echo "[INFO] Starting Tomcat..."
$TOMCAT_DIR/bin/startup.sh

echo "[SUCCESS] Deployment completed! Access your app at /$APP_NAME"
