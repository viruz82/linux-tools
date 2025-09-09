#!/usr/bin/env bash
set -e

# ================================
# Cronicle Worker Manager (interaktiv)
# Installiert oder entfernt einen minimalen Cronicle-Worker
# mit automatischer Node.js-Architektur-Erkennung
# ================================

# Basis-Installationspfad
BASE_DIR="/opt/cronicle-worker"

# Node.js Version (Standard)
NODE_VERSION="v22.19.0"

usage() {
  cat <<EOF
Usage:
  $(basename "$0")  – interaktives Setup oder Deinstallieren
EOF
  exit 1
}

if [ $# -gt 0 ]; then
  echo "Dieses Skript arbeitet rein interaktiv. Keine Parameter erlaubt."
  usage
fi

echo
echo "=== Cronicle-Worker Manager (interaktiv) ==="
echo

# Aktion wählen
read -p "Aktion [install/uninstall] (install): " ACTION
ACTION=${ACTION:-install}

if [[ "$ACTION" != "install" && "$ACTION" != "uninstall" ]]; then
  echo "Ungültige Aktion: $ACTION"
  exit 1
fi

if [ "$ACTION" = "uninstall" ]; then
  echo
  echo "🗑️  Deinstalliere Cronicle-Worker …"
  systemctl stop cronicle-worker.service 2>/dev/null || true
  systemctl disable cronicle-worker.service 2>/dev/null || true
  rm -f /etc/systemd/system/cronicle-worker.service
  systemctl daemon-reload
  rm -rf "$BASE_DIR"
  rm -f /root/cronicle-worker
  echo "✅ Cronicle-Worker entfernt."
  exit 0
fi

# --- Architektur erkennen ---
ARCH_DETECTED="$(uname -m)"
case "$ARCH_DETECTED" in
  x86_64)   NODE_ARCH="linux-x64" ;;
  aarch64)  NODE_ARCH="linux-arm64" ;;
  armv7l)   NODE_ARCH="linux-armv7l" ;;
  armv6l)
    NODE_ARCH="linux-armv6l"
    NODE_VERSION="v22.19.0"
    NODE_URL="https://unofficial-builds.nodejs.org/download/release/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.xz"
    ;;
  *)
    echo "⚠️  Unbekannte Architektur: $ARCH_DETECTED"
    NODE_ARCH=""
    ;;
esac

# Falls unbekannt oder Benutzer möchte überschreiben → Auswahlmenü
if [ -z "$NODE_ARCH" ]; then
  echo "Bitte Architektur auswählen:"
  select opt in "linux-x64" "linux-arm64" "linux-armv7l" "linux-armv6l"; do
    NODE_ARCH="$opt"
    break
  done
else
  echo "✅ Architektur automatisch erkannt: $NODE_ARCH"
  read -p "Möchtest du diese Auswahl ändern? (y/N): " CHANGE
  if [[ "$CHANGE" =~ ^[Yy]$ ]]; then
    select opt in "linux-x64" "linux-arm64" "linux-armv7l" "linux-armv6l"; do
      NODE_ARCH="$opt"
      break
    done
  fi
fi

# --- Interaktive Eingaben ---
DEFAULT_WORKER_NAME="$(hostname)"
DEFAULT_SMTP_HOSTNAME="localhost"
DEFAULT_SMTP_PORT="25"
DEFAULT_EMAIL_FROM="cronicle@example.com"

while [ -z "$MASTER_IP" ]; do
  read -p "Master IP (z.B. 10.0.0.144): " MASTER_IP
done

while [ -z "$SECRET_KEY" ]; do
  read -p "Secret-Key des Masters: " SECRET_KEY
done

read -p "Worker-Name [${DEFAULT_WORKER_NAME}]: " WORKER_NAME
WORKER_NAME=${WORKER_NAME:-$DEFAULT_WORKER_NAME}

read -p "SMTP Hostname [${DEFAULT_SMTP_HOSTNAME}]: " SMTP_HOSTNAME
SMTP_HOSTNAME=${SMTP_HOSTNAME:-$DEFAULT_SMTP_HOSTNAME}

read -p "SMTP Port [${DEFAULT_SMTP_PORT}]: " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-$DEFAULT_SMTP_PORT}

