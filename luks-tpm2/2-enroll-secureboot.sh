#!/usr/bin/env bash
# Stage 2: enroll our Secure Boot keys (+ Microsoft vendor keys). Firmware MUST be in Setup Mode.
set -euo pipefail
sbctl status
if ! grep -q "Setup Mode:.*Enabled" <<<"$(sbctl status)"; then
  echo "Firmware is not in Setup Mode. Reboot -> firmware -> Security -> Secure Boot -> Reset to Setup Mode, then rerun." >&2
  exit 1
fi
chattr -i /sys/firmware/efi/efivars/{PK,KEK,db,dbx}-* 2>/dev/null || true   # kernel marks these immutable
sbctl enroll-keys -m         # -m keeps Microsoft keys (option ROMs, Windows)
sbctl verify
echo; echo "Keys enrolled. Reboot now; Secure Boot turns on automatically. Then run 3-enroll-tpm2.sh"
