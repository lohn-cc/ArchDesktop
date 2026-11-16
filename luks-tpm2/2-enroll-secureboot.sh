#!/usr/bin/env bash
# Stage 2: enroll our Secure Boot keys (+ Microsoft vendor keys). Firmware MUST be in Setup Mode.
set -euo pipefail
sbctl status
if ! sbctl status | grep -q 'Setup Mode:.*Enabled'; then
  echo "Firmware is not in Setup Mode. Reboot -> firmware -> Security -> Secure Boot -> Reset to Setup Mode, then rerun." >&2
  exit 1
fi
sbctl enroll-keys -m          # -m keeps Microsoft keys (option ROMs, Windows)
sbctl verify
echo; echo "Keys enrolled. Reboot now; Secure Boot turns on automatically. Then run 3-enroll-tpm2.sh"
