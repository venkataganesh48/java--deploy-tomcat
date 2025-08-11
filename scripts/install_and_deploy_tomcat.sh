#!/bin/bash
set -e
TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat
WAR_FILE=/opt/tomcat/latest/webapps/Ecomm.war
TOMCAT_USERS_FILE=/opt/tomcat/latest/conf/tomcat-users.xml

echo "===== Starting Tomcat Install & Deployment Script ====="

# Detect lifecycle event (optional debug)
echo "Running for CodeDeploy lifecycle event: $LIFECYCLE_EVENT"

# 1. Stop Tomcat if running
if systemctl is-active --quiet tomcat; then
    echo "Stopping Tomcat..."
    sudo systemctl stop tomcat
fi

# 2. Install Java if not installed
if ! command -v java &>/dev/null; then
    echo "Installing Amazon Corretto 11..."
    sudo yum install -y java-11-amazon-corretto
fi

# 3. Install Tomcat if not installed
if [ ! -d "$TOMCAT_DIR" ]; then
    echo "Downloading and installing Tomcat $TOMCAT_VERSION..."
    sudo mkdir -p $TOMCAT_DIR
    cd /tmp
    curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
    sudo tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $TOMCAT_DIR
    sudo ln -s $TOMCAT_DIR/apache-tomcat-${TOMCAT_VERSION} $TOMCAT_DIR/latest
    sudo chmod +x $TOMCAT_DIR/latest/bin/*.sh
fi

# 4. Set up systemd service for Tomcat (only once)
if [ ! -f /etc/systemd/system/tomcat.service ]; then
    echo "Creating Tomcat systemd service..."
    sudo bash -c 'cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID='"$TOMCAT_DIR"'/latest/temp/tomcat.pid
Environment=CATALINA_HOME='"$TOMCAT_DIR"'/latest
Environment=CATALINA_BASE='"$TOMCAT_DIR"'/latest
ExecStart='"$TOMCAT_DIR"'/latest/bin/startup.sh
ExecStop='"$TOMCAT_DIR"'/latest/bin/shutdown.sh
User=ec2-user
Group=ec2-user
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat
fi

# 5. Deploy WAR file (already copied by appspec.yml)
if [ -f "$WAR_FILE" ]; then
    echo "WAR file deployed to $WAR_FILE"
else
    echo "ERROR: WAR file missing!"
    exit 1
fi

# 6. Deploy tomcat-users.xml (already copied by appspec.yml)
if [ -f "$TOMCAT_USERS_FILE" ]; then
    echo "Tomcat users file deployed to $TOMCAT_USERS_FILE"
else
    echo "ERROR: tomcat-users.xml missing!"
    exit 1
fi

# 7. Start Tomcat
echo "Starting Tomcat..."
sudo systemctl start tomcat

# 8. Validate Tomcat service
echo "Validating Tomcat..."
sleep 10
if systemctl is-active --quiet tomcat; then
    echo "Tomcat is running successfully."
else
    echo "Tomcat failed to start!"
    exit 1
fi

echo "===== Tomcat Deployment Completed Successfully ====="
