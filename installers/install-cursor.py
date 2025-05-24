#!/usr/bin/env python3
"""
cursor_installer.py – installs or removes the Cursor AI IDE for the current user only.

✔ AppImage → ~/.local/bin/cursor.appimage
✔ Icon     → ~/.local/share/icons/cursor.png
✔ Launcher  → ~/.local/share/applications/cursor.desktop

Usage:
    python3 cursor_installer.py install
    python3 cursor_installer.py uninstall

Notes:
* The latest AppImage is obtained from the official Cursor endpoint
    `https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable`.
* Some servers return **HTTP 403** if the *User-Agent* header is missing.
    This script now sends a generic User-Agent to avoid blocks.
"""

import argparse
import json
import os
import stat
import sys
import urllib.request
from pathlib import Path
from urllib.error import HTTPError

API_URL = "https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
ICON_URL = (
    "https://us1.discourse-cdn.com/flex020/uploads/cursor1/original/2X/a/a4f78589d63edd61a2843306f8e11bad9590f0ca.png"
)

HOME = Path.home()
APPIMAGE_PATH = HOME / ".local" / "bin" / "cursor.appimage"
ICON_PATH = HOME / ".local" / "share" / "icons" / "cursor.png"
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share"))
DESKTOP_ENTRY_PATH = DATA_HOME / "applications" / "cursor.desktop"
ZSHRC_ALIAS_COMMENT = "# Cursor alias"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
}

def _ensure_dirs():
    for d in (
        APPIMAGE_PATH.parent,
        ICON_PATH.parent,
        DESKTOP_ENTRY_PATH.parent,
    ):
        d.mkdir(parents=True, exist_ok=True)


def _download(url: str, dest: Path):
    """Downloads a file (supports JSON wrapper) and adds User-Agent."""
    print(f"Downloading {url} → {dest}")
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req) as resp:
            ctype = resp.headers.get("Content-Type", "")
            if "application/json" in ctype:
                data = json.loads(resp.read().decode())
                final_url = data.get("url") or data.get("downloadUrl")
                if not final_url:
                    print("[ERROR] Unexpected download JSON.")
                    sys.exit(1)
                return _download(final_url, dest)
            with open(dest, "wb") as fp:
                while True:
                    chunk = resp.read(8192)
                    if not chunk:
                        break
                    fp.write(chunk)
    except HTTPError as e:
        print(f"[ERROR] Download failed: {e}")
        sys.exit(1)


def _add_exec_permission(path: Path):
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _write_desktop_entry():
    entry = f"""[Desktop Entry]
Name=Cursor AI IDE
Exec={APPIMAGE_PATH} --no-sandbox
Icon={ICON_PATH}
Type=Application
Categories=Development;
"""
    DESKTOP_ENTRY_PATH.write_text(entry)
    print(f"Launcher created at {DESKTOP_ENTRY_PATH}")


def _add_alias_to_zshrc():
    zshrc = HOME / ".zshrc"
    if zshrc.exists() and ZSHRC_ALIAS_COMMENT in zshrc.read_text():
        return
    alias_block = f"""

{ZSHRC_ALIAS_COMMENT}
function cursor() {{
    "{APPIMAGE_PATH}" --no-sandbox "$@" > /dev/null 2>&1 & disown
}}
"""
    with zshrc.open("a") as fp:
        fp.write(alias_block)
    print("Alias added to ~/.zshrc (reopen shell).")


def _remove_alias_from_zshrc():
    zshrc = HOME / ".zshrc"
    if not zshrc.exists():
        return
    lines = zshrc.read_text().splitlines()
    new_lines = []
    skip = False
    for line in lines:
        if line.strip() == ZSHRC_ALIAS_COMMENT:
            skip = True
            continue
        if skip and line.startswith("}"):
            skip = False
            continue
        if not skip:
            new_lines.append(line)
    zshrc.write_text("\n".join(new_lines))

def install():
    if APPIMAGE_PATH.exists():
        print("Cursor AI IDE is already installed.")
        return

    print("Installing Cursor AI IDE…")
    _ensure_dirs()
    _download(API_URL, APPIMAGE_PATH)
    _add_exec_permission(APPIMAGE_PATH)
    _download(ICON_URL, ICON_PATH)
    _write_desktop_entry()
    _add_alias_to_zshrc()
    print("Installation complete! It will appear in the applications menu.")


def uninstall():
    print("Removing Cursor AI IDE…")
    for p in (APPIMAGE_PATH, ICON_PATH, DESKTOP_ENTRY_PATH):
        if p.exists():
            print(f"Deleting {p}")
            p.unlink()
    _remove_alias_from_zshrc()
    for d in (
        APPIMAGE_PATH.parent,
        ICON_PATH.parent,
        DESKTOP_ENTRY_PATH.parent,
    ):
        try:
            d.rmdir()
        except OSError:
            pass
    print("Uninstallation complete.")

def main():
    parser = argparse.ArgumentParser(description="Installs or removes the Cursor AI IDE for the current user only.")
    parser.add_argument("action", choices=["install", "uninstall"], help="Desired action")
    args = parser.parse_args()

    if args.action == "install":
        install()
    elif args.action == "uninstall":
        uninstall()
    else:
        print("Invalid action. Please use 'install' or 'uninstall'.")
        sys.exit(1)


if __name__ == "__main__":
    main()