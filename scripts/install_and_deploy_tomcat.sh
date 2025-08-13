#!/bin/bash
set -e

# ===== CONFIG =====
TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat
TOMCAT_SYMLINK=$TOMCAT_DIR/latest
WAR_NAME=Ecomm.war
WAR_SRC=/home/ec2-user/$WAR_NAME
WAR_DEST=$TOMCAT_SYMLINK/webapps/$WAR_NAME
TOMCAT_USERS_SRC=/home/ec2-user/tomcat-users.xml
TOMCAT_USERS_DEST=$TOMCAT_SYMLINK/conf/tomcat-users.xml
SERVICE_FILE=/etc/systemd/system/tomcat.service

echo "=== CodeDeploy Hook: $LIFECYCLE_EVENT_NAME ==="

# Install Java if not present
if ! java -version &>/dev/null; then
    echo "[INFO] Installing Java 11..."
    yum install -y java-11-amazon-corretto
fi

# Install Tomcat if not already installed
if [ ! -d "$TOMCAT_SYMLINK" ]; then
    echo "[INFO] Installing Tomcat $TOMCAT_VERSION..."
    mkdir -p $TOMCAT_DIR
    cd $TOMCAT_DIR
    curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
    tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
    ln -s apache-tomcat-${TOMCAT_VERSION} latest
    chmod +x $TOMCAT_SYMLINK/bin/*.sh

    # Create systemd service
    cat <<EOF >$SERVICE_FILE
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID=$TOMCAT_SYMLINK/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_SYMLINK
Environment=CATALINA_BASE=$TOMCAT_SYMLINK
ExecStart=$TOMCAT_SYMLINK/bin/startup.sh
ExecStop=$TOMCAT_SYMLINK/bin/shutdown.sh
User=root
Group=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tomcat
fi

# Stop Tomcat before deployment
if systemctl is-active --quiet tomcat; then
    echo "[INFO] Stopping Tomcat..."
    systemctl stop tomcat
fi

# Remove old WAR & exploded folder
echo "[INFO] Cleaning old deployment..."
rm -f $WAR_DEST
rm -rf $TOMCAT_SYMLINK/webapps/${WAR_NAME%.war}

# Copy new WAR
echo "[INFO] Deploying new WAR..."
cp $WAR_SRC $WAR_DEST

# Copy tomcat-users.xml
echo "[INFO] Updating Tomcat users..."
cp $TOMCAT_USERS_SRC $TOMCAT_USERS_DEST

# Start Tomcat
echo "[INFO] Starting Tomcat..."
systemctl start tomcat

echo "=== Deployment Completed Successfully ==="