read -p "E-Mail Absenderadresse (email_from) [${DEFAULT_EMAIL_FROM}]: " EMAIL_FROM
EMAIL_FROM=${EMAIL_FROM:-$DEFAULT_EMAIL_FROM}

echo
echo "→ Konfiguration:"
echo "   Master IP:      $MASTER_IP"
echo "   Secret-Key:     [verdeckt]"
echo "   Worker-Name:    $WORKER_NAME"
echo "   SMTP Hostname:  $SMTP_HOSTNAME"
echo "   SMTP Port:      $SMTP_PORT"
echo "   email_from:     $EMAIL_FROM"
echo "   Node.js Build:  $NODE_ARCH"
echo "   Installationspfad: $BASE_DIR"
echo

# --- Installation ---
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

ln -sfn "$BASE_DIR" /root/cronicle-worker

# Node.js Download-URL setzen, falls nicht schon für armv6l definiert
if [ -z "$NODE_URL" ]; then
  NODE_TARBALL="node-${NODE_VERSION}-${NODE_ARCH}.tar.xz"
  NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_TARBALL}"
fi

echo "→ Lade Node.js ${NODE_VERSION} für ${NODE_ARCH} herunter..."
curl -fsSL "$NODE_URL" -o node.tar.xz
tar -xf node.tar.xz --strip-components=1
rm node.tar.xz

git clone https://github.com/jhuckaby/Cronicle.git app

export PATH="$BASE_DIR/bin:$PATH"

cd app
npm install --omit=dev

# --- Config ---
APP_ROOT="$BASE_DIR/app"
APP_CONF="$APP_ROOT/conf"
SAMPLE_CONF="$APP_ROOT/sample_conf"
CONFIG_JSON="$APP_CONF/config.json"
SAMPLE_CONFIG="$APP_CONF/config.sample.json"
LOG_DIR="$APP_ROOT/logs"

if [ ! -d "$APP_CONF" ] && [ -d "$SAMPLE_CONF" ]; then
  cp -r "$SAMPLE_CONF" "$APP_CONF"
fi

if [ ! -f "$CONFIG_JSON" ] && [ -f "$SAMPLE_CONFIG" ]; then
  cp "$SAMPLE_CONFIG" "$CONFIG_JSON"
fi

mkdir -p "$LOG_DIR"
cp "$CONFIG_JSON" "${CONFIG_JSON}.bak"

sed -i 's#^\s*"base_app_url".*#    "base_app_url": "http://'"$MASTER_IP"':3012",#' "$CONFIG_JSON"
sed -i 's#^\s*"secret_key".*#    "secret_key": "'"$SECRET_KEY"'",#' "$CONFIG_JSON"
sed -i '/"secret_key"/a\    "role": "worker",\n    "hostname": "'"$WORKER_NAME"'",' "$CONFIG_JSON"
sed -i 's#^\s*"smtp_hostname".*#    "smtp_hostname": "'"$SMTP_HOSTNAME"'",#' "$CONFIG_JSON"
sed -i 's#^\s*"smtp_port".*#    "smtp_port": '"$SMTP_PORT"',#' "$CONFIG_JSON"
sed -i 's#^\s*"email_from".*#    "email_from": "'"$EMAIL_FROM"'",#' "$CONFIG_JSON"
sed -i 's#^\s*"log_dir".*#    "log_dir": "'"$LOG_DIR"'",#' "$CONFIG_JSON"

# --- Build & Start ---
cd "$APP_ROOT"
node bin/build.js dist
./bin/control.sh start

# --- systemd ---
cat > /etc/systemd/system/cronicle-worker.service <<EOF
[Unit]
Description=Cronicle Worker Service
After=network.target

[Service]
Type=forking
Environment=PATH=$BASE_DIR/bin:/usr/bin:/bin
WorkingDirectory=$APP_ROOT
ExecStart=$APP_ROOT/bin/control.sh start
ExecStop=$APP_ROOT/bin/control.sh stop
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cronicle-worker.service

echo
echo "🎉 Installation abgeschlossen."
echo "Symlink: /root/cronicle-worker → $BASE_DIR"
echo "Service-Status prüfen: systemctl status cronicle-worker.service"
