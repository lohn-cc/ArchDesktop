#!/usr/bin/env bash
# If the TPM refuses after a firmware/bootloader update: boot with the passphrase, then re-seal.
set -euo pipefail
DEV=/dev/disk/by-uuid/f4d66f5d-3b5b-4df8-8f97-2d07f7c15c75
systemd-cryptenroll --wipe-slot=tpm2 "$DEV"
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$DEV"
