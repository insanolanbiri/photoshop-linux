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
command -v wine >/dev/null 2>&1 || { 
    echo -e "${Red}Looks like wine is not installed on this system.${Rst}" >&2
    echo -e "${Red}You can install wine from here: ${Ylw}https://wiki.winehq.org/Download${Rst}" >&2
    exit 1
}

#check wget installed
command -v wget >/dev/null 2>&1 || { 
    echo -e "${Red}Looks like wget is not installed on this system.${Rst}" >&2
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

#### variables

if [ -z "$PHOTOSHOP_PATH" ]; then
    # path where adobe photoshop will be installed if $PHOTOSHOP_PATH is not set
    export WINEPREFIX="$HOME/.local/share/wine/adobe-photoshop"
else
    export WINEPREFIX="$PHOTOSHOP_PATH"
fi

export WINEDEBUG=-all
TEMP_DIR=/tmp/photoshop #"$(mktemp -d /tmp/photoshop.XXXXXX)"

if [ -z "$APP_PATH" ]; then
    DESKTOP_PATH="$HOME/.local/share/applications"
else
    DESKTOP_PATH="$APP_PATH"
fi

WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
DOWNLOAD_URL="https://lulucloud.mywire.org/FileHosting/GithubProjects"
DOWNLOAD_URL_BACKUP="https://web.archive.org/web/20220520182929/https://lulucloud.mywire.org/FileHosting/GithubProjects"
CAMERARAW_URL="https://download.adobe.com/pub/adobe/photoshop/cameraraw/win/12.x/CameraRaw_12_2_1.exe"
VKD3D_URL="https://raw.githubusercontent.com/HansKristian-Work/vkd3d-proton/master/setup_vkd3d_proton.sh"
msvcp140_codecvt_ids_URL="https://web.archive.org/web/20220523165932/https://doc-10-64-docs.googleusercontent.com/docs/securesc/\
ha0ro937gcuc7l7deffksulhg5h7mbp1/p1g45hh8c4s1oe09nrdeiimrce9o7kig/1653325125000/14773101981101256716/*/1xBJgN2ur0W8QKvW45tLh4QWmlUiUuyuU?e=download"


SHA256_CHECKSUMS="
a7cd24cecc984c10e6cbbdf77ebb8211bbc774cbc7d7e6fd9776f1eb13dbc9d4 $TEMP_DIR/allredist.tar.xz
c1ed75f674d4d6c49434e6953f1476293d09925946275b7ebb883a96613f9d0a $TEMP_DIR/Adobe.tar.xz
d417ac92073c4cf11ac7422dce0be3477d7b3bf1e7c118feeaed809002143170 $TEMP_DIR/AdobePhotoshop2022.tar.xz
4ae1bd5be25fc2ff99a35dc7b340a3b061e14daa9ef773e73dffec5338a2045a $TEMP_DIR/Adobe_Photoshop_2022_Settings.tar.xz
a2520e03933b611d460c5b47577a5037eef85fd61458486745ff4c35ba146194 $TEMP_DIR/AdobePhotoshop2021.tar.xz
ad8627ab2af003e47f62ed2b4e41460cd4b66b06b63f573456f2db41d60ad180 $TEMP_DIR/msvcp140_codecvt_ids.dll
629dacb785191a6ee2d30645fcbe720e718d1ba1544df59fda0ba97fb2262b2d $TEMP_DIR/CameraRaw.exe"
#### end of variables

DOWNLOAD_URL_A="$DOWNLOAD_URL/PS2022"
DOWNLOAD_URL_BACKUP_A="$DOWNLOAD_URL_BACKUP/PS2022"

mkdir -p "$TEMP_DIR"

installCameraRaw() {
    if [ -f "$TEMP_DIR/CameraRaw.exe" ] && (echo "$SHA256_CHECKSUMS" | grep "CameraRaw.exe" | sha256sum --check --status); then
        echo -e "${Ylw}Using cached CameraRaw${Rst}"
    else
        touch "$TEMP_DIR/CameraRaw.exe"
        echo -e "${Cyn}Downloading CameraRaw${Rst}"
        echo -e "${Ylw}"
        wget -O "$TEMP_DIR/CameraRaw.exe" -q --show-progress "$CAMERARAW_URL"
        echo -e "${Rst}"
        if !(echo "$SHA256_CHECKSUMS" | grep "CameraRaw.exe" | sha256sum --check --status); then
            echo -e "${Red}Downloading CameraRaw failed (or shasums mismatched). Installation of CameraRaw is cancelled.${Rst}" >&2
            return 1;
        fi
    fi
    echo -e "${Cyn}Installing CameraRaw${Rst}"
    echo -e "${Prp}"
    wine "$TEMP_DIR/CameraRaw.exe" /S
    echo -e "${Rst}"
    echo -e "${Cyn}To use Camera Raw, change this setting on photoshop:${Rst}"
    echo -e "Edit -> Preferences -> Camera Raw... -> Performance -> Use graphic processor: Off"
}

echo -e -n "${Grn}Which version of Adobe Photoshop you want to install? (2022[has problems]/2021) ${Rst}"
read -r PS_VERSION

#if not 2022 or 2021; then exit
if [ "$PS_VERSION" != "2022" ] && [ "$PS_VERSION" != "2021" ]; then
    echo -e "${Red}You have to choose either 2022 or 2021.${Rst}"
    exit 1
elif [ "$PS_VERSION" == "2022" ]; then
    echo -e "${Ylw}Warning: Adobe Photoshop 2022 has some problems in wine. contiuning anyway.${Rst}"
    DOWNLOAD_URL="$DOWNLOAD_URL/PS2022"
    DOWNLOAD_URL_BACKUP="$DOWNLOAD_URL_BACKUP/PS2022"
fi

#if wineprefix exists; then exit
if [ -d "$WINEPREFIX" ]; then
    echo -e "${Red}Looks like you already have Adobe Photoshop installed.${Rst}"
    echo -e "${Red}If you want to reinstall it, delete the wineprefix (${Rst}${WINEPREFIX}${Red}) first.${Rst}"
    exit 1
fi

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


echo -e "${Cyn}Downloading latest vkd3d setup script${Rst}"

echo -e "${Ylw}"
wget -O "$TEMP_DIR/vkd3d" -q --show-progress "$VKD3D_URL"
chmod +x "$TEMP_DIR/vkd3d"
echo -e "${Rst}"



echo -e "${Cyn}Installing some libs...${Rst}"


file="msvcp140_codecvt_ids.dll"
echo -e "${Ylw}"
wget -O "$TEMP_DIR/msvcp140_codecvt_ids.dll" -q --show-progress "$msvcp140_codecvt_ids_URL"
echo -e "${Rst}"
if !(echo "$SHA256_CHECKSUMS" | grep "$file" | sha256sum --check --status); then
    echo -e "${Red}Downloading $file failed (or shasums mismatched). Exiting.${Rst}" >&2
    exit 1
else
    mv "$TEMP_DIR/msvcp140_codecvt_ids.dll" "$WINEPREFIX/drive_c/windows/system32/"
fi

echo -e "${Prp}"

"$TEMP_DIR/winetricks" "fontsmooth=rgb" "gdiplus" "msxml3" "msxml6" "atmlib" "corefonts" "dxvk" "win10"

echo -e "${Rst}"

# downloading
echo "Downloading Adobe Photoshop files, this approximates to about 1.6GB"
echo "Source used: $DOWNLOAD_URL"
echo "GitHub project used: https://github.com/MiMillieuh/Photoshop-CC2022-Linux"

if [ "$PS_VERSION" == "2022" ]; then
    files=("allredist.tar.xz" "Adobe.tar.xz" "AdobePhotoshop2022.tar.xz" "Adobe_Photoshop_2022_Settings.tar.xz")
else
    files=("allredist.tar.xz"  "AdobePhotoshop2021.tar.xz")
fi

for file in "${files[@]}"; do
    if [ "$file" == "allredist.tar.xz" ]; then
        d="$DOWNLOAD_URL_A"
        d_backup="$DOWNLOAD_URL_BACKUP_A"
    else
        d="$DOWNLOAD_URL"
        d_backup="$DOWNLOAD_URL_BACKUP"
    fi
    echo -e "${Cyn}Downloading $file${Rst}"
    if [ -f "$TEMP_DIR/$file" ] && (echo "$SHA256_CHECKSUMS" | grep "$file" | sha256sum --check --status); then
        echo -e "${Ylw}Using cached $file${Rst}"
        continue
    fi
    touch "$TEMP_DIR/$file"
    echo -e "${Ylw}"
    wget -O "$TEMP_DIR/$file" -q --show-progress "$d/$file"
    echo -e "${Rst}"
    if !(echo "$SHA256_CHECKSUMS" | grep "$file" | sha256sum --check --status); then
        echo -e "${Red}Downloading $file failed (or shasums mismatched). Trying backup url.${Rst}" >&2
        echo -e "${Ylw}"
        wget -O "$TEMP_DIR/$file" -q --show-progress "$d_backup/$file"
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
mkdir -p "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Adobe/Adobe Photoshop $PS_VERSION/"

rm "$TEMP_DIR/allredist" -rf
tar -xf "$TEMP_DIR/allredist.tar.xz" -C "$TEMP_DIR" # all
mv "$TEMP_DIR/allredist/photoshop.png" "$WINEPREFIX"
mv "$TEMP_DIR/vkd3d" "$TEMP_DIR/allredist/"

echo -e "${Prp}"
"$TEMP_DIR/allredist/vkd3d" install
echo -e "${Rst}"

tar -xf "$TEMP_DIR/AdobePhotoshop$PS_VERSION.tar.xz" -C "$WINEPREFIX/drive_c/Program Files/Adobe/"


if [ "$PS_VERSION" == "2022" ]; then
    tar -xf "$TEMP_DIR/Adobe.tar.xz" -C "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/" #2022
    tar -xf "$TEMP_DIR/Adobe_Photoshop_2022_Settings.tar.xz" -C "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Adobe/Adobe Photoshop $PS_VERSION/" # 2022
fi


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
export DXVK_STATE_CACHE_PATH="\$WINEPREFIX"
export DXVK_LOG_PATH="\$WINEPREFIX"
export SCR_PATH="pspath"
export CACHE_PATH="pscache"
export RESOURCES_PATH="\$SCR_PATH/resources"
export WINE_PREFIX="\$SCR_PATH/prefix"
if [ "\$1" == "launch" ]; then
    FILE_PATH=\$(winepath -w "\$2")
    wine "\$WINEPREFIX/drive_c/Program Files/Adobe/Adobe Photoshop $PS_VERSION/photoshop.exe" "\$FILE_PATH" &
    exit 0
fi
if [ "\$1" == "generate" ]; then
    cat << EoF > "\$WINEPREFIX/photoshop-$PS_VERSION-wine.desktop"
[Desktop Entry]
Name=Adobe Photoshop $PS_VERSION
Path=\$WINEPREFIX
Exec=bash -c "'\$WINEPREFIX/photoshop_launcher.sh' launch '%F'"
Type=Application
Comment=Adobe Photoshop $PS_VERSION (Wine)
Categories=Graphics;
Icon=\$WINEPREFIX/photoshop.png
StartupWMClass=photoshop.exe
EoF
    ln -sf "\$WINEPREFIX/photoshop-$PS_VERSION-wine.desktop" "\$DESKTOP_PATH/photoshop-$PS_VERSION-wine.desktop"
    update-desktop-database "\$DESKTOP_PATH"
    echo -e "\033[0;36mDesktop files of WINEPREFIX='\$WINEPREFIX' generated at '\$DESKTOP_PATH'\033[0m"
    exit 0
fi
echo "Usage: \$0 [launch|generate]"
exit 1
EOF

chmod +x "$WINEPREFIX/photoshop_launcher.sh"

"$WINEPREFIX/photoshop_launcher.sh" "generate"

echo -e "${Grn}Installation complete.${Rst}"

echo -e -n "${Cyn}Do you want to install CameraRaw?${Rst} (y/N) "
read -r answer
if [ "${answer,,}" = "y" ]; then
    installCameraRaw
else
    echo -e "CameraRaw will not be installed."
fi

echo -e -n "${Cyn}Do you want to delete the downloaded temporary files?${Rst} (y/N) "
read -r answer
if [ "${answer,,}" = "y" ]; then
    rm "$TEMP_DIR" -rf
    echo "Files are deleted."
else
    echo "Files in '$TEMP_DIR' will not be deleted."
fi
