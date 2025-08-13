#!/bin/bash
set -e

TOMCAT_VERSION="10.1.73"
TOMCAT_DIR="/opt/apache-tomcat-$TOMCAT_VERSION"
WAR_SOURCE="/home/ec2-user/Ecomm.war"
TOMCAT_USERS="/home/ec2-user/tomcat-users.xml"
APP_NAME="Ecomm"

# 1. Install Java and Tomcat if not installed
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "[INFO] Installing Java and Tomcat..."
    yum install -y java-17-amazon-corretto wget tar
    wget https://downloads.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -P /tmp
    tar -xzf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C /opt
    chmod +x $TOMCAT_DIR/bin/*.sh

    # Optional: create systemd service
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

# 2. Stop Tomcat
echo "[INFO] Stopping Tomcat..."
$TOMCAT_DIR/bin/shutdown.sh || true
sleep 5

# 3. Deploy WAR to subpath
echo "[INFO] Deploying $APP_NAME.war..."
DEST_DIR="$TOMCAT_DIR/webapps/$APP_NAME"
mkdir -p $DEST_DIR
rm -rf $DEST_DIR/*
cp $WAR_SOURCE $DEST_DIR/ROOT.war
chown -R root:root $DEST_DIR

# 4. Configure tomcat-users.xml
echo "[INFO] Configuring Tomcat manager authentication..."
cp $TOMCAT_USERS $TOMCAT_DIR/conf/tomcat-users.xml

# 5. Start Tomcat
echo "[INFO] Starting Tomcat..."
$TOMCAT_DIR/bin/startup.sh

echo "[SUCCESS] Deployment completed! Access your app at /$APP_NAME"
