#!/bin/bash

set -e

USERNAME="voshond"
REPO="/mnt/archBackup01/borg_repo"
SCRIPT_PATH="/usr/local/bin/borg_backup.sh"
SERVICE_FILE="/etc/systemd/system/borg-backup.service"
TIMER_FILE="/etc/systemd/system/borg-backup.timer"
LOG_FILE="/var/log/borg_backup.log"

echo "==> Step 1: Install borg (if not installed)..."
if ! command -v borg &> /dev/null; then
    echo "-- Installing borg with pacman..."
    sudo pacman -Sy --noconfirm borg
else
    echo "-- Borg is already installed."
fi

echo "==> Step 2: Check/create backup repository..."
if [ -d "$REPO" ] && [ -f "$REPO/config" ]; then
    echo "-- Borg repository already exists at $REPO."
else
    echo "-- Creating new Borg repo at $REPO..."
    sudo mkdir -p "$REPO"
    sudo chown "$USERNAME:$USERNAME" "$REPO"
    borg init --encryption=repokey "$REPO"
fi

echo "==> Step 3: Prompt for passphrase (will be embedded in memory only)..."
read -s -p "Enter your Borg repository passphrase: " BORG_PASSPHRASE
echo

echo "==> Step 4: Create or update backup script..."
sudo tee "$SCRIPT_PATH" > /dev/null <<EOF
#!/bin/bash

exec >> "$LOG_FILE" 2>&1
echo "== Borg Backup started at \$(date) =="

ARCHIVE="home-latest"
REPO="$REPO"

borg create --stats --progress --checkpoint-interval 600 --compression lz4 \\
  --exclude "/home/$USERNAME/.cache" \\
  --exclude "/home/$USERNAME/Downloads" \\
  "\$REPO::\$ARCHIVE" /home/$USERNAME

echo "== Borg Backup completed at \$(date) =="
EOF
sudo chmod +x "$SCRIPT_PATH"
sudo touch "$LOG_FILE"
sudo chown "$USERNAME:$USERNAME" "$LOG_FILE"
echo "-- Backup script saved to $SCRIPT_PATH and logs to $LOG_FILE."

echo "==> Step 5: Create systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Borg Backup Service

[Service]
Type=oneshot
User=$USERNAME
Environment="BORG_PASSPHRASE=$BORG_PASSPHRASE"
ExecStart=$SCRIPT_PATH
EOF
echo "-- Created/Updated $SERVICE_FILE"

echo "==> Step 6: Create systemd timer..."
sudo tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Run Borg backup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
echo "-- Created/Updated $TIMER_FILE"

echo "==> Step 7: Reload and enable systemd units..."
sudo systemctl daemon-reload
sudo systemctl enable --now borg-backup.timer

echo ""
echo "✅ Borg daily backup is fully set up!"
echo "🕒 Check timer status:    systemctl list-timers borg-backup.timer"
echo "📂 Check backup list:     borg list $REPO"
echo "🛠️  Run manually:          sudo systemctl start borg-backup.service"
echo "📝 Logs saved to:          $LOG_FILE"
