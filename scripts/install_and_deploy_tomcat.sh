#!/bin/bash
set -e
set -x

# Install Java
sudo yum install -y java-11-amazon-corretto

# Install Tomcat only if not already installed
TOMCAT_VERSION=9.0.86
if [ ! -d "/opt/tomcat9" ]; then
  cd /opt
  sudo curl -O https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo ln -s apache-tomcat-${TOMCAT_VERSION} tomcat9
  sudo chmod +x /opt/tomcat9/bin/*.sh

  # Configure tomcat-users.xml
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

  # Create systemd service
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
