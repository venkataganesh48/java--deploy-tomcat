#!/bin/bash

echo "======== Updating system ========="
sudo yum update -y

echo "======== Installing Java 11 ========="
sudo amazon-linux-extras enable corretto11
sudo yum install -y java-11-amazon-corretto

echo "======== Installing Tomcat ========="
cd /opt/
sudo wget https://downloads.apache.org/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz
sudo tar -xzf apache-tomcat-9.0.85.tar.gz
sudo mv apache-tomcat-9.0.85 tomcat
sudo chmod +x /opt/tomcat/bin/*.sh

echo "======== Creating Tomcat systemd service ========="
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking
User=ec2-user
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "======== Starting and enabling Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

echo "======== Deploying WAR file to Tomcat ========="
WAR_FILE="Ecomm.war"
SOURCE_WAR="/home/ec2-user/$WAR_FILE"
TARGET_WAR="/opt/tomcat/webapps/$WAR_FILE"

if [ -f "$SOURCE_WAR" ]; then
  sudo cp "$SOURCE_WAR" "$TARGET_WAR"
  echo "WAR file deployed to Tomcat."
else
  echo "WAR file not found at $SOURCE_WAR"
  exit 1
fi

echo "======== Restarting Tomcat to reload application ========="
sudo systemctl restart tomcat
