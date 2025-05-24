#!/bin/bash
set -e

# === CONFIG ===
NAS_HOST="nas"
BASE_MOUNT="/mnt/nas01"
CREDENTIALS_FILE="/etc/samba/credentials"
SHARES=(
  "Documents"
  "Apps"
  "Data 3 Backup"
  "docker"
  "Downloads"
  "Game"
  "HDD Backup"
  "HDD Backup Mac"
  "Public"
  "SSD Backup"
  "Video"
)
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# === Ask for credentials ===
read -p "Enter SMB username: " SMB_USER
read -s -p "Enter SMB password: " SMB_PASS
echo

# === Install cifs-utils ===
echo "[+] Installing cifs-utils..."
sudo pacman -Sy --noconfirm cifs-utils

# === Create credential file ===
echo "[+] Creating /etc/samba and credentials file..."
sudo mkdir -p /etc/samba
echo -e "username=$SMB_USER\npassword=$SMB_PASS" | sudo tee "$CREDENTIALS_FILE" > /dev/null
sudo chmod 600 "$CREDENTIALS_FILE"

# === Create base mount directory ===
echo "[+] Creating base mount directory: $BASE_MOUNT"
sudo mkdir -p "$BASE_MOUNT"

# === Mount each share ===
for SHARE in "${SHARES[@]}"; do
  # Local mount path: sanitize for filesystem
  SAFE_NAME=$(echo "$SHARE" | tr ' ' '_' | tr -cd '[:alnum:]_-')
  MOUNT_PATH="$BASE_MOUNT/$SAFE_NAME"

  echo "[+] Mounting $SHARE at $MOUNT_PATH..."
  sudo mkdir -p "$MOUNT_PATH"

  # Escape share name for fstab (replace space with \040)
  ESCAPED_SHARE=$(echo "$SHARE" | sed 's/ /\\040/g')

  FSTAB_ENTRY="//${NAS_HOST}/${ESCAPED_SHARE} ${MOUNT_PATH} cifs credentials=${CREDENTIALS_FILE},uid=${USER_ID},gid=${GROUP_ID},vers=3.0,sec=ntlmssp,iocharset=utf8,nofail,x-systemd.automount 0 0"

  # Avoid duplicate entries
  if ! grep -Fq "$FSTAB_ENTRY" /etc/fstab; then
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
  else
    echo "[!] $SHARE already exists in fstab. Skipping."
  fi
done

# === Reload systemd mount units (optional) ===
echo "[+] Reloading systemd daemon..."
sudo systemctl daemon-reexec

# === Mount all from fstab ===
echo "[+] Mounting all fstab entries..."
sudo mount -a

echo "[✓] All shares mounted under $BASE_MOUNT"

