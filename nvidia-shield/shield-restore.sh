#!/usr/bin/env bash
# Macht shield-debloat.sh rückgängig.  Aufruf: ./shield-restore.sh 192.168.x.x disabled-XXXX.txt
set -u
IP="${1:?IP fehlt}"; LIST="${2:?Logdatei (disabled-*.txt) fehlt}"
adb connect "$IP:5555"
while read -r p; do
  [ -n "$p" ] && adb -s "$IP:5555" shell pm enable "$p" && echo "  aktiviert: $p"
done < "$LIST"
adb -s "$IP:5555" shell settings put global window_animation_scale 1
adb -s "$IP:5555" shell settings put global transition_animation_scale 1
adb -s "$IP:5555" shell settings put global animator_duration_scale 1
