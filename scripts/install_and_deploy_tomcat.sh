#!/bin/bash
set -euo pipefail

# ===== CONFIG =====
TOMCAT_VERSION="9.0.86"
T_BASE="/opt/tomcat"
T_DIR_VERSION="$T_BASE/apache-tomcat-${TOMCAT_VERSION}"
T_SYMLINK="$T_BASE/latest"
SERVICE_FILE="/etc/systemd/system/tomcat.service"

WAR_NAME="Ecomm.war"
WAR_SRC="/home/ec2-user/${WAR_NAME}"
WAR_DEST="${T_SYMLINK}/webapps/${WAR_NAME}"

USERS_SRC="/home/ec2-user/tomcat-users.xml"
USERS_DEST="${T_SYMLINK}/conf/tomcat-users.xml"

echo "[INFO] === Starting deployment ==="

# --- 1) Prereqs: Java + tools ---
if ! command -v java >/dev/null 2>&1; then
  echo "[INFO] Installing Amazon Corretto 11..."
  yum install -y java-11-amazon-corretto
fi
yum install -y curl tar >/dev/null 2>&1 || true

# --- 2) Install Tomcat (idempotent) ---
if [ ! -d "$T_DIR_VERSION" ]; then
  echo "[INFO] Installing Tomcat ${TOMCAT_VERSION}..."
  mkdir -p "$T_BASE"
  cd /tmp
  # Use archive URL so it never 404s as versions age
  curl -fsSLO "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
  tar -xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz" -C "$T_BASE"
fi

if [ ! -L "$T_SYMLINK" ]; then
  ln -s "$T_DIR_VERSION" "$T_SYMLINK"
else
  # ensure latest points to the requested version
  ln -sfn "$T_DIR_VERSION" "$T_SYMLINK"
fi

chmod +x "$T_SYMLINK"/bin/*.sh

# --- 3) Create/ensure systemd service (once) ---
if [ ! -f "$SERVICE_FILE" ]; then
  echo "[INFO] Creating systemd unit: tomcat.service"
  cat >/etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user
Environment=JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
Environment=CATALINA_HOME=${T_SYMLINK}
Environment=CATALINA_BASE=${T_SYMLINK}
Environment=CATALINA_PID=${T_SYMLINK}/temp/tomcat.pid
ExecStart=${T_SYMLINK}/bin/startup.sh
ExecStop=${T_SYMLINK}/bin/shutdown.sh
Restart=always
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF
  # Allow ec2-user to own Tomcat tree
  chown -R ec2-user:ec2-user "$T_BASE" || true
  systemctl daemon-reload
  systemctl enable tomcat
fi

# --- 4) Stop Tomcat if running ---
if systemctl is-active --quiet tomcat; then
  echo "[INFO] Stopping Tomcat..."
  systemctl stop tomcat
fi

# --- 5) Clean old deployment (war & exploded dir) ---
echo "[INFO] Cleaning previous Ecomm deployment..."
rm -f "$WAR_DEST" || true
rm -rf "${T_SYMLINK}/webapps/${WAR_NAME%.war}" || true

# --- 6) Validate incoming artifacts & deploy ---
if [ ! -f "$WAR_SRC" ]; then
  echo "[ERROR] WAR not found at $WAR_SRC"
  exit 1
fi
cp -f "$WAR_SRC" "$WAR_DEST"

if [ -f "$USERS_SRC" ]; then
  echo "[INFO] Updating tomcat-users.xml (Manager auth)..."
  cp -f "$USERS_SRC" "$USERS_DEST"
fi

# Ensure permissions (Tomcat runs as ec2-user)
chown -R ec2-user:ec2-user "$T_BASE"

# --- 7) Start Tomcat ---
echo "[INFO] Starting Tomcat..."
systemctl start tomcat

# --- 8) Basic health check (8080) ---
echo "[INFO] Waiting for Tomcat to respond on :8080 ..."
retries=15
until curl -fsS "http://localhost:8080/" >/dev/null 2>&1; do
  ((retries-=1)) || { echo "[WARN] Tomcat not responding yet, continuing (Validate hook will catch if needed)."; break; }
  sleep 2
done

echo "[INFO] === Deployment completed successfully ==="
