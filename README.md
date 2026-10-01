# System Monitor Remote

Publishes the sensors enabled on the DELROBCO System Monitor integrations:

- disk usage `/`
- memory usage
- processor use
- processor temperature (Celsius; HA converts to °F)
- load 1 / 5 / 15 min
- uptime (boot time)
- IPv4 address per non-loopback interface
- fan speed, when the kernel exposes one (`pwmfan` on the Pi HATs)

Pair with [ha-system-monitor-remote](https://github.com/rbridal/ha-system-monitor-remote).

`shop-*` hosts publish to shop-ha Mosquitto `172.31.0.20`. `home-*` hosts publish to home-ha Mosquitto `172.31.0.30`. Topic prefix is `system-monitor/{device_id}`.

## Install

From a checkout this user can read:

```bash
DEVICE_ID=shop-dash bash scripts/install.sh
```

Other ids: `shop-server`, `home-dino`, `home-clock`. The script copies the MQTT password from `/opt/ups-hat-e-remote/config.yaml` when that file exists, so shop-dash does not need a second password entry.
