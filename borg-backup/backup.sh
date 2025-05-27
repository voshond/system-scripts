#!/bin/bash

# Define source and destination
SOURCE="/home/voshond/"
DEST="/mnt/archBackup01/home_backup/"

# Create destination directory if it doesn't exist
mkdir -p "$DEST"

# Rsync options:
# -a = archive mode (preserves permissions, symbolic links, etc.)
# -v = verbose
# -h = human-readable
# --delete = deletes files in backup not present in source
# --exclude = exclude specific directories if needed

rsync -avh --delete "$SOURCE" "$DEST"

# Print finish message
echo "Backup completed on $(date)"
