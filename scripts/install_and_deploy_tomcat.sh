#!/bin/bash
set -e
set -x

echo "======== Installing Java 11 ========="
sudo yum install -y java-11-amazon-corretto

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
cd /opt/

if [ ! -d "/opt/tomcat" ]; then
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat

  # Set execute permission for Tomcat scripts
  sudo chmod +x /opt/tomcat/bin/*.sh

  # Give ec2-user ownership
  sudo chown -R ec2-user:ec2-user /opt/tomcat
else
  echo "Tomcat is already installed. Skipping reinstallation."
fi

echo "======== Creating Tomcat systemd service ========="
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user

Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "======== Starting and enabling Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

echo "======== Deploying WAR file to Tomcat ========="
WAR_FILE="Ecomm.war"
TARGET_WAR="/opt/tomcat/webapps/${WAR_FILE}"

# Dynamically find WAR file location in CodeDeploy deployment directory
SOURCE_WAR=$(find /opt/codedeploy-agent/deployment-root/ -name "${WAR_FILE}" | head -n 1)

echo "Looking for WAR file at: $SOURCE_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "✅ WAR file deployed to Tomcat."
else
  echo "❌ WAR file not found. Expected at: $SOURCE_WAR"
  exit 1
fi

echo "======== Restarting Tomcat to reload application ========="
sudo systemctl restart tomcat

echo "======== ✅ Deployment Complete ========="
