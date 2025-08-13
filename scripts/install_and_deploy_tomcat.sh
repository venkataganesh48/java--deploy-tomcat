#!/bin/bash
set -e

TOMCAT_DIR="/opt/apache-tomcat-10.1.42"
WAR_SOURCE="/home/ec2-user/Ecomm.war"
TOMCAT_USERS="/home/ec2-user/tomcat-users.xml"

# 1. Install Java and Tomcat if not installed
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "[INFO] Installing Java and Tomcat..."
    yum install -y java-17-amazon-corretto
    wget https://downloads.apache.org/tomcat/tomcat-10/v10.1.42/bin/apache-tomcat-10.1.42.tar.gz -P /tmp
    tar -xzf /tmp/apache-tomcat-10.1.42.tar.gz -C /opt
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

# 3. Deploy WAR
echo "[INFO] Deploying Ecomm.war..."
cp $WAR_SOURCE $TOMCAT_DIR/webapps/
chown -R root:root $TOMCAT_DIR/webapps/Ecomm.war

# 4. Configure tomcat-users.xml
echo "[INFO] Configuring Tomcat manager authentication..."
cp $TOMCAT_USERS $TOMCAT_DIR/conf/tomcat-users.xml

# 5. Start Tomcat
echo "[INFO] Starting Tomcat..."
$TOMCAT_DIR/bin/startup.sh

echo "[SUCCESS] Deployment completed!"
