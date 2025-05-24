#!/bin/bash

# =============================================================================
# Arch Linux Restore Script
# =============================================================================
# This script helps restore from backups created by backup.sh
# Author: Generated for user
# Usage: ./restore.sh [options]
# =============================================================================

set -euo pipefail

# Configuration
BACKUP_MOUNT="@archBackup01"
BACKUP_BASE="$BACKUP_MOUNT/arch-backups"
LOG_FILE="$BACKUP_BASE/restore.log"
DATE=$(date +%Y%m%d_%H%M%S)

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
    
    # Check if backup mount point exists
    if [[ ! -d "$BACKUP_MOUNT" ]]; then
        error "Backup mount point $BACKUP_MOUNT does not exist!"
        error "Please ensure your backup disk is mounted at $BACKUP_MOUNT"
        exit 1
    fi
    
    # Check if backup base exists
    if [[ ! -d "$BACKUP_BASE" ]]; then
        error "Backup directory $BACKUP_BASE does not exist!"
        error "No backups found to restore from."
        exit 1
    fi
}

# =============================================================================
# Listing Functions
# =============================================================================

list_available_backups() {
    info "Available backups:"
    echo
    
    # List package backups
    if [[ -d "$BACKUP_BASE/packages" ]]; then
        echo -e "${GREEN}Package Backups:${NC}"
        find "$BACKUP_BASE/packages" -maxdepth 1 -type d -name "[0-9]*" | sort -r | head -10 | while read -r dir; do
            local backup_name=$(basename "$dir")
            echo "  📦 $backup_name"
        done
        echo
    fi
    
    # List config backups
    if [[ -d "$BACKUP_BASE/configs" ]]; then
        echo -e "${GREEN}Configuration Backups:${NC}"
        find "$BACKUP_BASE/configs" -maxdepth 1 -type d -name "[0-9]*" | sort -r | head -10 | while read -r dir; do
            local backup_name=$(basename "$dir")
            echo "  ⚙️  $backup_name"
        done
        echo
    fi
    
    # List home backups
    if [[ -d "$BACKUP_BASE/home" ]]; then
        echo -e "${GREEN}Home Directory Backups:${NC}"
        find "$BACKUP_BASE/home" -name "home-*.tar.gz" | sort -r | head -10 | while read -r file; do
            local backup_name=$(basename "$file")
            local size=$(du -h "$file" | cut -f1)
            echo "  🏠 $backup_name ($size)"
        done
        echo
    fi
    
    # List system backups
    if [[ -d "$BACKUP_BASE/system" ]]; then
        echo -e "${GREEN}System Backups:${NC}"
        find "$BACKUP_BASE/system" -name "system-*.tar.gz" | sort -r | head -5 | while read -r file; do
            local backup_name=$(basename "$file")
            local size=$(du -h "$file" | cut -f1)
            echo "  💻 $backup_name ($size)"
        done
        echo
    fi
    
    # List incremental backups
    if [[ -d "$BACKUP_BASE/incremental" ]]; then
        echo -e "${GREEN}Incremental Backups:${NC}"
        find "$BACKUP_BASE/incremental" -type d -name "[0-9]*" | sort -r | head -10 | while read -r dir; do
            local backup_name=$(basename "$dir")
            local hostname=$(basename "$(dirname "$(dirname "$dir")")")
            echo "  🔄 $hostname/$backup_name"
        done
        echo
    fi
}

# =============================================================================
# Restore Functions
# =============================================================================

restore_packages() {
    local backup_date="$1"
    local pkg_dir="$BACKUP_BASE/packages/$backup_date"
    
    if [[ ! -d "$pkg_dir" ]]; then
        error "Package backup $backup_date not found!"
        return 1
    fi
    
    info "Restoring packages from backup: $backup_date"
    
    # Show what's available
    echo "Available package lists in this backup:"
    ls -la "$pkg_dir"
    echo
    
    if [[ -f "$pkg_dir/explicitly-installed.txt" ]]; then
        warning "This will install packages from the backup. Continue? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Package restore cancelled."
            return 0
        fi
        
        info "Installing explicitly installed packages..."
        if command -v yay &> /dev/null; then
            # Use yay if available (handles AUR packages)
            yay -S --needed - < "$pkg_dir/explicitly-installed.txt"
        else
            # Fall back to pacman (official repos only)
            sudo pacman -S --needed - < "$pkg_dir/explicitly-installed.txt"
        fi
        
        success "Packages restored successfully!"
    fi
    
    # Restore pacman database if available and running as root
    if [[ -f "$pkg_dir/pacman-database.tar.gz" && $EUID -eq 0 ]]; then
        warning "Restore pacman database? This will overwrite the current database. (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            info "Restoring pacman database..."
            tar xzf "$pkg_dir/pacman-database.tar.gz" -C /var/lib/pacman/
            success "Pacman database restored!"
        fi
    fi
}

