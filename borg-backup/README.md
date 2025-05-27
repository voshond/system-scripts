# Borg Backup Setup on Arch Linux

This repository contains a script to set up automated daily backups of your `/home` directory using [BorgBackup](https://borgbackup.readthedocs.io/en/stable/) on Arch Linux.

Backups are stored in a local Borg repository (e.g. `/mnt/archBackup01/borg_repo`) and are managed using a `systemd` timer that runs once daily when the system is on.

---

## 🔐 Features

- Installs Borg if not present
- Initializes a local encrypted Borg repository
- Backs up your home directory daily (once per day)
- Uses a fixed snapshot name (`home-latest`) to keep only the most recent backup
- Skips large or unnecessary folders (`.cache`, `Downloads`)
- Uses `systemd` for reliable, event-based scheduling

---

## 🛠️ Installation

1. **Mount your backup drive** (e.g. at `/mnt/archBackup01`)
2. **Clone this repo**:
```shell
   git clone https://github.com/voshond/system-scripts
   cd system-scripts/borg-backup
```
3. **Run the setup script**:
```shell
   chmod +x borg_backup.sh
   ./borg_backup.sh
```

---

## 📁 Backup Destination

Backups are stored at:

`/mnt/archBackup01/borg_repo`

Ensure this mount point exists and is writable before running the setup.

---

## 🕒 How It Works

* A systemd timer (`borg-backup.timer`) runs daily
* The timer triggers a service (`borg-backup.service`) that executes the backup script
* The backup creates or replaces a snapshot named `home-latest`

---

## 🔁 Manual Backup

To run a backup manually:

```bash
sudo /usr/local/bin/borg_backup.sh
```

---

## 🔍 Checking Backup

List all backups:

```bash
borg list /mnt/archBackup01/borg_repo
```

---

## 📥 Restore Files

To restore:

```bash
borg extract /mnt/archBackup01/borg_repo::home-latest
```

Or extract a specific folder:

```bash
borg extract /mnt/archBackup01/borg_repo::home-latest home/voshond/Documents
```

---

## 📋 Requirements

* Arch Linux
* A mounted backup destination (e.g. external drive)
* Sufficient permissions to run systemd services

---

## ✅ Customization

* Edit `/usr/local/bin/borg_backup.sh` to exclude/include specific folders
* Adjust timer frequency by editing `/etc/systemd/system/borg-backup.timer`

