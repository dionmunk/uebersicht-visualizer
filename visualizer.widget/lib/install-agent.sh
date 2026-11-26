#!/bin/bash
# Install (or remove) a LaunchAgent so visualizerd starts at login.
#
#   ./lib/install-agent.sh [device-name]   # install, default device "Music"
#   ./lib/install-agent.sh --system        # no virtual device: everything playing
#   ./lib/install-agent.sh --apps com.apple.Music,com.spotify.client
#   ./lib/install-agent.sh --uninstall
#
# Anything starting with "--" is handed to visualizerd as-is, so any of its options
# can go here (see ./lib/visualizerd --help).
#
# Running it under launchd rather than from the widget is deliberate: the widget
# has no business owning a long-lived audio process, and a launchd job gets a
# stable TCC identity so the microphone grant sticks instead of being attributed
# to whichever shell happened to spawn it.

set -euo pipefail

LABEL="local.uebersicht.visualizerd"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/visualizerd"

if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "==> Removed $LABEL"
  exit 0
fi

if [ "${1:-}" != "" ] && [ "${1#--}" != "$1" ]; then
  ARGS=("$@")
  DESC="$*"
else
  ARGS=(--device "${1:-Music}")
  DESC="device: ${1:-Music}"
fi

# Plist strings, so escape the three characters XML cares about.
ARG_XML=""
for a in "${ARGS[@]}"; do
  # sed, not ${a//&/&amp;}: in bash 5.2+ a bare & in that replacement means "the match".
  a="$(printf '%s' "$a" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  ARG_XML+=$'\t\t'"<string>$a</string>"$'\n'
done

if [ ! -x "$BIN" ]; then
  echo "!! $BIN not built yet. Run ./lib/build.sh first." >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$BIN</string>
$ARG_XML	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>/tmp/visualizerd.log</string>
	<key>StandardOutPath</key>
	<string>/tmp/visualizerd.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "==> Installed $LABEL ($DESC)"
echo "    log: /tmp/visualizerd.log"
echo "    remove with: ./lib/install-agent.sh --uninstall"
