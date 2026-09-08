#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
cd "$(dirname "$0")"

echo "Running architecture self-check…"
bash ./self-check.sh
VERSION="${1:-1.0.0}"
bash ./build-local.sh "$VERSION"
echo "Release asset ready: dist/Social-Science-Paste-${VERSION}.dmg"
