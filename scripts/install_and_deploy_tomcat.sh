#!/bin/bash 
set -e
set -x

# ======== Step 1: Install AWS CodeDeploy Agent ========

echo "======== Installing AWS CodeDeploy Agent ========="
sudo yum update -y

if grep -q "Amazon Linux release 2" /etc/os-release; then
echo "Installing CodeDeploy agent for Amazon Linux 2..."
sudo yum install -y ruby wget
cd /home/ec2-user
wget [https://aws-codedeploy-ap-northeast-3.s3.ap-northeast-3.amazonaws.com/latest/install](https://aws-codedeploy-ap-northeast-3.s3.ap-northeast-3.amazonaws.com/latest/install)
chmod +x ./install
sudo ./install auto
else
echo "Installing CodeDeploy agent for Amazon Linux (classic)..."
sudo yum install -y ruby wget
cd /home/ec2-user
wget [https://aws-codedeploy-ap-northeast-3.s3.ap-northeast-3.amazonaws.com/latest/install](https://aws-codedeploy-ap-northeast-3.s3.ap-northeast-3.amazonaws.com/latest/install)
chmod +x ./install
sudo ./install auto
fi

sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent
sleep 5
sudo systemctl status codedeploy-agent
sudo tail -n 20 /var/log/aws/codedeploy-agent/codedeploy-agent.log

# ======== Step 2: Install Java 11 ========

echo "======== Checking and Installing Java 11 ========="
if ! java -version &>/dev/null; then
echo "Installing Java 11..."
sudo yum install -y java-11-amazon-corretto
else
echo "Java is already installed."
fi

# ======== Step 3: Install Tomcat ========

echo "======== Installing Tomcat ========="
TOMCAT\_VERSION=9.0.86
cd /opt/

if \[ ! -d "/opt/tomcat" ]; then
echo "Downloading and installing Tomcat..."
sudo curl -O [https://archive.apache.org/dist/tomcat/tomcat-9/v\${TOMCAT\_VERSION}/bin/apache-tomcat-\${TOMCAT\_VERSION}.tar.gz](https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz)
sudo tar -xzf apache-tomcat-\${TOMCAT\_VERSION}.tar.gz
sudo mv apache-tomcat-\${TOMCAT\_VERSION} tomcat
sudo chmod +x /opt/tomcat/bin/\*.sh
sudo chown -R ec2-user\:ec2-user /opt/tomcat
else
echo "Tomcat is already installed. Skipping installation."
fi

# ======== Step 4: Configure Tomcat Users ========

echo "======== Creating tomcat-users.xml with admin user ========="
sudo tee /opt/tomcat/conf/tomcat-users.xml > /dev/null <\<EOF <tomcat-users> <role rolename="manager-gui"/> <role rolename="manager-script"/> <role rolename="manager-jmx"/> <role rolename="manager-status"/> <user username="admin" password="admin" roles="manager-gui,manager-script,manager-jmx,manager-status"/> </tomcat-users>
EOF

# ======== Step 5: Create Tomcat systemd Service ========

echo "======== Creating Tomcat systemd service ========="
if \[ ! -f "/etc/systemd/system/tomcat.service" ]; then
sudo tee /etc/systemd/system/tomcat.service > /dev/null <\<EOF
\[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

\[Service]
Type=forking
User=ec2-user
Group=ec2-user

Environment=JAVA\_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA\_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA\_HOME=/opt/tomcat
Environment=CATALINA\_BASE=/opt/tomcat

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

Restart=always
RestartSec=10

\[Install]
WantedBy=multi-user.target
EOF
else
echo "Tomcat systemd service already exists. Skipping creation."
fi

# ======== Step 6: Stop Tomcat for Deployment ========

echo "======== Stopping Tomcat to deploy WAR file ========="
sudo systemctl stop tomcat || true

# ======== Step 7: Deploy WAR file ========

echo "======== Deploying WAR file to Tomcat ========="
WAR\_NAME="Ecomm.war"
SOURCE\_WAR="/home/ec2-user/\${WAR\_NAME}"
TARGET\_WAR="/opt/tomcat/webapps/\${WAR\_NAME}"
APP\_DIR="/opt/tomcat/webapps/Ecomm"

# Clean up previous deployment

sudo rm -rf "\$APP\_DIR"
sudo rm -f "\$TARGET\_WAR"

if \[ -f "\$SOURCE\_WAR" ]; then
sudo cp "\$SOURCE\_WAR" "\$TARGET\_WAR"
echo "✅ WAR file copied to Tomcat webapps."
else
echo "❌ WAR file not found at \$SOURCE\_WAR"
exit 1
fi

# ======== Step 8: Start Tomcat ========

echo "======== Starting and Enabling Tomcat service ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

echo "======== Deployment Complete ========="