restore_configs() {
    local backup_date="$1"
    local config_dir="$BACKUP_BASE/configs/$backup_date"
    
    if [[ ! -d "$config_dir" ]]; then
        error "Configuration backup $backup_date not found!"
        return 1
    fi
    
    info "Restoring configurations from backup: $backup_date"
    
    # Show what's available
    echo "Available configurations in this backup:"
    find "$config_dir" -type f | head -20
    if [[ $(find "$config_dir" -type f | wc -l) -gt 20 ]]; then
        echo "... and $(( $(find "$config_dir" -type f | wc -l) - 20 )) more files"
    fi
    echo
    
    warning "This will overwrite existing configuration files. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Configuration restore cancelled."
        return 0
    fi
    
    # Restore system configs (requires root)
    if [[ $EUID -eq 0 && -d "$config_dir/etc" ]]; then
        info "Restoring system configurations..."
        cp -a "$config_dir/etc"/* /etc/ 2>/dev/null || warning "Some system config files could not be restored"
        
        if [[ -d "$config_dir/boot" ]]; then
            cp -a "$config_dir/boot"/* /boot/ 2>/dev/null || warning "Boot configuration could not be restored"
        fi
    fi
    
    # Restore user configs
    if [[ -d "$config_dir/user" ]]; then
        info "Restoring user configurations..."
        cp -a "$config_dir/user"/* "$HOME"/ 2>/dev/null || warning "Some user config files could not be restored"
    fi
    
    success "Configuration restore completed!"
}

restore_home() {
    local backup_file="$1"
    
    if [[ ! -f "$BACKUP_BASE/home/$backup_file" ]]; then
        error "Home backup $backup_file not found!"
        return 1
    fi
    
    info "Restoring home directory from: $backup_file"
    
    warning "This will overwrite files in your home directory. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Home directory restore cancelled."
        return 0
    fi
    
    info "Extracting home directory backup..."
    tar xzf "$BACKUP_BASE/home/$backup_file" -C "$(dirname "$HOME")"
    
    success "Home directory restored successfully!"
}

restore_incremental() {
    local hostname="$1"
    local snapshot="$2"
    local snapshot_dir="$BACKUP_BASE/incremental/$hostname/snapshots/$snapshot"
    
    if [[ ! -d "$snapshot_dir" ]]; then
        error "Incremental backup $hostname/$snapshot not found!"
        return 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        error "Incremental restore requires root privileges!"
        return 1
    fi
    
    warning "This will restore the entire system from incremental backup."
    warning "This is a DESTRUCTIVE operation that will overwrite system files."
    warning "Make sure you know what you're doing!"
    echo
    warning "Continue with system restore? (type 'YES' to confirm)"
    read -r response
    if [[ "$response" != "YES" ]]; then
        info "System restore cancelled."
        return 0
    fi
    
    info "Restoring system from incremental backup: $hostname/$snapshot"
    
    # Use rsync to restore
    rsync -av --delete \
        --exclude='/dev/*' \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/tmp/*' \
        --exclude='/run/*' \
        --exclude='/mnt/*' \
        --exclude='/media/*' \
        --exclude="$BACKUP_MOUNT/*" \
        "$snapshot_dir/" /
    
    success "Incremental system restore completed!"
    warning "Please reboot the system to ensure all changes take effect."
}

# =============================================================================
# Main Functions
# =============================================================================

show_usage() {
    cat << EOF
Arch Linux Restore Script

Usage: $0 [OPTIONS]

OPTIONS:
    -l, --list          List available backups
    -p, --packages DATE Restore packages from specific backup date
    -c, --configs DATE  Restore configurations from specific backup date
    -h, --home FILE     Restore home directory from specific backup file
    -i, --incremental HOSTNAME/SNAPSHOT  Restore from incremental backup
    --help              Show this help message

EXAMPLES:
    $0 --list                           # List all available backups
    $0 --packages 20241201_143022       # Restore packages from specific date
    $0 --configs 20241201_143022        # Restore configs from specific date
    $0 --home home-myhost-20241201_143022.tar.gz  # Restore home directory
    sudo $0 --incremental myhost/20241201_143022  # Restore full system

The backup disk should be mounted at: $BACKUP_MOUNT
Backups are read from: $BACKUP_BASE
EOF
}

main() {
    # Initialize log
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    info "=== Arch Linux Restore Script Started ==="
    info "Date: $DATE"
    info "User: $(whoami)"
    
    check_prerequisites
    
    case "${1:-}" in
        -l|--list)
            list_available_backups
            ;;
        -p|--packages)
            if [[ -z "${2:-}" ]]; then
                error "Please specify backup date for package restore"
                exit 1
            fi
            restore_packages "$2"
            ;;
        -c|--configs)
            if [[ -z "${2:-}" ]]; then
                error "Please specify backup date for configuration restore"
                exit 1
            fi
            restore_configs "$2"
            ;;
        -h|--home)
            if [[ -z "${2:-}" ]]; then
                error "Please specify backup file for home directory restore"
                exit 1
            fi
            restore_home "$2"
            ;;
        -i|--incremental)
            if [[ -z "${2:-}" ]]; then
                error "Please specify hostname/snapshot for incremental restore"
                exit 1
            fi
            local hostname=$(echo "$2" | cut -d'/' -f1)
            local snapshot=$(echo "$2" | cut -d'/' -f2)
            restore_incremental "$hostname" "$snapshot"
            ;;
        --help)
            show_usage
            exit 0
            ;;
        "")
            info "No action specified. Use --help for options or --list to see available backups."
            echo
            list_available_backups
            ;;
        *)
            error "Unknown option: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
    
    success "=== Restore Script Completed ==="
}

# Run main function with all arguments
main "$@" 