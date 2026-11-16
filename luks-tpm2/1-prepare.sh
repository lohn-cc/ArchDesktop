#!/usr/bin/env bash
# Stage 1 of Secure Boot + TPM2 LUKS unlock. Safe to re-run. Does NOT enroll keys or touch the TPM.
set -euo pipefail
D=2026-11-16
UUID=f4d66f5d-3b5b-4df8-8f97-2d07f7c15c75
say(){ printf '\n==> %s\n' "$*"; }

say "packages"; pacman -S --needed --noconfirm sbctl tpm2-tools >/dev/null && echo ok

say "sbctl keys"; [ -d /var/lib/sbctl/keys ] || sbctl create-keys; sbctl status

say "backups"
cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak-$D
cp -n /etc/kernel/cmdline  /etc/kernel/cmdline.bak-$D
cp /boot/EFI/Linux/arch-linux.efi /boot/EFI/Linux/arch-linux-backup.efi   # pre-change UKI (encrypt hook, old cmdline)
ls -la /etc/mkinitcpio.conf.bak-$D /etc/kernel/cmdline.bak-$D /boot/EFI/Linux/arch-linux-backup.efi

say "initramfs hooks -> systemd + sd-encrypt"
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
grep '^HOOKS' /etc/mkinitcpio.conf

say "kernel cmdline -> rd.luks (TPM2 auto, falls back to passphrase until enrolled)"
printf 'rd.luks.name=%s=root rd.luks.options=%s=discard,tpm2-device=auto root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs\n' "$UUID" "$UUID" > /etc/kernel/cmdline
cat /etc/kernel/cmdline

say "rebuild UKIs"; mkinitcpio -P 2>&1 | grep -E 'Image generation|UKI|ERROR|WARNING' || true

say "sign bootloader + UKIs (saved in sbctl db, re-signed on updates by its pacman hook)"
for f in /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/systemd/systemd-boot-fallbackx64.efi /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/Linux/*.efi; do
  [ -f "$f" ] && sbctl sign -s "$f"
done
sbctl verify

say "boot entries now"; ls -la /boot/EFI/Linux/
say "DONE stage 1. Next: reboot into firmware (F1), Security -> Secure Boot -> Reset to Setup Mode / Clear keys. Keep Secure Boot OFF for now."
