#!/usr/bin/env bash

# ansi color codes
# https://stackoverflow.com/a/28938235
Rst='\033[0m'    # Text Reset
Blk='\033[0;30m' # Black
Red='\033[0;31m' # Red
Grn='\033[0;32m' # Green
Ylw='\033[0;33m' # Yellow
Blu='\033[0;34m' # Blue
Prp='\033[0;35m' # Purple
Cyn='\033[0;36m' # Cyan
Wht='\033[0;37m' # White

#check wine installed
command -v ine >/dev/null 2>&1 || { 
    echo -e "${Red}Looks like wine is not installed on this system.${Rst}" >&2
    echo -e "${Red}You can install wine from here: ${Ylw}https://wiki.winehq.org/Download${Rst}" >&2
    exit 1
    }

if [ $EUID -eq 0 ]; then
   echo -e "${Ylw}Warning: Running this script as root is not recommended.${Rst}" 1>&2
fi

# set $USER if not set
if [ -z "$USER" ]; then
   USER="$(whoami)"
fi

# set $HOME if not set
if [ -z "$HOME" ] && [ $EUID -ne 0 ]; then
   HOME="/home/$USER"
fi

# variables
export WINEPREFIX="$HOME/.local/share/wine/adobe-photoshop" # path where photoshop-cc-2022 will be installed

TEMP_DIR="$(mktemp -d /tmp/photoshop.XXXXXX)"
DESKTOP_PATH="$HOME/.local/share/applications"

WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
DOWNLOAD_URL="https://lulucloud.mywire.org/FileHosting/GithubProjects/PS2022"
DOWNLOAD_URL_BACKUP="https://web.archive.org/web/20220520182929/https://lulucloud.mywire.org/FileHosting/GithubProjects/PS2022"


SHA256_CHECKSUMS="
a7cd24cecc984c10e6cbbdf77ebb8211bbc774cbc7d7e6fd9776f1eb13dbc9d4 $TEMP_DIR/allredist.tar.xz
c1ed75f674d4d6c49434e6953f1476293d09925946275b7ebb883a96613f9d0a $TEMP_DIR/Adobe.tar.xz
d417ac92073c4cf11ac7422dce0be3477d7b3bf1e7c118feeaed809002143170 $TEMP_DIR/AdobePhotoshop2022.tar.xz
4ae1bd5be25fc2ff99a35dc7b340a3b061e14daa9ef773e73dffec5338a2045a $TEMP_DIR/Adobe_Photoshop_2022_Settings.tar.xz"
# end of variables

echo -e "${Cyn}Photoshop will be installed to: $WINEPREFIX${Rst}"
mkdir -p "$WINEPREFIX"

echo -e "${Prp}"
wineboot -i
echo -e "${Rst}"


echo -e "${Cyn}Downloading latest winetricks${Rst}"

echo -e "${Ylw}"
wget -O "$TEMP_DIR/winetricks" -q --show-progress "$WINETRICKS_URL"
chmod +x "$TEMP_DIR/winetricks"
echo -e "${Rst}"


echo -e "${Cyn}Installing some libs...${Rst}"

echo -e "${Prp}"
"$TEMP_DIR/winetricks" "fontsmooth=rgb" "gdiplus" "msxml3" "msxml6" "atmlib" "corefonts" "dxvk" "win10"
echo -e "${Rst}"

# downloading
echo "Downloading Adobe Photoshop CC 2022 files, this approximates to about 1.6GB"
echo "Source used: $DOWNLOAD_URL"
echo "GitHub project used: https://github.com/MiMillieuh/Photoshop-CC2022-Linux"

files=("allredist.tar.xz" "Adobe.tar.xz" "AdobePhotoshop2022.tar.xz" "Adobe_Photoshop_2022_Settings.tar.xz")

for file in "${files[@]}"; do
    echo -e "${Cyn}Downloading $file${Rst}"
    touch "$TEMP_DIR/$file"
    echo -e "${Ylw}"
    wget -O "$TEMP_DIR/$file" -q --show-progress "$DOWNLOAD_URL/$file"
    echo -e "${Rst}"
    if !(echo "$SHA256_CHECKSUMS" | grep "$file" | sha256sum --check --status); then
        echo -e "${Red}Downloading $file failed (or shasums mismatched). Trying backup url.${Rst}" >&2
        echo -e "${Ylw}"
        wget -O "$TEMP_DIR/$file" -q --show-progress "$DOWNLOAD_URL_BACKUP/$file"
        echo -e "${Rst}"
        if !(echo "$SHA256_CHECKSUMS" | grep "$file" | sha256sum --check --status); then
            echo -e "${Red}Downloading $file failed (or shasums mismatched) again. Exiting.${Rst}" >&2
            exit 1
        fi
    fi
