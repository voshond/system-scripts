#!/bin/bash

# Configuration
EXTENSION_UUID="top-bar-organizer@julian.gse.jsts.xyz"
SRC_DIR="$HOME/top-bar-organizer/src"
DEST_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_UUID"

# Check for metadata.json to verify it's a valid GNOME extension directory
if [[ ! -f "$SRC_DIR/metadata.json" ]]; then
  echo "❌ Error: metadata.json not found in $SRC_DIR"
  exit 1
fi

# Create destination directory if needed
mkdir -p "$DEST_DIR"

# Copy extension files
cp -r "$SRC_DIR"/* "$DEST_DIR"

echo "✅ Extension files copied to: $DEST_DIR"

# Enable the extension
gnome-extensions enable "$EXTENSION_UUID" 2>/dev/null

# Restart GNOME Shell depending on session type
if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
  echo "🔄 Restarting GNOME Shell (X11)..."
  busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'global.reexec_self()'
else
  echo "🔁 You're on Wayland. Please log out and back in to apply changes."
fi

# Check status
echo "🔍 Installed extensions:"
gnome-extensions list --enabled | grep "$EXTENSION_UUID" && echo "✅ Extension is enabled." || echo "⚠️ Extension is not enabled yet. Enable it manually via GNOME Tweaks."
