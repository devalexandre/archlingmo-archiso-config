#!/usr/bin/env bash
set -euo pipefail

LOCKFILE="/run/calamares-autostart.lock"
LOGFILE="/tmp/calamares-autostart.log"

{
  echo "----"
  echo "$(date -Is) starting autostart-calamares"
  echo "DISPLAY=${DISPLAY:-} XAUTHORITY=${XAUTHORITY:-}"
} >>"$LOGFILE"

if [ -e "$LOCKFILE" ]; then
  if pgrep -x calamares >/dev/null 2>&1; then
    echo "calamares already running; exiting" >>"$LOGFILE"
    exit 0
  fi
  echo "stale lock detected; removing" >>"$LOGFILE"
  rm -f "$LOCKFILE"
fi
touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

use_software=0
if [ -n "${LINGMO_FORCE_SOFTWARE:-}" ]; then
  use_software=1
elif [ ! -e /dev/dri/renderD128 ] && [ ! -e /dev/dri/card0 ]; then
  use_software=1
fi

if [ "$use_software" -eq 1 ]; then
  export QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}"
  export QT_OPENGL="${QT_OPENGL:-software}"
  export QSG_RHI_BACKEND="${QSG_RHI_BACKEND:-software}"
  export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-basic}"
  export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
else
  [ -z "${QSG_RHI_BACKEND:-}" ] && export QSG_RHI_BACKEND=opengl
  [ -z "${QT_OPENGL:-}" ] && export QT_OPENGL=desktop
  [ -z "${LIBGL_ALWAYS_SOFTWARE:-}" ] && export LIBGL_ALWAYS_SOFTWARE=0
fi
export QT_QUICK_CONTROLS_STYLE="${QT_QUICK_CONTROLS_STYLE:-lingmo-style}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-lingmo}"
export QT_STYLE_OVERRIDE="${QT_STYLE_OVERRIDE:-lingmo-style}"
export QT_QUICK_CONTROLS_STYLE_PATH="${QT_QUICK_CONTROLS_STYLE_PATH:+$QT_QUICK_CONTROLS_STYLE_PATH:}/usr/lib/qt/qml/QtQuick/Controls.2"
export QML_IMPORT_PATH="${QML_IMPORT_PATH:+$QML_IMPORT_PATH:}/usr/lib/qt/qml"
export QML2_IMPORT_PATH="${QML2_IMPORT_PATH:+$QML2_IMPORT_PATH:}/usr/lib/qt/qml"
export QT_PLUGIN_PATH="${QT_PLUGIN_PATH:+$QT_PLUGIN_PATH:}/usr/lib/qt/plugins"
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-qt.qml.warning=true;qt.qml.debug=false}"

if [ -z "${XAUTHORITY:-}" ]; then
  uid="$(id -u)"
  for candidate in "/run/user/${uid}/.Xauthority" "$HOME/.Xauthority"; do
    if [ -f "$candidate" ]; then
      export XAUTHORITY="$candidate"
      break
    fi
  done
fi

if command -v calamares_polkit >/dev/null 2>&1; then
  echo "launching calamares_polkit" >>"$LOGFILE"
  exec calamares_polkit >>"$LOGFILE" 2>&1
fi

if command -v pkexec >/dev/null 2>&1; then
  echo "launching calamares via pkexec" >>"$LOGFILE"
  exec pkexec env \
    DISPLAY="${DISPLAY:-:0}" \
    XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
    QT_QUICK_BACKEND="$QT_QUICK_BACKEND" \
    QT_OPENGL="$QT_OPENGL" \
    QSG_RHI_BACKEND="$QSG_RHI_BACKEND" \
    QSG_RENDER_LOOP="$QSG_RENDER_LOOP" \
    LIBGL_ALWAYS_SOFTWARE="$LIBGL_ALWAYS_SOFTWARE" \
    QT_QUICK_CONTROLS_STYLE="$QT_QUICK_CONTROLS_STYLE" \
    calamares >>"$LOGFILE" 2>&1
fi

if command -v sudo >/dev/null 2>&1; then
  echo "launching calamares via sudo" >>"$LOGFILE"
  exec sudo -E calamares >>"$LOGFILE" 2>&1
fi

echo "calamares binary not found or failed to start" >>"$LOGFILE"
exit 1
