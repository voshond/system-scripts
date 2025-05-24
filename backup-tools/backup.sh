#!/bin/bash

# =============================================================================
# Arch Linux Backup Script
# =============================================================================
# This script provides comprehensive backup functionality for Arch Linux
# Author: Generated for user
# Usage: ./backup.sh [options]
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
BACKUP_MOUNT="@archBackup01"
BACKUP_BASE="$BACKUP_MOUNT/arch-backups"
LOG_FILE="$BACKUP_BASE/backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    log "INFO" "$*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    log "SUCCESS" "$*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    log "WARNING" "$*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    log "ERROR" "$*"
}

# =============================================================================
# Validation Functions
# =============================================================================

check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check if running as root for system backup
    if [[ $EUID -ne 0 ]]; then
        warning "Not running as root. Some system files may not be accessible."
        warning "Consider running with sudo for complete system backup."
    fi
    
    # Check if backup mount point exists
    if [[ ! -d "$BACKUP_MOUNT" ]]; then
        error "Backup mount point $BACKUP_MOUNT does not exist!"
        error "Please ensure your backup disk is mounted at $BACKUP_MOUNT"
        exit 1
    fi
    
    # Check available space
    local available_space=$(df "$BACKUP_MOUNT" | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    info "Available backup space: ${available_gb}GB"
    
    if [[ $available_gb -lt 10 ]]; then
        warning "Low disk space on backup drive: ${available_gb}GB remaining"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Create backup directories
    mkdir -p "$BACKUP_BASE/system"
    mkdir -p "$BACKUP_BASE/packages"
    mkdir -p "$BACKUP_BASE/configs"
    mkdir -p "$BACKUP_BASE/home"
    mkdir -p "$BACKUP_BASE/incremental"
}

# =============================================================================
# Backup Functions
# =============================================================================

backup_packages() {
    info "Backing up package lists..."
    local pkg_dir="$BACKUP_BASE/packages/$DATE"
    mkdir -p "$pkg_dir"
    
    # Backup explicit packages
    pacman -Qe > "$pkg_dir/explicitly-installed.txt"
    
    # Backup all packages
    pacman -Q > "$pkg_dir/all-packages.txt"
    
    # Backup AUR packages (if yay is installed)
    if command -v yay &> /dev/null; then
        yay -Qm > "$pkg_dir/aur-packages.txt"
    fi
    
    # Backup pacman database
    if [[ $EUID -eq 0 ]]; then
        tar czf "$pkg_dir/pacman-database.tar.gz" -C /var/lib/pacman local
    fi
    
    success "Package lists backed up to $pkg_dir"
}

backup_system_configs() {
    info "Backing up system configuration files..."
    local config_dir="$BACKUP_BASE/configs/$DATE"
    mkdir -p "$config_dir"
    
    # Important system config files
    local system_configs=(
        "/etc/fstab"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/locale.conf"
        "/etc/vconsole.conf"
        "/etc/mkinitcpio.conf"
        "/etc/pacman.conf"
        "/etc/makepkg.conf"
        "/boot/loader"
        "/etc/systemd"
        "/etc/NetworkManager"
        "/etc/X11"
    )
    
    for config in "${system_configs[@]}"; do
        if [[ -e "$config" ]]; then
            # Preserve directory structure
            local dest_dir="$config_dir$(dirname "$config")"
            mkdir -p "$dest_dir"
            cp -a "$config" "$dest_dir/" 2>/dev/null || warning "Failed to backup $config"
        fi
    done
    
    success "System configurations backed up to $config_dir"
}

backup_user_configs() {
    info "Backing up user configuration files..."
    local user_config_dir="$BACKUP_BASE/configs/$DATE/user"
    mkdir -p "$user_config_dir"
    
    # Backup current user's config files
    local user_configs=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.vimrc"
        "$HOME/.gitconfig"
        "$HOME/.ssh"
        "$HOME/.config"
        "$HOME/.local/share/applications"
    )
    
    for config in "${user_configs[@]}"; do
        if [[ -e "$config" ]]; then
            cp -a "$config" "$user_config_dir/" 2>/dev/null || warning "Failed to backup $config"
        fi
    done
    
    success "User configurations backed up to $user_config_dir"
}

