#!/bin/bash
set -e
set -x

# Save logs for debugging
exec > >(tee -a /tmp/codedeploy_log.txt) 2>&1

PHASE=$1
echo "Running phase: $PHASE"

case "$PHASE" in

  ApplicationStop)
    echo "===== ApplicationStop: Stopping Tomcat ====="
    systemctl stop tomcat || true
    ;;

  BeforeInstall)
    echo "===== BeforeInstall: Cleaning old deployments ====="
    if [ -d "/opt/tomcat9/webapps" ]; then
      rm -f /opt/tomcat9/webapps/Ecomm.war || true
      rm -rf /opt/tomcat9/webapps/Ecomm || true
    else
      echo "/opt/tomcat9/webapps not found. Skipping."
    fi
    ;;

  AfterInstall)
    echo "===== AfterInstall: Installing Java, Tomcat, Deploying WAR ====="

    # Install Java 11 if missing
    if ! java -version 2>&1 | grep -q "11"; then
      amazon-linux-extras enable corretto11
      yum install -y java-11-amazon-corretto
    fi

    # Install Tomcat 9 if not installed
    if [ ! -d "/opt/tomcat9" ]; then
      cd /opt
      wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.86/bin/apache-tomcat-9.0.86.tar.gz
      tar -xvzf apache-tomcat-9.0.86.tar.gz
      mv apache-tomcat-9.0.86 tomcat9
      chown -R ec2-user:ec2-user /opt/tomcat9
    fi

    # Setup systemd service if not present
    if [ ! -f "/etc/systemd/system/tomcat.service" ]; then
      cat <<EOF | tee /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user
Environment="JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto"
Environment="CATALINA_PID=/opt/tomcat9/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat9"
Environment="CATALINA_BASE=/opt/tomcat9"
ExecStart=/opt/tomcat9/bin/startup.sh
ExecStop=/opt/tomcat9/bin/shutdown.sh
[Install]
WantedBy=multi-user.target
EOF

      systemctl daemon-reexec
      systemctl daemon-reload
      systemctl enable tomcat
    fi

    # Deploy WAR
    cp /home/ec2-user/Ecomm.war /opt/tomcat9/webapps/
    chown ec2-user:ec2-user /opt/tomcat9/webapps/Ecomm.war

    # Deploy tomcat-users.xml
    if [ -f "/home/ec2-user/tomcat-users.xml" ]; then
      cp /home/ec2-user/tomcat-users.xml /opt/tomcat9/conf/
      chown ec2-user:ec2-user /opt/tomcat9/conf/tomcat-users.xml
    fi

    chown -R ec2-user:ec2-user /opt/tomcat9
    ;;

  ApplicationStart)
    echo "===== ApplicationStart: Starting Tomcat ====="
    systemctl start tomcat
    ;;

  ValidateService)
    echo "===== ValidateService: Checking Tomcat Status ====="
    systemctl is-active --quiet tomcat && echo "Tomcat is running" || (echo "Tomcat is NOT running" && exit 1)
    ;;

  *)
    echo "❌ Unknown lifecycle phase: $PHASE"
    exit 1
    ;;
esac
