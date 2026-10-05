#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_B64="${RUNNER_TEMP:-/tmp}/moi-finansy-source.b64"
TMP_TGZ="${RUNNER_TEMP:-/tmp}/moi-finansy-source.tar.gz"

cd "$ROOT"
cat bundle2/part-*.b64 > "$TMP_B64"
base64 --decode "$TMP_B64" > "$TMP_TGZ"

EXPECTED="27007763a1f15c222246a3578fee3cb9945abf585150df82cd37a616e62ba41e"
ACTUAL="$(sha256sum "$TMP_TGZ" | awk '{print $1}')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "Source bundle checksum mismatch: $ACTUAL" >&2
  exit 1
fi

tar -xzf "$TMP_TGZ" -C "$ROOT"
echo "Source bundle unpacked successfully."
