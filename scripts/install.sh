#!/bin/bash
# Install from the checkout that contains this script.
# shop-dash has user dash. Other hosts run as the user who launched this script.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST=/opt/system-monitor-remote
DEVICE_ID="${DEVICE_ID:-shop-dash}"

if id dash >/dev/null 2>&1; then
  RUN_USER=dash
else
  RUN_USER="${SUDO_USER:-$(id -un)}"
  if [[ "$RUN_USER" == "root" ]]; then
    echo "no dash user; run this as the service user, not root" >&2
    exit 1
  fi
fi

sudo mkdir -p "$DEST"
sudo rsync -a --delete --exclude venv --exclude config.yaml "$SRC/" "$DEST/"
sudo chown -R "$RUN_USER:$RUN_USER" "$DEST"

if [[ ! -d "$DEST/venv" ]]; then
  sudo -u "$RUN_USER" python3 -m venv "$DEST/venv"
fi
sudo -u "$RUN_USER" "$DEST/venv/bin/pip" install -q -r "$DEST/requirements.txt"

if [[ ! -f "$DEST/config.yaml" ]]; then
  case "$DEVICE_ID" in
    home-*) HOST=172.31.0.30 ;;
    *) HOST=172.31.0.20 ;;
  esac
  NAME=$(echo "$DEVICE_ID" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
  sudo -u "$RUN_USER" tee "$DEST/config.yaml" >/dev/null <<EOF
device_id: ${DEVICE_ID}
device_name: ${NAME}
interval_seconds: 15
mqtt:
  host: ${HOST}
  port: 1883
  username: dino-player
  password: CHANGE_ME
  topic_prefix: system-monitor/${DEVICE_ID}
EOF
  sudo chmod 600 "$DEST/config.yaml"
  if [[ -f /opt/ups-hat-e-remote/config.yaml ]]; then
    sudo -u "$RUN_USER" "$DEST/venv/bin/python" - <<'PY'
from pathlib import Path
import yaml
src = yaml.safe_load(Path("/opt/ups-hat-e-remote/config.yaml").read_text()) or {}
dst_path = Path("/opt/system-monitor-remote/config.yaml")
dst = yaml.safe_load(dst_path.read_text()) or {}
password = ((src.get("mqtt") or {}).get("password")) or ""
if password and password != "CHANGE_ME":
    dst.setdefault("mqtt", {})["password"] = password
    dst["mqtt"]["username"] = (src.get("mqtt") or {}).get("username") or "dino-player"
    dst_path.write_text(yaml.safe_dump(dst, sort_keys=False))
PY
    sudo chown "$RUN_USER:$RUN_USER" "$DEST/config.yaml"
    sudo chmod 600 "$DEST/config.yaml"
  fi
fi

sudo sed -e "s/^User=.*/User=${RUN_USER}/" -e "s/^Group=.*/Group=${RUN_USER}/" \
  "$DEST/system-monitor-remote.service" | sudo tee /etc/systemd/system/system-monitor-remote.service >/dev/null
sudo systemctl daemon-reload

if sudo grep -q 'CHANGE_ME' "$DEST/config.yaml"; then
  echo "unit installed as ${RUN_USER}, not started"
  echo "set mqtt.password in $DEST/config.yaml, then:"
  echo "  sudo systemctl enable --now system-monitor-remote"
  exit 0
fi

sudo systemctl enable --now system-monitor-remote
sudo systemctl --no-pager --full status system-monitor-remote
