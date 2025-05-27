#!/bin/bash

REPO="/mnt/archBackup01/borg_repo"
ARCHIVE="home-$(date +%Y-%m-%d)"

borg create --stats --progress \
  --exclude '/home/voshond/.cache' \
  --exclude '/home/voshond/Downloads' \
  "$REPO::$ARCHIVE" /home/voshond

borg prune -v --list "$REPO" \
  --keep-daily=7 --keep-weekly=4 --keep-monthly=3

echo "Backup completed at $(date)"
