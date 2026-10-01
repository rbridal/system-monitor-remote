#!/bin/bash
# Install from the checkout that contains this script. dash cannot clone private repos;
# these repos are public, but copying the checkout still avoids a second auth step.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST=/opt/system-monitor-remote
DEVICE_ID="${DEVICE_ID:-shop-dash}"

if ! id dash >/dev/null 2>&1; then
  echo "user dash is missing" >&2
  exit 1
fi

sudo mkdir -p "$DEST"
sudo rsync -a --delete --exclude venv --exclude config.yaml "$SRC/" "$DEST/"
sudo chown -R dash:dash "$DEST"

if [[ ! -d "$DEST/venv" ]]; then
  sudo -u dash python3 -m venv "$DEST/venv"
fi
sudo -u dash "$DEST/venv/bin/pip" install -q -r "$DEST/requirements.txt"

if [[ ! -f "$DEST/config.yaml" ]]; then
  case "$DEVICE_ID" in
    home-*) HOST=172.31.0.30 ;;
    *) HOST=172.31.0.20 ;;
  esac
  NAME=$(echo "$DEVICE_ID" | sed -e 's/-/ /g' -e 's/\b\(.\)/\u\1/g')
  sudo -u dash tee "$DEST/config.yaml" >/dev/null <<EOF
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
    python3 - <<'PY'
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
    sudo chown dash:dash "$DEST/config.yaml"
    sudo chmod 600 "$DEST/config.yaml"
  fi
fi

sudo install -m 644 "$DEST/system-monitor-remote.service" /etc/systemd/system/system-monitor-remote.service
sudo systemctl daemon-reload

if grep -q 'CHANGE_ME' "$DEST/config.yaml"; then
  echo "unit installed, not started"
  echo "set mqtt.password in $DEST/config.yaml, then:"
  echo "  sudo systemctl enable --now system-monitor-remote"
  exit 0
fi

sudo systemctl enable --now system-monitor-remote
sudo systemctl --no-pager --full status system-monitor-remote
