#!/bin/bash
set -e
set -x

# === 1. Ensure AWS CodeDeploy Agent is Installed ===
echo "=== Installing CodeDeploy Agent (if not already installed) ==="
if ! systemctl is-active --quiet codedeploy-agent; then
  sudo yum update -y
  sudo yum install -y ruby wget

  cd /home/ec2-user
  wget https://aws-codedeploy-ap-northeast-3.s3.amazonaws.com/latest/install
  chmod +x ./install
  sudo ./install auto
  sudo systemctl start codedeploy-agent
  sudo systemctl enable codedeploy-agent
fi

# === 2. Install Java 11 if not present ===
if ! java -version 2>&1 | grep "11" >/dev/null; then
  echo "=== Installing Java 11 ==="
  sudo yum install -y java-11-amazon-corretto
fi

# === 3. Install Tomcat 9 if not already installed ===
TOMCAT_VERSION=9.0.86
TOMCAT_DIR="/opt/apache-tomcat-${TOMCAT_VERSION}"
if [ ! -d "$TOMCAT_DIR" ]; then
  echo "=== Installing Tomcat $TOMCAT_VERSION ==="
  cd /opt
  sudo curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo ln -s apache-tomcat-${TOMCAT_VERSION} tomcat9
  sudo chmod +x /opt/tomcat9/bin/*.sh

  # === Create systemd service ===
  echo "=== Creating Tomcat systemd service ==="
  sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat9/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat9
Environment=CATALINA_BASE=/opt/tomcat9
ExecStart=/opt/tomcat9/bin/startup.sh
ExecStop=/opt/tomcat9/bin/shutdown.sh
User=ec2-user
Group=ec2-user
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable tomcat
fi

# === 4. Configure Tomcat Manager Access (tomcat-users.xml) ===
echo "=== Configuring Tomcat Manager user ==="
sudo tee /opt/tomcat9/conf/tomcat-users.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
               version="1.0">
  <role rolename="manager-gui"/>
  <role rolename="admin-gui"/>
  <user username="admin" password="admin123" roles="manager-gui,admin-gui"/>
</tomcat-users>
EOF

# === 5. Deploy WAR File (Ecomm.war) ===
echo "=== Deploying Ecomm.war to Tomcat ==="
[ -f /home/ec2-user/Ecomm.war ] || { echo "❌ WAR file not found at /home/ec2-user/Ecomm.war"; exit 1; }

sudo rm -rf /opt/tomcat9/webapps/Ecomm*
sudo cp /home/ec2-user/Ecomm.war /opt/tomcat9/webapps/

# === 6. Start or Restart Tomcat ===
echo "=== Restarting Tomcat ==="
sudo systemctl restart tomcat

# === 7. Final Message with YOUR IP ===
echo "✅ Deployment complete."
echo "🌐 Visit: http://56.155.30.10:8080/ → Tomcat Homepage"
echo "🔐 Login to Manager App: http://56.155.30.10:8080/manager/html (admin / admin123)"
echo "📦 Access your app: http://56.155.30.10:8080/Ecomm"
