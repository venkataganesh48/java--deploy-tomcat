#!/bin/bash
set -e

TOMCAT_VERSION=9.0.86
TOMCAT_DIR=/opt/tomcat
TOMCAT_HOME=$TOMCAT_DIR/apache-tomcat-$TOMCAT_VERSION

echo "===== Step 1: Install Java if not installed ====="
if ! java -version &>/dev/null; then
  yum install -y java-11-amazon-corretto
fi

echo "===== Step 2: Install Tomcat if not installed ====="
if [ ! -d "$TOMCAT_HOME" ]; then
  mkdir -p $TOMCAT_DIR
  cd $TOMCAT_DIR
  wget https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvf apache-tomcat-$TOMCAT_VERSION.tar.gz
  ln -sfn $TOMCAT_HOME $TOMCAT_DIR/latest
  chmod +x $TOMCAT_DIR/latest/bin/*.sh
fi

echo "===== Step 3: Copy tomcat-users.xml from repo ====="
cp tomcat-users.xml $TOMCAT_DIR/latest/conf/tomcat-users.xml

echo "===== Step 4: Stop Tomcat if running ====="
if pgrep -f "org.apache.catalina.startup.Bootstrap" > /dev/null; then
  $TOMCAT_DIR/latest/bin/shutdown.sh || true
  sleep 5
fi

echo "===== Step 5: Cleanup old Ecomm deployment ====="
rm -rf $TOMCAT_DIR/latest/webapps/Ecomm*

echo "===== Step 6: Deploy new Ecomm.war ====="
cp target/Ecomm.war $TOMCAT_DIR/latest/webapps/

echo "===== Step 7: Start Tomcat ====="
$TOMCAT_DIR/latest/bin/startup.sh

echo "===== Step 8: Validate Tomcat is running ====="
sleep 10
if curl -s http://localhost:8080 | grep -q "Apache Tomcat"; then
  echo "Tomcat homepage is accessible."
else
  echo "Tomcat validation failed!"
  exit 1
fi

echo "===== Deployment Successful! ====="
