#!/bin/bash
set -e
set -x

# === 1. Install AWS CodeDeploy Agent ===
echo "=== Installing CodeDeploy Agent ==="
sudo yum update -y
sudo yum install -y ruby wget

cd /home/ec2-user
wget https://aws-codedeploy-ap-northeast-3.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent

# === 2. Install Java ===
echo "=== Installing Java ==="
sudo yum install -y java-11-amazon-corretto
java -version

# === 3. Install Tomcat 9 ===
echo "=== Installing Tomcat 9 ==="
TOMCAT_VERSION=9.0.86
cd /opt
sudo curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
sudo tar -xvzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
sudo ln -s apache-tomcat-${TOMCAT_VERSION} tomcat9
sudo chmod +x /opt/tomcat9/bin/*.sh

# === 4. Configure tomcat-users.xml before starting ===
echo "=== Configuring tomcat-users.xml ==="
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

# === 5. Deploy WAR File BEFORE starting tomcat ===
echo "=== Deploying WAR File ==="
[ -f /home/ec2-user/Ecomm.war ] || { echo "❌ Ecomm.war not found!"; exit 1; }
sudo cp /home/ec2-user/Ecomm.war /opt/tomcat9/webapps/

# === 6. Create systemd service ===
echo "=== Creating systemd service for Tomcat ==="
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
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'

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

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable tomcat

# === 7. Start Tomcat ===
sudo systemctl start tomcat

# === 8. Final Output ===
echo "✅ Tomcat deployed. Visit http://<your-ec2-public-ip>:8080/"
echo "➡ Click 'Manager App' -> Login with admin/admin123 -> Find and click 'Ecomm' app"
