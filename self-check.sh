#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
cd "$(dirname "$0")"
SRC="Sources/SocialSciencePaste/main.swift"

grep -q 'Timer.scheduledTimer' "$SRC"
grep -q 'observeClipboardChange' "$SRC"
grep -q 'originalSnapshot' "$SRC"
grep -q 'rewriteClipboardFromOriginalSnapshotIfPossible' "$SRC"
grep -q 'writeCleanedClipboard' "$SRC"
grep -q 'declareTypes(declaredTypes' "$SRC"
grep -q 'PreferenceKey.italic: false' "$SRC"
grep -q 'PreferenceKey.bold: false' "$SRC"
grep -q 'PreferenceKey.links: false' "$SRC"
grep -q 'containsStructuredTable' "$SRC"
grep -q 'org.nspasteboard.concealedtype' "$SRC"

# Paste must remain completely native. These mechanisms are forbidden in this architecture.
! grep -q 'RegisterEventHotKey' "$SRC"
! grep -q 'CGEvent' "$SRC"
! grep -q 'AXIsProcessTrusted' "$SRC"
! grep -q 'AXUIElement' "$SRC"
! grep -q 'keyCode' "$SRC"
! grep -q 'Paste and Match' "$SRC"
! grep -q 'Paste Text Only' "$SRC"

# No app-specific delivery paths.
! grep -qi 'com.microsoft.Outlook' "$SRC"
! grep -qi 'microsoft word' "$SRC"
! grep -qi 'docs.google' "$SRC"

printf 'Copy-time architecture self-check passed.
'
