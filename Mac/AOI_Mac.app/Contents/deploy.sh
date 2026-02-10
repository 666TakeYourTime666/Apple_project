#!/usr/bin/env bash
set -euo pipefail
# ---------- 0. 自提权 ----------
(( EUID == 0 )) || exec sudo -p "Password: " "$0" "$@"

# ---------- 1. 参数 ----------
ACTION=${1:-install}
TARGET_USER=${2:-}
[[ -n $TARGET_USER ]] || { echo "Usage: $0 {install|uninstall} <target_user>"; exit 1; }

USR=$TARGET_USER
HOM=$(eval echo ~"$USR")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---------- 2. 常量 ----------
BIN="/usr/local/bin"
LDD="/Library/LaunchDaemons"
LAG="$HOM/Library/LaunchAgents"
LOG="/var/log/aoi_backup.log"
PLD_D="zss.aoi_monitor.plist"
PLD_A="zss.aoi_startapp.plist"
TAR="/Applications/AOI_Mac.app/Contents/aoi_env.tgz"
TASK="/var/db/aoi/task"
MARK="_username_"
MONITOR_S="system/aoi_monitor"

# ---------- 3. 安装 ----------
do_install(){
  mkdir -p "$HOM/Desktop/AOI" "$HOM/Desktop/backup" "$BIN" "$LDD" "$LAG" "$TASK"
  touch "$LOG"
  chown "$USR":staff "$HOM/Desktop/AOI"
  chown root:wheel "$HOM/Desktop/backup" "$LOG"
  chmod 644 "$LOG"

  tar -xzf "$TAR" -C "$TMP"
  sed -i '' "s/$MARK/$USR/g" "$TMP"/*.{sh,py,plist}

  install -m 755 -o root -g wheel "$TMP/aoi_backup.sh"  "$BIN"
  install -m 755 -o root -g wheel "$TMP/aoi_control.py" "$BIN"
  install -m 644 -o root -g wheel "$TMP/$PLD_D" "$LDD"
  install -m 644 "$TMP/$PLD_A" "$LAG"
  chown "$USR":staff "$LAG/$PLD_A"
  launchctl enable "$MONITOR_S"
  launchctl bootstrap system "$LDD/$PLD_D"
  echo "$LOG root:wheel 644 3 20480 * Z" > /etc/newsyslog.d/aoi_backup.conf
  sudo -u "$USR" ln -sf /Applications/AOI_Mac.app "$HOM/Desktop/AOI_Mac"
  echo "AOI installed for $USR"
}

# ---------- 4. 卸载 ----------
do_uninstall(){
  launchctl bootout "$MONITOR_S"
  launchctl disable "$MONITOR_S"
  rm -f $LDD/aoi_backup_*.plist "$LDD/$PLD_D" "$LAG/$PLD_A" "$LOG" \
        "$BIN/aoi_backup.sh" "$BIN/aoi_control.py" \
        "$LOG" /etc/newsyslog.d/aoi_backup.conf "$HOM/Desktop/AOI_Mac"
  rm -rf "$HOM/Desktop/AOI" "$HOM/Desktop/backup" "$TASK"
  echo "AOI uninstalled for $USR"
}

# ---------- 5. 分支 ----------
case "$ACTION" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  *) echo "Usage: $0 {install|uninstall} <target_user>"; exit 1 ;;
esac
