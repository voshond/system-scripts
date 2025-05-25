#!/usr/bin/env python3
"""
OpenMW Configuration Synchronizer
Copies mod configuration from Windows OpenMW config to Linux OpenMW config
"""

import re
import shutil
from pathlib import Path

def sync_openmw_config():
    # File paths
    windows_config = Path("/run/media/voshond/win01/Users/Martin/Documents/My Games/OpenMW/openmw.cfg")
    linux_config = Path("/home/voshond/.var/app/org.openmw.OpenMW/config/openmw/openmw.cfg")
    backup_config = Path("/home/voshond/.var/app/org.openmw.OpenMW/config/openmw/openmw.cfg.backup")
    
    # Check if files exist
    if not windows_config.exists():
        print(f"Error: Windows config file not found: {windows_config}")
        return False
    
    if not linux_config.exists():
        print(f"Error: Linux config file not found: {linux_config}")
        return False
    
    # Create backup
    print(f"Creating backup: {backup_config}")
    shutil.copy2(linux_config, backup_config)
    
    # Read both files
    with open(windows_config, 'r', encoding='utf-8') as f:
        windows_lines = f.readlines()
    
    with open(linux_config, 'r', encoding='utf-8') as f:
        linux_lines = f.readlines()
    
    # Extract data and content lines from Windows config
    windows_data_lines = []
    windows_content_lines = []
    
    for line in windows_lines:
        line = line.strip()
        if line.startswith('data='):
            windows_data_lines.append(line)
        elif line.startswith('content='):
            windows_content_lines.append(line)
    
    # Process the new lines
    new_lines = []
    
    # Copy everything from Linux config except data= and content= lines
    for line in linux_lines:
        stripped_line = line.strip()
        if not stripped_line.startswith('data=') and not stripped_line.startswith('content='):
            new_lines.append(line)
    
    # Add the base Morrowind data path
    new_lines.append('data="/mnt/data02/SteamLibrary/steamapps/common/Morrowind/Data Files"\n')
    
    # Process Windows data lines and convert paths
    for data_line in windows_data_lines:
        # Skip the base game data path
        if 'steamapps/common/Morrowind/Data Files' in data_line or 'games/steam/steamapps/common/Morrowind/Data Files' in data_line:
            continue
        
        # Convert Windows mod paths to Linux paths
        if 'ModOrganizer/Morrowind/mods/' in data_line:
            # Extract the mod name from the Windows path
            match = re.search(r'ModOrganizer/Morrowind/mods/([^"]+)', data_line)
            if match:
                mod_name = match.group(1)
                new_line = f'data="/home/voshond/Documents/Morrowind/mods/{mod_name}"\n'
                new_lines.append(new_line)
        elif 'ModOrganizer/Morrowind/overwrite' in data_line:
            # Skip the overwrite directory for now
            continue
    
    # Add all content lines from Windows config
    for content_line in windows_content_lines:
        new_lines.append(content_line + '\n')
    
    # Write the new configuration
    with open(linux_config, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print("Configuration synchronized successfully!")
    print(f"Backup saved as: {backup_config}")
    
    # Print summary
    mod_count = len([line for line in new_lines if line.startswith('data=') and 'mods/' in line])
    content_count = len([line for line in new_lines if line.startswith('content=')])
    
    print(f"Added {mod_count} mod data paths")
    print(f"Added {content_count} content entries")
    
    return True

if __name__ == "__main__":
    sync_openmw_config() 