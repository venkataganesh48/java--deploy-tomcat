#!/bin/bash
set -e

TOMCAT_VERSION=9.0.86
WAR_NAME=Ecomm.war
TOMCAT_DIR=/opt/tomcat

echo "=== Installing Java ==="
if ! java -version &>/dev/null; then
  yum install -y java-11-amazon-corretto
fi

echo "=== Installing Tomcat if not present ==="
if [ ! -d "$TOMCAT_DIR/apache-tomcat-$TOMCAT_VERSION" ]; then
  mkdir -p $TOMCAT_DIR
  cd $TOMCAT_DIR
  wget https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvf apache-tomcat-$TOMCAT_VERSION.tar.gz
  ln -s apache-tomcat-$TOMCAT_VERSION latest
  chmod +x latest/bin/*.sh
fi

echo "=== Stopping Tomcat if running ==="
if [ -f "$TOMCAT_DIR/latest/bin/shutdown.sh" ]; then
  $TOMCAT_DIR/latest/bin/shutdown.sh || true
  sleep 5
fi

echo "=== Cleaning old deployment ==="
rm -rf $TOMCAT_DIR/latest/webapps/Ecomm*

echo "=== Copying WAR file ==="
cp target/$WAR_NAME $TOMCAT_DIR/latest/webapps/

echo "=== Copying tomcat-users.xml ==="
cp tomcat-users.xml $TOMCAT_DIR/latest/conf/

echo "=== Starting Tomcat ==="
$TOMCAT_DIR/latest/bin/startup.sh

echo "=== Validating deployment ==="
sleep 10
if curl -f http://localhost:8080; then
  echo "Deployment successful!"
else
  echo "Deployment failed!"
  exit 1
fi
