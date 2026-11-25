#!/usr/bin/env bash
# NVIDIA Shield (Pro) – unnötige Dienste per ADB deaktivieren.
# Nutzt "pm disable-user" -> vollständig umkehrbar (siehe shield-restore.sh), kein Root nötig.
#
# Voraussetzung: Shield > Einstellungen > Geräteeinstellungen > Info > 7x auf "Build" tippen,
# dann Entwickleroptionen > "Netzwerk-Debugging" einschalten.
# Aufruf:  ./shield-debloat.sh                    (sucht die Shield automatisch im Netz)
#          ./shield-debloat.sh 192.168.x.x        (IP der Shield)
#          DRY_RUN=1 ./shield-debloat.sh 192.168.x.x   (nur anzeigen)
set -u
IP="${1:-}"
if [ -z "$IP" ]; then
  echo ">> Suche Shield im lokalen Netz (Port 5555)..."
  SUBNET="$(ip -4 route 2>/dev/null | awk '/src/ && !/docker|veth/ {print $1; exit}' | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')"
  [ -z "$SUBNET" ] && SUBNET="$(ipconfig getifaddr en0 2>/dev/null | cut -d. -f1-3)"   # macOS
  [ -z "$SUBNET" ] && { echo "Subnetz nicht erkannt – bitte IP angeben."; exit 1; }
  for i in $(seq 1 254); do
    ( timeout 1 bash -c "echo >/dev/tcp/$SUBNET.$i/5555" 2>/dev/null && echo "$SUBNET.$i" ) &
  done > /tmp/shield-scan.txt; wait
  for c in $(cat /tmp/shield-scan.txt); do
    adb connect "$c:5555" >/dev/null 2>&1
    MODEL="$(adb -s "$c:5555" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    echo "   gefunden: $c  ($MODEL)"
    case "$MODEL" in *SHIELD*|*Shield*) IP="$c"; break;; esac
  done
  [ -z "$IP" ] && { echo "Keine Shield gefunden. Netzwerk-Debugging an? Sonst IP manuell angeben."; exit 1; }
  echo ">> Shield erkannt: $IP"
fi
DRY_RUN="${DRY_RUN:-0}"
LOG="disabled-$(date +%Y%m%d-%H%M%S).txt"

command -v adb >/dev/null || { echo "adb fehlt: https://developer.android.com/tools/releases/platform-tools"; exit 1; }
adb connect "$IP:5555"
echo ">> Auf der Shield ggf. 'USB-Debugging zulassen' bestätigen, dann Enter drücken."; read -r _
adb -s "$IP:5555" get-state >/dev/null || { echo "Keine Verbindung zur Shield."; exit 1; }
A=(adb -s "$IP:5555" shell)

# --- Pakete, die gefahrlos deaktiviert werden können -------------------------
PKGS=(
  # NVIDIA Telemetrie / Feedback / Diagnose
  com.nvidia.diagtools
  com.nvidia.feedback
  com.nvidia.stats
  com.nvidia.shield.nvcustomize
  com.nvidia.tegrazone3            # NVIDIA Games / GeForce NOW-Launcher
  com.nvidia.nvgamecast
  com.nvidia.ocs                   # NVIDIA Online Content Service
  com.plexapp.mediaserver.smb      # Plex Media Server (falls nicht genutzt)
  # Google Telemetrie / Werbung / Empfehlungen
  com.google.android.feedback
  com.google.android.partnersetup
  com.google.android.tvrecommendations
  com.google.android.leanbacklauncher.recommendations
  com.google.android.play.games
  com.google.android.videos
  com.google.android.youtube.tvmusic
  com.google.android.marvin.talkback
  com.google.android.syncadapters.calendar
  # Android-Reste, die auf einem TV nichts tun
  com.android.printspooler
  com.android.bookmarkprovider
  com.android.gallery3d
  com.android.dreams.basic
)
# OPTIONAL – nur entkommentieren, wenn du sie wirklich nicht brauchst:
#  com.google.android.katniss        # Google Assistant / Sprachsuche (Mikrofon-Taste geht dann nicht)
#  com.google.android.backdrop       # Ambient-Bildschirmschoner
#  com.nvidia.ota                    # System-Updates (nicht empfohlen)
#  com.netflix.ninja  com.amazon.amazonvideo.livingroom

# NIEMALS deaktivieren: com.google.android.tvlauncher, com.nvidia.blakepairing (Fernbedienung),
# com.android.tv.settings, com.google.android.gms, com.android.vending, com.nvidia.shieldtech.*

INSTALLED="$("${A[@]}" pm list packages | sed 's/^package://' | tr -d '\r')"
for p in "${PKGS[@]}"; do
  if ! grep -qx "$p" <<<"$INSTALLED"; then echo "  -- nicht vorhanden: $p"; continue; fi
  if [ "$DRY_RUN" = 1 ]; then echo "  [dry] würde deaktivieren: $p"; continue; fi
  if "${A[@]}" pm disable-user --user 0 "$p" | grep -q "disabled"; then
    echo "  OK  deaktiviert: $p"; echo "$p" >> "$LOG"
  else
    echo "  !!  fehlgeschlagen: $p"
  fi
done

# Animationen verkürzen (spürbar flottere Oberfläche)
if [ "$DRY_RUN" != 1 ]; then
  "${A[@]}" settings put global window_animation_scale 0.5
  "${A[@]}" settings put global transition_animation_scale 0.5
  "${A[@]}" settings put global animator_duration_scale 0.5
  echo ">> Fertig. Liste gespeichert in $LOG – Shield jetzt neu starten: adb -s $IP:5555 reboot"
fi