done
# end of downloading


echo -e "${Cyn}Extracting files to $WINEPREFIX${Rst}"
mkdir -p "$WINEPREFIX/drive_c/Program Files (x86)/Common Files"
mkdir -p "$WINEPREFIX/drive_c/Program Files/Adobe"
mkdir -p "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Adobe/Adobe Photoshop 2022/"

rm "$TEMP_DIR/allredist" -rf
tar -xf "$TEMP_DIR/allredist.tar.xz" -C "$TEMP_DIR"
mv "$TEMP_DIR/allredist/photoshop.png" "$WINEPREFIX"

tar -xf "$TEMP_DIR/Adobe.tar.xz" -C "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/"
tar -xf "$TEMP_DIR/Adobe_Photoshop_2022_Settings.tar.xz" -C "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Adobe/Adobe Photoshop 2022/"
tar -xf "$TEMP_DIR/AdobePhotoshop2022.tar.xz" -C "$WINEPREFIX/drive_c/Program Files/Adobe/"

# visual studio
echo -e "${Cyn}Installing some libs...${Rst}"

echo -e "${Prp}"
wine "$TEMP_DIR/allredist/redist/2010/vcredist_x64.exe" /q /norestart
wine "$TEMP_DIR/allredist/redist/2010/vcredist_x86.exe" /q /norestart

wine "$TEMP_DIR/allredist/redist/2012/vcredist_x86.exe" /install /quiet /norestart
wine "$TEMP_DIR/allredist/redist/2012/vcredist_x64.exe" /install /quiet /norestart

wine "$TEMP_DIR/allredist/redist/2013/vcredist_x86.exe" /install /quiet /norestart
wine "$TEMP_DIR/allredist/redist/2013/vcredist_x64.exe" /install /quiet /norestart

wine "$TEMP_DIR/allredist/redist/2019/VC_redist.x64.exe" /install /quiet /norestart
wine "$TEMP_DIR/allredist/redist/2019/VC_redist.x86.exe" /install /quiet /norestart
echo -e "${Rst}"
# end of visual studio


echo -e "${Cyn}Generating launcher and desktop files${Rst}"

cat << EOF > "$WINEPREFIX/photoshop_launcher.sh" 
#!/usr/bin/env bash
DESKTOP_PATH='$DESKTOP_PATH'
SCRIPT_PATH="\$(dirname \`realpath \$0\`)"
export WINEPREFIX="\$SCRIPT_PATH"
export DXVK_STATE_CACHE_PATH="SCRIPT_PATH"
SCR_PATH="pspath"
CACHE_PATH="pscache"
RESOURCES_PATH="\$SCR_PATH/resources"
WINE_PREFIX="\$SCR_PATH/prefix"
if [ "\$1" == "launch" ]; then
    FILE_PATH=\$(winepath -w "\$2")
    wine "\$SCRIPT_PATH/drive_c/Program Files/Adobe/Adobe Photoshop 2022/photoshop.exe" "\$FILE_PATH" &
    exit 0
fi
if [ "\$1" == "generate" ]; then
    cat << EoF > "\$WINEPREFIX/photoshop-wine.desktop"
[Desktop Entry]
Name=Adobe Photoshop 2022
Exec=bash -c "'\$WINEPREFIX/photoshop_launcher.sh' launch '%F'"
Type=Application
Comment=Adobe Photoshop 2022 (Wine)
Categories=Graphics;
Icon=\$WINEPREFIX/photoshop.png
StartupWMClass=photoshop.exe
EoF
    ln -sf "\$WINEPREFIX/photoshop-wine.desktop" "\$DESKTOP_PATH/photoshop-wine.desktop"
    update-desktop-database "\$DESKTOP_PATH"
    echo -e "\033[0;36mDesktop files of WINEPREFIX='\$WINEPREFIX' generated at '\$DESKTOP_PATH'\033[0m"
    exit 0
fi
EOF

chmod +x "$WINEPREFIX/photoshop_launcher.sh"

"$WINEPREFIX/photoshop_launcher.sh" "generate"

echo -e "${Grn}Installation complete.${Rst}"

echo -e -n "${Cyn}Do you want to delete the downloaded temporary files?${Rst} (y/N) "
read -r answer
if [ "${answer,,}" = "y" ]; then
    rm "$TEMP_DIR" -rf
    echo "Files are deleted."
else
    echo "Files in '$TEMP_DIR' will not be deleted."
fi
