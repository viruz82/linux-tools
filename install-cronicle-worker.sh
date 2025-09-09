#!/usr/bin/env bash
set -e

# Usage-Hilfe
usage() {
  cat <<EOF
Usage:
  $(basename "$0")            – interaktives Setup oder Deinstallieren
    install   → Cronicle-Worker interaktiv einrichten
    uninstall → Komplett entfernen
EOF
  exit 1
}

# Skript darf keine Argumente bekommen
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
  rm -rf /opt/cronicle-worker
  rm -f /root/cronicle-worker
  echo "✅ Cronicle-Worker entfernt."
  exit 0
fi

# Installations-Defaults
DEFAULT_WORKER_NAME="$(hostname)"
DEFAULT_SMTP_HOSTNAME="localhost"
DEFAULT_SMTP_PORT="25"

# Master-IP abfragen (erforderlich)
while [ -z "$MASTER_IP" ]; do
  read -p "Master IP (z.B. 10.0.0.144): " MASTER_IP
done

# Secret-Key abfragen (erforderlich)
while [ -z "$SECRET_KEY" ]; do
  read -p "Secret-Key des Masters: " SECRET_KEY
done

# Optionale Werte
read -p "Worker-Name [${DEFAULT_WORKER_NAME}]: " WORKER_NAME
WORKER_NAME=${WORKER_NAME:-$DEFAULT_WORKER_NAME}

read -p "SMTP Hostname [${DEFAULT_SMTP_HOSTNAME}]: " SMTP_HOSTNAME
SMTP_HOSTNAME=${SMTP_HOSTNAME:-$DEFAULT_SMTP_HOSTNAME}

read -p "SMTP Port [${DEFAULT_SMTP_PORT}]: " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-$DEFAULT_SMTP_PORT}

echo
echo "→ Konfiguration:"
echo "   Master IP:      $MASTER_IP"
echo "   Secret-Key:     [verdeckt]"
echo "   Worker-Name:    $WORKER_NAME"
echo "   SMTP Hostname:  $SMTP_HOSTNAME"
echo "   SMTP Port:      $SMTP_PORT"
echo

# 1) Basis-Verzeichnis anlegen
mkdir -p /opt/cronicle-worker
cd /opt/cronicle-worker

# 1a) Symlink unter /root
ln -sfn /opt/cronicle-worker /root/cronicle-worker

# 2) Node.js 22.19.0 installieren
curl -fsSL https://nodejs.org/dist/v22.19.0/node-v22.19.0-linux-x64.tar.xz \
  -o node.tar.xz
tar -xf node.tar.xz --strip-components=1
rm node.tar.xz

# 3) Cronicle klonen
git clone https://github.com/jhuckaby/Cronicle.git app

# 4) Lokale Node in den PATH
export PATH=/opt/cronicle-worker/bin:$PATH

# 5) Abhängigkeiten installieren
cd app
npm install --omit=dev

# 6) Konfiguration anpassen
APP_ROOT="/opt/cronicle-worker/app"
APP_CONF="$APP_ROOT/conf"
SAMPLE_CONF="$APP_ROOT/sample_conf"
CONFIG_JSON="$APP_CONF/config.json"
SAMPLE_CONFIG="$APP_CONF/config.sample.json"

# 6a) sample_conf → conf kopieren, falls notwendig
if [ ! -d "$APP_CONF" ] && [ -d "$SAMPLE_CONF" ]; then
  cp -r "$SAMPLE_CONF" "$APP_CONF"
fi

# 6b) config.json aus sample erstellen, falls nicht vorhanden
if [ ! -f "$CONFIG_JSON" ] && [ -f "$SAMPLE_CONFIG" ]; then
  cp "$SAMPLE_CONFIG" "$CONFIG_JSON"
fi

# 6c) Backup der Config
cp "$CONFIG_JSON" "${CONFIG_JSON}.bak"

# 6d) Werte in config.json setzen
sed -i 's#^\s*"base_app_url".*#    "base_app_url": "http://'"$MASTER_IP"':3012",#' "$CONFIG_JSON"
sed -i 's#^\s*"secret_key".*#    "secret_key": "'"$SECRET_KEY"'",#' "$CONFIG_JSON"
sed -i '/"secret_key"/a\    "role": "worker",\n    "hostname": "'"$WORKER_NAME"'",' "$CONFIG_JSON"
sed -i 's#^\s*"smtp_hostname".*#    "smtp_hostname": "'"$SMTP_HOSTNAME"'",#' "$CONFIG_JSON"
sed -i 's#^\s*"smtp_port".*#    "smtp_port": '"$SMTP_PORT"',#' "$CONFIG_JSON"

# 7) Worker bauen & starten
cd "$APP_ROOT"
node bin/build.js dist
./bin/control.sh start

# 8) systemd-Service anlegen & aktivieren
cat > /etc/systemd/system/cronicle-worker.service << 'EOF'
[Unit]
Description=Cronicle Worker Service
After=network.target

[Service]
Type=forking
Environment=PATH=/opt/cronicle-worker/bin:/usr/bin:/bin
WorkingDirectory=/opt/cronicle-worker/app
ExecStart=/opt/cronicle-worker/app/bin/control.sh start
ExecStop=/opt/cronicle-worker/app/bin/control.sh stop
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cronicle-worker.service

echo
echo "🎉 Installation abgeschlossen."
echo "Symlink: /root/cronicle-worker → /opt/cronicle-worker"
echo "Service-Status prüfen: systemctl status cronicle-worker.service"
