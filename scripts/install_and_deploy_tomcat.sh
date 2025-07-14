#!/bin/bash
set -e
set -x

PHASE=$1

case "$PHASE" in
  ApplicationStop)
    echo "===== ApplicationStop: Stopping Tomcat ====="
    sudo systemctl stop tomcat || true
    ;;

  BeforeInstall)
    echo "===== BeforeInstall: Cleaning old deployments ====="
    rm -rf /opt/tomcat9/webapps/Ecomm.war
    rm -rf /opt/tomcat9/webapps/Ecomm
    ;;

  AfterInstall)
    echo "===== AfterInstall: Installing Java, Tomcat, Deploying WAR ====="
    sudo yum update -y
    sudo amazon-linux-extras enable corretto11
    sudo yum install -y java-11-amazon-corretto ruby wget

    cd /home/ec2-user
    wget https://aws-codedeploy-ap-northeast-3.s3.amazonaws.com/latest/install
    chmod +x ./install
    sudo ./install auto || true
    sudo systemctl enable codedeploy-agent
    sudo systemctl start codedeploy-agent

    if [ ! -d "/opt/tomcat9" ]; then
      cd /opt
      sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.86/bin/apache-tomcat-9.0.86.tar.gz
      sudo tar -xvzf apache-tomcat-9.0.86.tar.gz
      sudo mv apache-tomcat-9.0.86 tomcat9
      sudo chown -R ec2-user:ec2-user /opt/tomcat9
    fi

    if [ ! -f "/etc/systemd/system/tomcat.service" ]; then
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
    cp /home/ec2-user/Ecomm.war /opt/tomcat9/webapps/
    sudo chown ec2-user:ec2-user /opt/tomcat9/webapps/Ecomm.war

    # Use tomcat-users.xml from repo
    if [ -f "/home/ec2-user/tomcat-users.xml" ]; then
      echo "Copying tomcat-users.xml from repo to Tomcat conf..."
      cp /home/ec2-user/tomcat-users.xml /opt/tomcat9/conf/tomcat-users.xml
      sudo chown ec2-user:ec2-user /opt/tomcat9/conf/tomcat-users.xml
    else
      echo "tomcat-users.xml not found in repo. Skipping user config."
    fi

    sudo chown -R ec2-user:ec2-user /opt/tomcat9
    ;;

  ApplicationStart)
    echo "===== ApplicationStart: Starting Tomcat ====="
    sudo systemctl start tomcat
    ;;

  *)
    echo "Unknown phase: $PHASE"
    exit 1
    ;;
esac
