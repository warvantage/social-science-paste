# SPDX-License-Identifier: MPL-2.0
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = (root / "Sources/SocialSciencePaste/main.swift").read_text()

# Paste must be invisible to the app.
for forbidden in [
    "RegisterEventHotKey", "CGEvent", "AXUIElement", "AXIsProcessTrusted",
    "Paste and Match", "Paste Text Only", "keyCode"
]:
    assert forbidden not in src, f"forbidden paste-time mechanism found: {forbidden}"

# Core copy-time architecture.
for required in [
    "originalSnapshot", "observeClipboardChange", "captureStableClipboardSnapshot",
    "writeCleanedClipboard", "rewriteClipboardFromOriginalSnapshotIfPossible",
    "if output.htmlData != nil { declaredTypes.append(.html) }",
    "declaredTypes.append(.string)",
    "PreferenceKey.italic: false", "PreferenceKey.bold: false", "PreferenceKey.links: false"
]:
    assert required in src, f"missing architecture invariant: {required}"

# Rich representation must be offered before plain text fallback.
assert src.index("if output.htmlData != nil { declaredTypes.append(.html) }") < src.index("declaredTypes.append(.string)")

# Selected semantic HTML must never deliberately emit source font/size/style CSS.
fragment_start = src.index("private func semanticFragment")
fragment_end = src.index("private func attributesEquivalentForPaste")
fragment = src[fragment_start:fragment_end]
for forbidden in ["font-family", "font-size", "background-color", "style=", "<font"]:
    assert forbidden not in fragment, f"presentation styling emitted by semantic HTML: {forbidden}"

# Non-text / table pass-through guards remain present.
assert "containsNonTextPayload" in src
assert "containsStructuredTable" in src
assert "org.nspasteboard.concealedtype" in src

# No target-app special cases.
for forbidden in ["com.microsoft.Outlook", "Microsoft Word", "docs.google"]:
    assert forbidden.lower() not in src.lower(), f"target-app special case found: {forbidden}"

print("Architecture tests passed.")
