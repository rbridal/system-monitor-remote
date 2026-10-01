"""Publish System Monitor snapshots to an HA Mosquitto broker."""
from __future__ import annotations

import json
import socket
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import psutil
import yaml
from paho.mqtt.client import CallbackAPIVersion, Client


def _load(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path} is not a mapping")
    return data


def _ipv4() -> dict[str, str]:
    found: dict[str, str] = {}
    for name, addrs in psutil.net_if_addrs().items():
        if name == "lo":
            continue
        for addr in addrs:
            if addr.family == socket.AF_INET and addr.address:
                found[name] = addr.address
                break
    return found


def _temperature_c() -> float | None:
    try:
        temps = psutil.sensors_temperatures()
    except (AttributeError, OSError):
        return None
    for entries in temps.values():
        for entry in entries:
            if entry.current is not None:
                return round(entry.current, 1)
    return None


def _fans() -> dict[str, int]:
    try:
        fans = psutil.sensors_fans()
    except (AttributeError, OSError):
        return {}
    out: dict[str, int] = {}
    for label, entries in fans.items():
        for entry in entries:
            if entry.current is None:
                continue
            key = label or entry.label or "fan"
            out[key] = int(entry.current)
    return out


def snapshot(cfg: dict) -> dict:
    disk = psutil.disk_usage("/")
    mem = psutil.virtual_memory()
    load1, load5, load15 = psutil.getloadavg()
    boot = datetime.fromtimestamp(psutil.boot_time(), timezone.utc).isoformat()
    return {
        "device_id": cfg["device_id"],
        "device_name": cfg.get("device_name") or cfg["device_id"],
        "hostname": socket.gethostname(),
        "ts": datetime.now(timezone.utc).isoformat(),
        "disk_usage": round(disk.percent, 1),
        "memory_usage": round(mem.percent, 1),
        "processor_use": round(psutil.cpu_percent(interval=None), 1),
        "processor_temperature_c": _temperature_c(),
        "load_1_min": round(load1, 2),
        "load_5_min": round(load5, 2),
        "load_15_min": round(load15, 2),
        "boot_time": boot,
        "ipv4": _ipv4(),
        "fans": _fans(),
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("config", nargs="?", default="config.yaml")
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    cfg = _load(Path(args.config))
    psutil.cpu_percent(interval=None)

    if args.once:
        time.sleep(0.2)
        print(json.dumps(snapshot(cfg)))
        return

    mqtt_cfg = cfg.get("mqtt") or {}
    prefix = str(mqtt_cfg.get("topic_prefix") or f"system-monitor/{cfg['device_id']}").rstrip("/")
    state_topic = f"{prefix}/state"
    avail_topic = f"{prefix}/availability"
    interval = int(cfg.get("interval_seconds", 15))
    password = mqtt_cfg.get("password") or None
    if password == "CHANGE_ME":
        raise SystemExit("set mqtt.password in config.yaml")

    client = Client(CallbackAPIVersion.VERSION2, client_id=f"system-monitor-{cfg['device_id']}")
    username = mqtt_cfg.get("username") or None
    if username:
        client.username_pw_set(username, password)
    client.will_set(avail_topic, "offline", qos=1, retain=True)

    def on_connect(c, _userdata, _flags, reason_code, _properties):
        if reason_code == 0:
            c.publish(avail_topic, "online", qos=1, retain=True)

    client.on_connect = on_connect
    client.connect(str(mqtt_cfg.get("host") or "127.0.0.1"), int(mqtt_cfg.get("port") or 1883), keepalive=30)
    client.loop_start()
    try:
        while True:
            client.publish(state_topic, json.dumps(snapshot(cfg)), qos=1, retain=True)
            client.publish(avail_topic, "online", qos=1, retain=True)
            time.sleep(interval)
    finally:
        client.publish(avail_topic, "offline", qos=1, retain=True)
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
