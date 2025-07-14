#!/bin/bash
set -e
set -x

# Optional: Save logs for debugging
exec > >(tee -a /tmp/codedeploy_log.txt) 2>&1

PHASE=$1

case "$PHASE" in

  ApplicationStop)
    echo "===== ApplicationStop: Stopping Tomcat ====="
    sudo systemctl stop tomcat || true
    ;;

  BeforeInstall)
    echo "===== BeforeInstall: Cleaning old deployments ====="
    if [ -d "/opt/tomcat9/webapps" ]; then
      echo "Cleaning previous Ecomm app..."
      rm -f /opt/tomcat9/webapps/Ecomm.war || echo "WAR not found"
      rm -rf /opt/tomcat9/webapps/Ecomm || echo "Directory not found"
    else
      echo "/opt/tomcat9/webapps does not exist yet. Skipping cleanup."
    fi
    ;;

  AfterInstall)
    echo "===== AfterInstall: Installing Java, Tomcat, Deploying WAR ====="

    # Install Java 11 only if missing
    if ! java -version 2>&1 | grep -q "11"; then
      echo "Installing Java 11..."
      sudo amazon-linux-extras enable corretto11
      sudo yum install -y java-11-amazon-corretto
    fi

    # Install Tomcat 9 only if not already installed
    if [ ! -d "/opt/tomcat9" ]; then
      echo "Installing Tomcat 9.0.86..."
      cd /opt
      sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.86/bin/apache-tomcat-9.0.86.tar.gz
      sudo tar -xvzf apache-tomcat-9.0.86.tar.gz
      sudo mv apache-tomcat-9.0.86 tomcat9
      sudo chown -R ec2-user:ec2-user /opt/tomcat9
    fi

    # Setup systemd service if not already created
    if [ ! -f "/etc/systemd/system/tomcat.service" ]; then
      echo "Creating systemd service for Tomcat..."
      cat <<EOF | sudo tee /etc/systemd/system/tomcat.service
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

      sudo systemctl daemon-reexec
      sudo systemctl daemon-reload
      sudo systemctl enable tomcat
    fi

    # Deploy WAR
    echo "Deploying Ecomm.war to Tomcat..."
    cp /home/ec2-user/Ecomm.war /opt/tomcat9/webapps/
    sudo chown ec2-user:ec2-user /opt/tomcat9/webapps/Ecomm.war

    # Deploy tomcat-users.xml if provided
    if [ -f "/home/ec2-user/tomcat-users.xml" ]; then
      echo "Replacing tomcat-users.xml..."
      cp /home/ec2-user/tomcat-users.xml /opt/tomcat9/conf/tomcat-users.xml
      sudo chown ec2-user:ec2-user /opt/tomcat9/conf/tomcat-users.xml
    else
      echo "tomcat-users.xml not found in /home/ec2-user/. Skipping."
    fi

    sudo chown -R ec2-user:ec2-user /opt/tomcat9
    ;;

  ApplicationStart)
    echo "===== ApplicationStart: Starting Tomcat ====="
    sudo systemctl start tomcat
    ;;

  *)
    echo "❌ Unknown lifecycle phase: $PHASE"
    exit 1
    ;;
esac
