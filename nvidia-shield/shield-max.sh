#!/bin/sh
# Shield Pro – maximal entschlacken (POSIX sh, läuft in iSH auf dem iPad)
# Aufruf: sh shield-max.sh 192.168.178.108      Rückgängig: sh shield-max.sh 192.168.178.108 restore
IP="${1:?IP fehlt}"; D="$IP:5555"; LOG=~/shield-disabled.txt
STREAMING=0   # 1 = auch Netflix, Prime, YouTube, Spotify, Disney+ deaktivieren
adb connect "$D" >/dev/null; adb -s "$D" get-state >/dev/null 2>&1 || { echo "Keine Verbindung"; exit 1; }
S="adb -s $D shell"
if [ "${2:-}" = restore ]; then
  for p in $(cat "$LOG"); do $S pm enable "$p" >/dev/null && echo "aktiviert: $p"; done
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do $S settings put global $k 1; done
  rm -f "$LOG"; echo FERTIG; exit 0
fi
PKGS="
com.nvidia.diagtools com.nvidia.feedback com.nvidia.stats com.nvidia.ocs com.nvidia.tegrazone3
com.nvidia.nvgamecast com.nvidia.shield.nvcustomize com.nvidia.shield.remote.server com.plexapp.mediaserver.smb
com.google.android.feedback com.google.android.partnersetup com.google.android.tvrecommendations
com.google.android.leanbacklauncher.recommendations com.google.android.play.games com.google.android.videos
com.google.android.youtube.tvmusic com.google.android.marvin.talkback com.google.android.syncadapters.calendar
com.google.android.syncadapters.contacts com.google.android.backdrop com.google.android.katniss
com.google.android.speech.pumpkin com.google.android.tv.remote.service com.google.android.tv.bugreportsender
com.google.android.tts
com.android.printspooler com.android.bips com.android.bookmarkprovider com.android.gallery3d com.android.dreams.basic
com.android.musicfx com.android.egg com.android.wallpaperbackup com.android.wallpaper.livepicker
com.android.sharedstoragebackup com.android.calllogbackup"
[ "$STREAMING" = 1 ] && PKGS="$PKGS com.netflix.ninja com.amazon.amazonvideo.livingroom com.google.android.youtube.tv com.spotify.tv.android com.disney.disneyplus"
# Schutzliste – wird nie angefasst
KEEP="com.google.android.tvlauncher com.nvidia.blakepairing com.google.android.gms com.android.vending com.android.tv.settings com.google.android.apps.mediashell com.android.systemui com.google.android.gsf"
ON="$($S pm list packages -e | sed 's/package://' | tr -d '\r')"
for p in $PKGS; do
  case " $KEEP " in *" $p "*) continue;; esac
  case "$p" in com.nvidia.shieldtech*) continue;; esac
  echo "$ON" | grep -qx "$p" || { echo "-- übersprungen: $p"; continue; }
  $S pm disable-user --user 0 "$p" | grep -q disabled && { echo "OK  $p"; echo "$p" >> "$LOG"; } || echo "!!  $p"
done
for k in window_animation_scale transition_animation_scale animator_duration_scale; do $S settings put global $k 0; done
echo "FERTIG – Liste: $LOG. Jetzt neu starten: adb -s $D reboot"
