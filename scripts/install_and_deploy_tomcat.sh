#!/bin/bash
set -e
TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat
WAR_FILE=$TOMCAT_DIR/latest/webapps/Ecomm.war
TOMCAT_USERS_FILE=$TOMCAT_DIR/latest/conf/tomcat-users.xml

echo "===== Starting Tomcat Install & Deployment Script ====="

# Fallback: If no LIFECYCLE_EVENT provided, run full deployment
if [ -z "$LIFECYCLE_EVENT" ]; then
    echo "No LIFECYCLE_EVENT detected — running full install & deployment process."

    # Stop Tomcat
    if systemctl is-active --quiet tomcat; then
        echo "Stopping Tomcat..."
        sudo systemctl stop tomcat
    fi

    # Install Java if missing
    if ! command -v java &>/dev/null; then
        echo "Installing Amazon Corretto 11..."
        sudo yum install -y java-11-amazon-corretto
    fi

    # Install Tomcat if missing
    if [ ! -d "$TOMCAT_DIR" ]; then
        echo "Installing Tomcat $TOMCAT_VERSION..."
        sudo mkdir -p $TOMCAT_DIR
        cd /tmp
        curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
        sudo tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $TOMCAT_DIR
        sudo ln -s $TOMCAT_DIR/apache-tomcat-${TOMCAT_VERSION} $TOMCAT_DIR/latest
        sudo chmod +x $TOMCAT_DIR/latest/bin/*.sh
    fi

    # Create systemd service if missing
    if [ ! -f /etc/systemd/system/tomcat.service ]; then
        echo "Creating Tomcat systemd service..."
        sudo bash -c "cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID=$TOMCAT_DIR/latest/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_DIR/latest
Environment=CATALINA_BASE=$TOMCAT_DIR/latest
ExecStart=$TOMCAT_DIR/latest/bin/startup.sh
ExecStop=$TOMCAT_DIR/latest/bin/shutdown.sh
User=ec2-user
Group=ec2-user
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF"
        sudo systemctl daemon-reload
        sudo systemctl enable tomcat
    fi

    sudo chown -R ec2-user:ec2-user $TOMCAT_DIR

    # Verify files
    if [ ! -f "$WAR_FILE" ]; then
        echo "ERROR: WAR file missing at $WAR_FILE"
        exit 1
    fi
    if [ ! -f "$TOMCAT_USERS_FILE" ]; then
        echo "ERROR: tomcat-users.xml missing at $TOMCAT_USERS_FILE"
        exit 1
    fi

    # Start Tomcat
    echo "Starting Tomcat..."
    sudo systemctl start tomcat

    # Validate
    echo "Validating Tomcat..."
    sleep 10
    if systemctl is-active --quiet tomcat; then
        echo "Tomcat is running successfully."
    else
        echo "Tomcat failed to start!"
        exit 1
    fi

    echo "===== Full Deployment Completed ====="
    exit 0
fi

# If LIFECYCLE_EVENT is set, run per-hook logic
echo "Lifecycle Event: $LIFECYCLE_EVENT"

case "$LIFECYCLE_EVENT" in

  ApplicationStop)
    echo "Stopping Tomcat..."
    if systemctl is-active --quiet tomcat; then
        sudo systemctl stop tomcat
    else
        echo "Tomcat is not running."
    fi
    ;;

  BeforeInstall)
    if ! command -v java &>/dev/null; then
        echo "Installing Amazon Corretto 11..."
        sudo yum install -y java-11-amazon-corretto
    fi

    if [ ! -d "$TOMCAT_DIR" ]; then
        echo "Installing Tomcat $TOMCAT_VERSION..."
        sudo mkdir -p $TOMCAT_DIR
        cd /tmp
        curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
        sudo tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $TOMCAT_DIR
        sudo ln -s $TOMCAT_DIR/apache-tomcat-${TOMCAT_VERSION} $TOMCAT_DIR/latest
        sudo chmod +x $TOMCAT_DIR/latest/bin/*.sh
    fi

    if [ ! -f /etc/systemd/system/tomcat.service ]; then
        echo "Creating Tomcat systemd service..."
        sudo bash -c "cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID=$TOMCAT_DIR/latest/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_DIR/latest
Environment=CATALINA_BASE=$TOMCAT_DIR/latest
ExecStart=$TOMCAT_DIR/latest/bin/startup.sh
ExecStop=$TOMCAT_DIR/latest/bin/shutdown.sh
User=ec2-user
Group=ec2-user
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF"
        sudo systemctl daemon-reload
        sudo systemctl enable tomcat
    fi

    sudo chown -R ec2-user:ec2-user $TOMCAT_DIR
    ;;

  AfterInstall)
    echo "Verifying WAR and tomcat-users.xml..."
    if [ ! -f "$WAR_FILE" ]; then
        echo "ERROR: WAR file missing at $WAR_FILE"
        exit 1
    fi
    if [ ! -f "$TOMCAT_USERS_FILE" ]; then
        echo "ERROR: tomcat-users.xml missing at $TOMCAT_USERS_FILE"
        exit 1
    fi
    ;;

  ApplicationStart)
    echo "Starting Tomcat..."
    sudo systemctl start tomcat
    ;;

  ValidateService)
    echo "Validating Tomcat..."
    sleep 10
    if systemctl is-active --quiet tomcat; then
        echo "Tomcat is running successfully."
    else
        echo "Tomcat failed to start!"
        exit 1
    fi
    ;;

  *)
    echo "Unknown lifecycle event: $LIFECYCLE_EVENT"
    exit 1
    ;;
esac

echo "===== Script Completed for $LIFECYCLE_EVENT ====="
