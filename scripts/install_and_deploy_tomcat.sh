#!/bin/bash
set -e
set -x

echo "======== Installing Java 11 ========="
sudo yum install -y java-11-amazon-corretto

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
cd /opt/

# Only install Tomcat if not already installed
if [ ! -d "/opt/tomcat" ]; then
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat

  # Make Tomcat scripts executable
  sudo chmod +x /opt/tomcat/bin/*.sh

  # Set ownership for ec2-user
  sudo chown -R ec2-user:ec2-user /opt/tomcat
else
  echo "✅ Tomcat already installed, skipping..."
fi

# === Create Tomcat systemd service ===
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

# === Start and enable Tomcat ===
echo "======== Starting and enabling Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat

# Check if startup script exists before starting
if [ -f /opt/tomcat/bin/startup.sh ]; then
  sudo systemctl start tomcat
else
  echo "❌ Tomcat startup script not found! Aborting."
  exit 1
fi

# === Deploy WAR file ===
echo "======== Deploying WAR file to Tomcat ========="
WAR_FILE="Ecomm.war"
TARGET_WAR="/opt/tomcat/webapps/${WAR_FILE}"

# Find the actual WAR location from CodeDeploy staging dir
SOURCE_WAR=$(find /opt/codedeploy-agent/deployment-root/ -name "${WAR_FILE}" | head -n 1)

echo "Looking for WAR file at: $SOURCE_WAR"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "✅ WAR file copied to Tomcat webapps."
else
  echo "❌ WAR file not found in deployment directory!"
  exit 1
fi

# === Restart Tomcat after deployment ===
echo "======== Restarting Tomcat to reload new app ========="
sudo systemctl restart tomcat

# === Verify Tomcat is running ===
if systemctl is-active --quiet tomcat; then
  echo "✅ Tomcat is running successfully."
else
  echo "❌ Tomcat failed to start. Run: sudo journalctl -xeu tomcat.service"
  exit 1
fi

echo "======== ✅ Deployment Complete ========="
