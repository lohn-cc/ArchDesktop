# LUKS auto-unlock with TPM2 + Secure Boot (Arch, systemd-boot, UKI)

Captured from `lohncc` on 2026-11-16. Disk `/dev/nvme0n1p2`, LUKS2 UUID
`f4d66f5d-3b5b-4df8-8f97-2d07f7c15c75`, mapped as `root`, btrfs on top.

## Why Secure Boot first

The TPM releases the key only when PCR 7 (Secure Boot policy + the keys that
verified the boot chain) matches enrollment. With Secure Boot off, PCR 7 is the
same for any boot medium, so a live USB could ask the TPM for the key. With
Secure Boot on and *our* keys enrolled, only images we signed get that PCR
state.

## Stages

| # | Script | Needs | Result |
|---|---|---|---|
| 1 | `1-prepare.sh` | sudo | sbctl + keys, hooks `systemd`/`sd-encrypt`, `rd.luks.*` cmdline with `tpm2-device=auto`, UKIs rebuilt + signed, pre-change UKI kept as `arch-linux-backup.efi` |
| — | reboot | you | firmware (F1): Security → Secure Boot → **Reset to Setup Mode** (clear keys). Leave Secure Boot off. Boot Arch; passphrase prompt is now systemd's |
| 2 | `2-enroll-secureboot.sh` | sudo, Setup Mode | `chattr -i` on key efivars, `sbctl enroll-keys -m` (keeps Microsoft keys). Then firmware: turn Secure Boot **On** (Lenovo does not do it automatically) |
| 3 | `3-enroll-tpm2.sh [--pin]` | sudo, SB enabled | `systemd-cryptenroll --tpm2-pcrs=7`. Reboot: no passphrase |

Check after each reboot:

```
bootctl status | grep -E 'Secure Boot|Setup Mode'
sbctl status; sbctl verify
sudo lsinitcpio -a /boot/EFI/Linux/arch-linux.efi | grep -iE 'hooks|cmdline'
journalctl -b -u 'systemd-cryptsetup@*'     # "Unlocked ... via TPM2" after stage 3
```

## Ubuntu / Fedora and the "3rd Party UEFI CA" BIOS option

- Ubuntu and Fedora boot through `shim`, which Microsoft's *third-party* UEFI CA
  signs. With factory keys, Lenovo needs **Allow Microsoft 3rd Party UEFI CA**
  turned on for them to boot under Secure Boot.
- This Arch setup uses no shim. Its images are signed with our sbctl key, so
  that option does **not** fix a "Secure Boot Violation" here. Only enrolling
  our keys (stage 2) does.
- `sbctl enroll-keys -m` re-adds Microsoft's certificates, the third-party
  UEFI CA included, so Ubuntu/Fedora live USBs and Windows still boot after
  stage 2. Booting one changes PCR 7 for that boot only. The TPM won't unseal
  for it, and Arch still unlocks normally on its next boot.

## Maintenance

- `sbctl` installs a pacman hook that re-signs everything in its database on
  kernel / systemd updates. `sbctl verify` lists anything unsigned.
- A firmware update, a new bootloader, or toggling Secure Boot changes PCR 7:
  the TPM refuses, you type the passphrase, then run `recover.sh`.
- The passphrase keyslot is never removed. `--pin` adds a short PIN on top of
  the TPM, which protects a stolen laptop that boots straight to the login screen.
- Rollback to the old setup: pick `arch-linux-backup.efi` in the boot menu, then
  restore `/etc/mkinitcpio.conf.bak-2026-11-16` and `/etc/kernel/cmdline.bak-2026-11-16`,
  `mkinitcpio -P`, `sbctl sign-all`.
- Stale firmware entries (Windows, Fedora on partitions that no longer exist)
  are harmless; `efibootmgr -b XXXX -B` removes them.
