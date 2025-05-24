# System Administration Scripts

A collection of useful system administration scripts organized by category for Linux systems, particularly Arch Linux.

## Repository Structure

This repository is organized into the following categories:

### 📦 `backup-tools/`
Comprehensive backup and restore solutions for Arch Linux systems.

- **`backup.sh`** - Full-featured backup script with multiple strategies
- **`restore.sh`** - Companion restore script for selective recovery
- **`README.md`** - Detailed documentation for backup/restore operations

**Features:**
- Incremental backups using rsync
- Package list backup and restore
- Configuration file backup
- Home directory backup
- Full system backup support
- Automatic cleanup of old backups

### 🌐 `networking/`
Network-related scripts and utilities.

- **`smb.sh`** - SMB/CIFS network share management script

### 📥 `installers/`
Installation and setup scripts for various applications and tools.

Currently contains scripts for automated software installation and configuration.

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/system-scripts.git
   cd system-scripts
   ```

2. Make scripts executable:
   ```bash
   find . -name "*.sh" -exec chmod +x {} \;
   ```

3. Navigate to the appropriate category folder and read the specific documentation.

## Usage Guidelines

- Each category folder contains its own documentation
- Always review scripts before running them
- Test scripts in a safe environment first
- Some scripts may require root privileges
- Check script requirements and dependencies

## Contributing

When adding new scripts:

1. Place them in the appropriate category folder
2. If creating a new category, update this README
3. Include proper documentation and usage examples
4. Follow existing code style and patterns
5. Test thoroughly before committing

## Categories

- **backup-tools**: System backup and restore utilities
- **networking**: Network configuration and management
- **installers**: Application installation and setup scripts

## License

These scripts are provided as-is for educational and practical use. Always test scripts thoroughly in your environment before production use.

## Safety Notice

⚠️ **Important**: These scripts can modify system files and configurations. Always:
- Read and understand scripts before running them
- Have backups before making system changes
- Test in non-production environments first
- Review logs after script execution

---

**Note**: This repository is actively maintained. Check back for updates and new scripts. 