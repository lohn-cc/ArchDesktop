#!/usr/bin/env bash
# Stage 3: seal a LUKS key in the TPM2, bound to Secure Boot state (PCR 7). Asks for the LUKS passphrase once.
#   ./3-enroll-tpm2.sh          # no PIN
#   ./3-enroll-tpm2.sh --pin    # also require a PIN at boot
set -euo pipefail
DEV=/dev/disk/by-uuid/f4d66f5d-3b5b-4df8-8f97-2d07f7c15c75
if ! grep -q "Secure Boot: enabled" <<<"$(bootctl status 2>/dev/null || true)"; then
  echo "Secure Boot is not enabled; enrolling now would bind to the wrong PCR 7 state. Enable it first." >&2
  exit 1
fi
PIN=(); [ "${1:-}" = "--pin" ] && PIN=(--tpm2-with-pin=yes)
systemd-cryptenroll --wipe-slot=tpm2 "$DEV" 2>/dev/null || true     # replace any old TPM slot
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "${PIN[@]}" "$DEV"
echo; cryptsetup luksDump "$DEV" | grep -E 'Keyslots:|^\s+[0-9]+: luks2|Tokens:|systemd-tpm2'
echo; echo "Enrolled. Reboot: the disk should unlock without the passphrase (passphrase still works as fallback)."
