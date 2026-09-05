#!/usr/bin/env bash
set -euo pipefail

#Set up some colors
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

#Silence proton
export WINEDEBUG=-all

#Set up steam directories
STEAM_DIR="$HOME/.steam/steam"
PROTON_DIR="$STEAM_DIR/steamapps/common"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_DIR"
export STEAM_COMPAT_DATA_PATH="$STEAM_DIR/steamapps/compatdata/1580240"

AP_DIR="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/ProgramData/Archipelago"
AP_PLAYER_DIR="$AP_DIR/Players"

#RF4 paths
RF4_LINUX_SAVE_FOLDER="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/users/steamuser/AppData/Roaming/Rune Factory 4 Special"
RF4_LINUX_INSTALL_FOLDER="$STEAM_DIR/steamapps/common/Rune Factory 4 Special"
RF4_WINE_INSTALL_PATH="Z:$STEAM_DIR/steamapps/common/Rune Factory 4 Special"
RF4_WINE_SAVE_PATH="C:/users/steamuser/AppData/Roaming/Rune Factory 4 Special"

install_ap_world() {
    AP_WORLD_URL=$(curl -s https://api.github.com/repos/Happyhappyism/Rune-Factory-4-Archipelago/releases/latest | jq -r '.assets[].browser_download_url')
    AP_WORLD_FILE="${AP_WORLD_URL##*/}"
    echo "Downloading Rune Factory 4 Special apworld..."
    curl -L -# "$AP_WORLD_URL" -O

    echo "Installing Rune Factory 4 apworld..."
    mkdir -p "$RF4_LINUX_INSTALL_FOLDER/Archipelago"
    mkdir -p "$AP_DIR/custom_worlds"
    mv "$AP_WORLD_FILE" "$AP_DIR/custom_worlds"
}

find_newest_proton() {
    # Find the newest normal Proton version
    PROTON_PATH=$(
        find "$PROTON_DIR" -maxdepth 2 -type f -name proton \
            -path '*/Proton [0-9]*.[0-9]*/proton' 2>/dev/null |
        sort -V |
        tail -n 1
    )

    if [ -z "$PROTON_PATH" ]; then
        echo "Could not find an installed Proton."
        exit 1
    fi
    echo "Using Proton: $PROTON_PATH"
}

install_archipelago() {
    #Get archipelago installer+apworld
    INSTALLER_URL=$(curl -s https://api.github.com/repos/ArchipelagoMW/Archipelago/releases/latest | jq -r '.assets[].browser_download_url' | grep exe)
    INSTALLER_FILE="${INSTALLER_URL##*/}"

    echo "Downloading archipelago installer..."
    curl -L -# "$INSTALLER_URL" -O

    echo "Installing $INSTALLER_FILE..."
    "$PROTON_PATH" run "$INSTALLER_FILE" /VERYSILENT /NORESTART >/dev/null 2>&1
    rm "$INSTALLER_FILE"
}

generate_player_yaml() {
    echo "Generating yaml templates..."
    "$PROTON_PATH" run "C:\ProgramData\Archipelago\ArchipelagoLauncher.exe" "Generate Template Options" -- --skip_open_folder >/dev/null 2>&1

    echo "Installing Rune Factory 4 Special yaml to $AP_PLAYER_DIR"
    cp "$AP_PLAYER_DIR/Templates/Rune Factory 4.yaml" "$AP_PLAYER_DIR"
}

install_desktop_launcher() {
echo "Setting up desktop launcher..."
DESKTOP_FILE_NAME="archipelago-launcher.desktop"
DESKTOP_FILE_PATH="$HOME/Desktop/$DESKTOP_FILE_NAME"
SCRIPT="$HOME/Desktop/ArchipelagoLauncher.sh"

cat > "$SCRIPT" <<'EOF'
#!/usr/bin/env bash

#Silence proton
export WINEDEBUG=-all

STEAM_DIR="$HOME/.steam/steam"
PROTON_DIR="$STEAM_DIR/steamapps/common"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_DIR"
export STEAM_COMPAT_DATA_PATH="$STEAM_DIR/steamapps/compatdata/1580240"

# Resolve Proton at launch time, so a Steam update that removes or replaces the
# version installed today doesn't break this shortcut.
PROTON_PATH=$(
    find "$PROTON_DIR" -maxdepth 2 -type f -name proton \
        -path '*/Proton [0-9]*.[0-9]*/proton' 2>/dev/null |
    sort -V |
    tail -n 1
)

if [ -z "$PROTON_PATH" ]; then
    MSG="Could not find an installed Proton. Install any Proton version through Steam, then try again."
    if command -v kdialog >/dev/null; then
        kdialog --error "$MSG"
    elif command -v zenity >/dev/null; then
        zenity --error --text="$MSG"
    else
        echo "$MSG" >&2
    fi
    exit 1
fi

"$PROTON_PATH" run "C:\ProgramData\Archipelago\ArchipelagoLauncher.exe"
EOF

cat > "$DESKTOP_FILE_PATH" <<EOF
[Desktop Entry]
Name=Archipelago Launcher
Exec=$SCRIPT
Type=Application
Terminal=false
Icon=steam
EOF

chmod +x "$SCRIPT"
chmod +x "$DESKTOP_FILE_PATH"
}

main() {
    find_newest_proton
    if [ ! -d "$AP_DIR" ]; then
        install_archipelago
    else
        echo -e "Archipelago is already installed"
    fi
    install_ap_world
    generate_player_yaml
    install_desktop_launcher

    echo -e "${YELLOW}Install done!"
    echo -e "You can start achipelago from the desktop by double clicking the icon ${BLUE}$DESKTOP_FILE_NAME${YELLOW}"
    echo -e "You can alter the yaml config at ${BLUE}$AP_PLAYER_DIR${YELLOW}"
    echo -e "Then generate your game and it will be under ${BLUE}$AP_DIR/output${YELLOW}"
    echo -e "In the output zip from generation, there will be a save marked with your chosen player name."
    echo -e "Place that save into ${BLUE}$RF4_LINUX_INSTALL_FOLDER/Archipelago${YELLOW}"
    echo -e "If you have Trupin hints enabled, also place your hints.json file in the same folder as well."
    echo -e "When asked for the rf4 install path paste ${BLUE}$RF4_WINE_INSTALL_PATH${YELLOW}"
    echo -e "Enjoy!${NC}"
}

main
