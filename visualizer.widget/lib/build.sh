#!/bin/bash
# Build the visualizer daemon.
#
#   ./lib/build.sh
#
# Two things here are load-bearing and easy to get wrong:
#
#   1. Info.plist is linked into the binary as a __TEXT,__info_plist section.
#      A bare executable has nowhere else to declare NSMicrophoneUsageDescription,
#      and without that key macOS kills the process on first audio-device access.
#
#   2. The binary is ad-hoc signed with a stable identifier. TCC keys the
#      microphone grant to the code signature, so an unsigned binary gets asked
#      again on every rebuild. It still re-prompts when the code actually
#      changes (the cdhash moves), but not for unrelated reruns.
#
#      So APPROVE THAT PROMPT, and check afterwards if the daemon comes back
#      silent. A denied process is handed zero-filled buffers rather than an
#      error: capture starts, buffers arrive at a steady rate, nothing throws,
#      and every band reads 0. That is indistinguishable from a silent device and
#      survives restarting the daemon, the player and Loopback. A recorded deny
#      sticks, and tccutil cannot reset a bare binary by identifier, so it has to
#      be switched back on in System Settings > Privacy & Security > Microphone.
#      See the note under "Build the daemon" in README.md.
#
# The plist is NOT named Info.plist on purpose. codesign treats a directory
# containing an Info.plist as a bundle, and would then produce a bundle signature
# with a sealed resource directory over all of lib/ — which goes invalid the
# moment anything else in here changes, taking the TCC grant with it.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

SRC="visualizerd.swift"
OUT="visualizerd"
PLIST="visualizerd-info.plist"
IDENT="local.uebersicht.visualizerd"

echo "==> Compiling $SRC"
swiftc -O "$SRC" -o "$OUT" \
  -framework AVFoundation \
  -framework Accelerate \
  -framework Network \
  -framework CoreAudio \
  -Xlinker -sectcreate \
  -Xlinker __TEXT \
  -Xlinker __info_plist \
  -Xlinker "$PLIST"

echo "==> Signing (ad-hoc, identifier $IDENT)"
codesign --force --sign - --identifier "$IDENT" "$OUT"

echo "==> Built $(pwd)/$OUT"
echo
echo "Next:"
echo "  ./lib/visualizerd --list          # confirm the loopback device is visible"
echo "  ./lib/visualizerd                 # run it (approve the mic prompt once)"
