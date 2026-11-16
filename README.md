# ArchDesktop

Setup records for my Arch Linux + KDE Plasma machines, so a new computer can be
brought to the same state quickly.

| Folder / file | What |
|---|---|
| `fingerprint-auth/` | fprintd + PAM fingerprint auth for login, lock, polkit, sudo. `install.sh` + notes. |
| `wireless-display-kit/` | Wireless display helper (launchers, systemd units, installer). |
| `luks-tpm2/` | LUKS auto-unlock via TPM2 (PCR 7) with Secure Boot on own sbctl keys + Microsoft keys. Staged scripts, recovery, rollback. |
| `HANDOFF.md` | Running log for `lohncc`: 2026-11-14 system tuning (snapper, TRIM, zram, LTS fallback, battery limit); 2026-11-16 fingerprint auth, NOPASSWD removal, KWallet off, wireless display phone wizard, LUKS TPM2 + Secure Boot; open items. Read this first on a new session. |

Each folder is self-contained and has its own README.
