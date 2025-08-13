#!/bin/bash
set -e

LOG_FILE="/var/log/tomcat_deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat
WAR_FILE=/opt/tomcat/latest/webapps/Ecomm.war
TOMCAT_USERS_FILE=/opt/tomcat/latest/conf/tomcat-users.xml

echo "==== $(date) : Starting Tomcat deployment script ===="

# 1. Install Java if not installed
if ! java -version &>/dev/null; then
  echo "Installing Java 11..."
  yum install -y java-11-amazon-corretto
else
  echo "Java is already installed."
fi

# 2. Install Tomcat if not already installed
if [ ! -d "$TOMCAT_DIR" ]; then
  echo "Installing Tomcat $TOMCAT_VERSION..."
  mkdir -p $TOMCAT_DIR
  cd /tmp
  curl -O https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvf apache-tomcat-$TOMCAT_VERSION.tar.gz
  mv apache-tomcat-$TOMCAT_VERSION $TOMCAT_DIR/latest
  chmod +x $TOMCAT_DIR/latest/bin/*.sh

  # Create systemd service
  cat >/etc/systemd/system/tomcat.service <<EOL
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
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

  systemctl daemon-reload
  systemctl enable tomcat
else
  echo "Tomcat is already installed."
fi

# 3. Stop Tomcat if running
if systemctl is-active --quiet tomcat; then
  echo "Stopping Tomcat..."
  systemctl stop tomcat
fi

# 4. Deploy WAR file
if [ -f "$WAR_FILE" ]; then
  echo "Removing old Ecomm.war..."
  rm -f "$WAR_FILE"
fi
echo "Copying new Ecomm.war..."
cp /opt/codedeploy-agent/deployment-root/*/*/target/Ecomm.war /opt/tomcat/latest/webapps/

# 5. Deploy tomcat-users.xml
echo "Copying tomcat-users.xml..."
cp /opt/codedeploy-agent/deployment-root/*/*/tomcat-users.xml /opt/tomcat/latest/conf/

# 6. Start Tomcat
echo "Starting Tomcat..."
systemctl start tomcat

echo "==== $(date) : Deployment completed successfully ===="