backup_home_directory() {
    info "Backing up home directory (excluding cache and temp files)..."
    local home_backup="$BACKUP_BASE/home/home-$HOSTNAME-$DATE.tar.gz"
    
    # Exclude patterns for home backup
    local exclude_file="/tmp/backup_home_excludes"
    cat > "$exclude_file" << EOF
.cache/*
.local/share/Trash/*
.thumbnails/*
.gvfs
.mozilla/firefox/*/Cache/*
.config/google-chrome/*/Cache/*
.config/chromium/*/Cache/*
Downloads/
*.tmp
*.temp
*.log
EOF
    
    info "Creating compressed home directory backup..."
    if tar czf "$home_backup" -X "$exclude_file" -C "$(dirname "$HOME")" "$(basename "$HOME")" 2>/dev/null; then
        success "Home directory backed up to $home_backup"
        local backup_size=$(du -h "$home_backup" | cut -f1)
        info "Backup size: $backup_size"
    else
        error "Failed to create home directory backup"
    fi
    
    rm -f "$exclude_file"
}

backup_system_full() {
    if [[ $EUID -ne 0 ]]; then
        warning "Skipping full system backup - requires root privileges"
        return
    fi
    
    info "Creating full system backup (this may take a while)..."
    local system_backup="$BACKUP_BASE/system/system-$HOSTNAME-$DATE.tar.gz"
    
    # Exclude patterns for system backup
    local exclude_file="/tmp/backup_system_excludes"
    cat > "$exclude_file" << EOF
/dev/*
/proc/*
/sys/*
/tmp/*
/run/*
/mnt/*
/media/*
/lost+found
/var/cache/pacman/pkg/*
/var/tmp/*
/var/log/*
$BACKUP_MOUNT/*
EOF
    
    info "Creating compressed system backup (excluding mount points and temporary files)..."
    if tar czf "$system_backup" -X "$exclude_file" -C / . 2>/dev/null; then
        success "System backup created: $system_backup"
        local backup_size=$(du -h "$system_backup" | cut -f1)
        info "System backup size: $backup_size"
    else
        error "Failed to create system backup"
    fi
    
    rm -f "$exclude_file"
}

backup_incremental() {
    info "Creating incremental backup using rsync..."
    local incremental_dir="$BACKUP_BASE/incremental/$HOSTNAME"
    local snapshot_dir="$incremental_dir/snapshots/$DATE"
    local latest_link="$incremental_dir/latest"
    
    mkdir -p "$snapshot_dir"
    
    # Rsync options for incremental backup
    local rsync_opts=(
        -av
        --delete
        --hard-links
        --link-dest="$latest_link"
        --exclude-from=<(cat << EOF
/dev/*
/proc/*
/sys/*
/tmp/*
/run/*
/mnt/*
/media/*
/lost+found
/var/cache/pacman/pkg/*
/var/tmp/*
$BACKUP_MOUNT/*
EOF
)
    )
    
    info "Running incremental backup to $snapshot_dir..."
    if rsync "${rsync_opts[@]}" / "$snapshot_dir/"; then
        # Update latest symlink
        rm -f "$latest_link"
        ln -s "snapshots/$DATE" "$latest_link"
        success "Incremental backup completed: $snapshot_dir"
        
        # Show backup statistics
        local backup_size=$(du -sh "$snapshot_dir" | cut -f1)
        info "Incremental backup size: $backup_size"
    else
        error "Incremental backup failed"
    fi
}

# =============================================================================
# Cleanup Functions
# =============================================================================

cleanup_old_backups() {
    info "Cleaning up old backups (keeping last 5 of each type)..."
    
    # Cleanup old package backups
    find "$BACKUP_BASE/packages" -maxdepth 1 -type d -name "[0-9]*" | sort -r | tail -n +6 | xargs rm -rf 2>/dev/null || true
    
    # Cleanup old config backups
    find "$BACKUP_BASE/configs" -maxdepth 1 -type d -name "[0-9]*" | sort -r | tail -n +6 | xargs rm -rf 2>/dev/null || true
    
    # Cleanup old home backups
    find "$BACKUP_BASE/home" -name "home-*.tar.gz" | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    
    # Cleanup old system backups
    find "$BACKUP_BASE/system" -name "system-*.tar.gz" | sort -r | tail -n +4 | xargs rm -f 2>/dev/null || true
    
    # Cleanup old incremental snapshots (keep last 10)
    if [[ -d "$BACKUP_BASE/incremental/$HOSTNAME/snapshots" ]]; then
        find "$BACKUP_BASE/incremental/$HOSTNAME/snapshots" -maxdepth 1 -type d -name "[0-9]*" | sort -r | tail -n +11 | xargs rm -rf 2>/dev/null || true
    fi
    
    success "Cleanup completed"
}

# =============================================================================
# Main Functions
# =============================================================================

show_usage() {
    cat << EOF
Arch Linux Backup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -a, --all           Run all backup types (packages, configs, home, system)
    -p, --packages      Backup package lists only
    -c, --configs       Backup configuration files only
    -h, --home          Backup home directory only
    -s, --system        Backup full system (requires root)
    -i, --incremental   Create incremental backup using rsync
    -k, --cleanup       Clean up old backups
    --help              Show this help message

EXAMPLES:
    $0 --all            # Full backup (all types)
    $0 --packages       # Just backup package lists
    $0 --incremental    # Create space-efficient incremental backup
    sudo $0 --system    # Full system backup (as root)

The backup disk should be mounted at: $BACKUP_MOUNT
Backups are stored in: $BACKUP_BASE
EOF
}

main() {
    # Initialize log
    mkdir -p "$(dirname "$LOG_FILE")"
    
    info "=== Arch Linux Backup Script Started ==="
    info "Date: $DATE"
    info "Hostname: $HOSTNAME"
    info "User: $(whoami)"
    
    check_prerequisites
    
    case "${1:-}" in
        -a|--all)
            backup_packages
            backup_system_configs
            backup_user_configs
            backup_home_directory
            if [[ $EUID -eq 0 ]]; then
                backup_system_full
            fi
            cleanup_old_backups
            ;;
        -p|--packages)
            backup_packages
            ;;
        -c|--configs)
            backup_system_configs
            backup_user_configs
            ;;
        -h|--home)
            backup_home_directory
            ;;
        -s|--system)
            backup_system_full
            ;;
        -i|--incremental)
            backup_incremental
            cleanup_old_backups
            ;;
        -k|--cleanup)
            cleanup_old_backups
            ;;
        --help)
            show_usage
            exit 0
            ;;
        "")
            warning "No backup type specified. Use --help for options."
            echo
            show_usage
            exit 1
            ;;
        *)
            error "Unknown option: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
    
    success "=== Backup Script Completed ==="
}

# =============================================================================
# Script Execution
# =============================================================================

# Run main function with all arguments
main "$@"
