#!/bin/bash
set -e
set -x

echo "======== Installing AWS CodeDeploy Agent ========="
sudo yum update -y
sudo yum install -y ruby wget curl unzip -y

cd /home/ec2-user
wget https://aws-codedeploy-ap-northeast-3.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl enable --now codedeploy-agent

echo "======== Installing Java 11 ========="
sudo yum install -y java-11-amazon-corretto

echo "======== Installing Tomcat ========="
TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat

if [ ! -d "$TOMCAT_DIR" ]; then
  cd /opt/
  sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
  sudo mv apache-tomcat-${TOMCAT_VERSION} tomcat
fi

sudo chown -R ec2-user:ec2-user "$TOMCAT_DIR"
sudo chmod +x "$TOMCAT_DIR"/bin/*.sh

echo "======== Configuring Tomcat Users ========="
cat <<EOF | sudo tee "$TOMCAT_DIR/conf/tomcat-users.xml"
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <user username="admin" password="admin" roles="manager-gui,manager-script,manager-jmx,manager-status"/>
</tomcat-users>
EOF

echo "======== Disabling RemoteAddrValve in manager context ========="
CONTEXT_FILE="$TOMCAT_DIR/webapps/manager/META-INF/context.xml"
if [ -f "$CONTEXT_FILE" ]; then
  sudo sed -i 's/<Valve/\<!-- <Valve/' "$CONTEXT_FILE"
  sudo sed -i 's/\/>$/\/> -->/' "$CONTEXT_FILE"
fi

echo "======== Creating Tomcat systemd service ========="
if [ ! -f /etc/systemd/system/tomcat.service ]; then
cat <<EOF | sudo tee /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat
After=network.target

[Service]
User=ec2-user
Group=ec2-user
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_HOME=${TOMCAT_DIR}
ExecStart=${TOMCAT_DIR}/bin/startup.sh
ExecStop=${TOMCAT_DIR}/bin/shutdown.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
fi

echo "======== Deploying WAR Application ========="
WAR_FILE="/home/ec2-user/Ecomm.war"
DEPLOY_PATH="$TOMCAT_DIR/webapps/Ecomm.war"

sudo systemctl stop tomcat || true
sudo rm -rf "$TOMCAT_DIR/webapps/Ecomm"
sudo rm -f "$DEPLOY_PATH"

if [ -f "$WAR_FILE" ]; then
  sudo cp "$WAR_FILE" "$DEPLOY_PATH"
else
  echo "❌ WAR file not found!"
  exit 1
fi

echo "======== Starting Tomcat ========="
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat

echo "======== Deployment Complete. Visit http://<your-public-ip>:8080 ========="
