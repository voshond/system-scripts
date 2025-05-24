# Arch Linux Backup & Restore Scripts

A comprehensive backup and restore solution for Arch Linux systems with support for multiple backup strategies.

## Features

- 📦 **Package Backup**: Save lists of installed packages (official repos + AUR)
- ⚙️ **Configuration Backup**: Backup system and user configuration files
- 🏠 **Home Directory Backup**: Compressed backup of user data (excluding cache/temp files)
- 💻 **Full System Backup**: Complete system backup (requires root)
- 🔄 **Incremental Backup**: Space-efficient incremental backups using rsync
- 🧹 **Automatic Cleanup**: Remove old backups to save space
- 📝 **Detailed Logging**: All operations are logged for audit purposes
- 🎨 **Colored Output**: Easy-to-read colored terminal output

## Prerequisites

- An external backup drive mounted at `@archBackup01` (250GB in your case)
- Standard Arch Linux utilities (`tar`, `rsync`, `pacman`)
- Optional: `yay` for AUR package support

## Setup

1. Ensure your backup drive is mounted:
   ```bash
   # Check if the mount point exists
   ls -la @archBackup01
   
   # If not mounted, mount your backup drive
   sudo mount /dev/sdX1 @archBackup01  # Replace sdX1 with your drive
   ```

2. Make scripts executable (if not already done):
   ```bash
   chmod +x backup.sh restore.sh
   ```

## Backup Usage

### Quick Start
```bash
# Show available options
./backup.sh --help

# Create a complete backup (packages + configs + home + system if root)
./backup.sh --all

# Create space-efficient incremental backup (recommended for regular use)
./backup.sh --incremental
```

### Backup Types

#### 1. Package Lists Only
```bash
./backup.sh --packages
```
Creates:
- List of explicitly installed packages
- List of all packages
- AUR packages (if `yay` is installed)
- Pacman database (if run as root)

#### 2. Configuration Files Only
```bash
./backup.sh --configs
```
Backs up:
- System configs: `/etc/fstab`, `/etc/pacman.conf`, systemd configs, etc.
- User configs: `.bashrc`, `.zshrc`, `.config/`, `.ssh/`, etc.

#### 3. Home Directory Only
```bash
./backup.sh --home
```
Creates compressed backup excluding:
- Cache directories
- Browser caches
- Downloads folder
- Temporary files

#### 4. Full System Backup (requires root)
```bash
sudo ./backup.sh --system
```
Creates complete system backup excluding:
- Virtual filesystems (`/proc`, `/sys`, `/dev`)
- Temporary directories
- Mount points
- Package cache

#### 5. Incremental Backup (recommended)
```bash
./backup.sh --incremental
```
- Uses rsync with hard links for space efficiency
- First backup is full, subsequent ones only store changes
- Much faster than full backups after initial run

#### 6. Cleanup Old Backups
```bash
./backup.sh --cleanup
```

### Example Backup Strategy

For regular use, consider this approach:

```bash
# Daily incremental backups
./backup.sh --incremental

# Weekly package list backup
./backup.sh --packages

# Monthly full backup with cleanup
sudo ./backup.sh --all
./backup.sh --cleanup
```

## Restore Usage

### Quick Start
```bash
# List all available backups
./restore.sh --list

# Restore packages from a specific backup
./restore.sh --packages 20241201_143022

# Restore configurations
./restore.sh --configs 20241201_143022

# Restore home directory
./restore.sh --home home-hostname-20241201_143022.tar.gz
```

### Restore Types

#### 1. List Available Backups
```bash
./restore.sh --list
```

#### 2. Restore Packages
```bash
./restore.sh --packages 20241201_143022
```
- Installs packages from backup using `yay` (if available) or `pacman`
- Uses `--needed` flag to avoid reinstalling existing packages
- Can restore pacman database (if backup available and running as root)

#### 3. Restore Configurations
```bash
./restore.sh --configs 20241201_143022
```
- Restores system configs (requires root)
- Restores user configs to current user's home directory

#### 4. Restore Home Directory
```bash
./restore.sh --home home-hostname-20241201_143022.tar.gz
```

#### 5. Restore Full System (DESTRUCTIVE!)
```bash
sudo ./restore.sh --incremental hostname/20241201_143022
```
⚠️ **WARNING**: This overwrites system files! Only use for disaster recovery.

## File Structure

Backups are organized as follows:
```
@archBackup01/arch-backups/
├── backup.log                    # Main backup log
├── restore.log                   # Restore operations log
├── packages/
│   └── 20241201_143022/
│       ├── explicitly-installed.txt
│       ├── all-packages.txt
│       ├── aur-packages.txt
│       └── pacman-database.tar.gz
├── configs/
│   └── 20241201_143022/
│       ├── etc/                   # System configs
│       └── user/                  # User configs
├── home/
│   └── home-hostname-20241201_143022.tar.gz
├── system/
│   └── system-hostname-20241201_143022.tar.gz
└── incremental/
    └── hostname/
        ├── latest -> snapshots/20241201_143022
        └── snapshots/
            ├── 20241201_143022/
            └── 20241201_150000/
```

## Tips & Best Practices

### Space Management
- **Incremental backups** are most space-efficient for regular use
- The script automatically cleans old backups (keeps last 5-10 of each type)
- Monitor space usage: `df -h @archBackup01`

### Security
- Home directory backups exclude cache but include `.ssh/` (contains private keys)
- Consider encrypting sensitive backups
- Restrict access to backup scripts and mount point

### Recovery Planning
1. **Test restores regularly** - ensure backups work when needed
2. **Document your system** - keep notes about custom configurations
3. **Bootable media** - have an Arch Linux USB ready for bare-metal recovery

### Automation
Consider adding to crontab for automated backups:
```bash
# Edit crontab
crontab -e

# Add lines like:
# Daily incremental backup at 2 AM
0 2 * * * /home/voshond/scripts/backup.sh --incremental >/dev/null 2>&1

# Weekly package backup on Sundays at 3 AM
0 3 * * 0 /home/voshond/scripts/backup.sh --packages >/dev/null 2>&1
```

## Troubleshooting

### Common Issues

**"Backup mount point does not exist"**
- Ensure your backup drive is mounted at `@archBackup01`
- Check `/etc/fstab` for automatic mounting

**"Permission denied"**
- Some operations require root privileges
- Use `sudo` for system-level operations

**"Low disk space"**
- Run cleanup: `./backup.sh --cleanup`
- Consider using incremental backups instead of full backups
- Compress large backups manually if needed

**"Package restore fails"**
- Check if AUR helper (`yay`) is installed for AUR packages
- Some packages may no longer be available in repositories

### Logs
Check logs for detailed information:
```bash
# View backup logs
tail -f @archBackup01/arch-backups/backup.log

# View restore logs
tail -f @archBackup01/arch-backups/restore.log
```

## Customization

You can modify the scripts to suit your needs:

- **Backup location**: Change `BACKUP_MOUNT` variable in both scripts
- **Retention policy**: Modify cleanup functions to keep more/fewer backups
- **Exclusions**: Edit exclude patterns in backup functions
- **Additional configs**: Add more paths to `system_configs` or `user_configs` arrays

## License

These scripts are provided as-is for educational and practical use. Test thoroughly before relying on them for critical data.

---

**Remember**: The best backup is the one you test! Regularly verify that your backups work by doing test restores. 