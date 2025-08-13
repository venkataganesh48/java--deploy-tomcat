#!/bin/bash
set -e

TOMCAT_VERSION=9.0.86
TOMCAT_DIR="/opt/tomcat"
WAR_SRC="/home/ec2-user/Ecomm.war"
USERS_XML_SRC="/home/ec2-user/tomcat-users.xml"

echo "[INFO] Starting deployment script..."

# 1. Install Java if not present
if ! java -version &>/dev/null; then
    echo "[INFO] Installing Java 11..."
    yum install -y java-11-amazon-corretto
else
    echo "[INFO] Java already installed."
fi

# 2. Install Tomcat only if not installed
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "[INFO] Installing Tomcat $TOMCAT_VERSION..."
    cd /tmp
    curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
    mkdir -p $TOMCAT_DIR
    tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $TOMCAT_DIR --strip-components=1

    # Make scripts executable
    chmod +x $TOMCAT_DIR/bin/*.sh

    # Create systemd service
    cat <<EOF >/etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=CATALINA_PID=${TOMCAT_DIR}/temp/tomcat.pid
Environment=CATALINA_HOME=${TOMCAT_DIR}
Environment=CATALINA_BASE=${TOMCAT_DIR}
ExecStart=${TOMCAT_DIR}/bin/startup.sh
ExecStop=${TOMCAT_DIR}/bin/shutdown.sh
User=root
Group=root
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tomcat
    echo "[INFO] Tomcat installed successfully."
else
    echo "[INFO] Tomcat already installed. Skipping installation."
fi

# 3. Stop Tomcat before deployment
echo "[INFO] Stopping Tomcat..."
systemctl stop tomcat || true

# 4. Deploy WAR
echo "[INFO] Deploying Ecomm.war..."
rm -rf $TOMCAT_DIR/webapps/Ecomm
rm -f $TOMCAT_DIR/webapps/Ecomm.war
cp $WAR_SRC $TOMCAT_DIR/webapps/

# 5. Update tomcat-users.xml
if [ -f "$USERS_XML_SRC" ]; then
    echo "[INFO] Updating tomcat-users.xml..."
    cp $USERS_XML_SRC $TOMCAT_DIR/conf/tomcat-users.xml
else
    echo "[WARN] tomcat-users.xml not found in repo!"
fi

# 6. Start Tomcat
echo "[INFO] Starting Tomcat..."
systemctl start tomcat

echo "[INFO] Deployment completed successfully!"
