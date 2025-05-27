#!/bin/bash

set -e

USERNAME="voshond"
REPO="/mnt/archBackup01/borg_repo"
SCRIPT_PATH="/usr/local/bin/borg_backup.sh"
SERVICE_FILE="/etc/systemd/system/borg-backup.service"
TIMER_FILE="/etc/systemd/system/borg-backup.timer"

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
    sudo chown "$USERNAME":"$USERNAME" "$REPO"
    borg init --encryption=repokey "$REPO"
fi

echo "==> Step 3: Create or update backup script..."
sudo tee "$SCRIPT_PATH" > /dev/null <<EOF
#!/bin/bash

ARCHIVE="home-latest"

borg create --stats --progress --checkpoint-interval 600 --compression lz4 \\
  --exclude "/home/$USERNAME/.cache" \\
  --exclude "/home/$USERNAME/Downloads" \\
  --force \\
  "$REPO::\$ARCHIVE" /home/$USERNAME

echo "Borg backup completed at \$(date)"
EOF
sudo chmod +x "$SCRIPT_PATH"
echo "-- Backup script saved to $SCRIPT_PATH."

echo "==> Step 4: Create systemd service..."
if [ ! -f "$SERVICE_FILE" ]; then
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Borg Backup Service

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF
    echo "-- Created $SERVICE_FILE"
else
    echo "-- $SERVICE_FILE already exists."
fi

echo "==> Step 5: Create systemd timer..."
if [ ! -f "$TIMER_FILE" ]; then
    sudo tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Run Borg backup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    echo "-- Created $TIMER_FILE"
else
    echo "-- $TIMER_FILE already exists."
fi

echo "==> Step 6: Enable and start timer..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now borg-backup.timer

echo ""
echo "✅ Borg daily backup is set up!"
echo "🕒 Check timer status:    systemctl list-timers borg-backup.timer"
echo "📂 Check backup list:     borg list $REPO"
echo "🛠️  Run manually:          sudo $SCRIPT_PATH"
