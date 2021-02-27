#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@#         @@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@*               @@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@               /@@@@@     /@@@@@@@@@@@@@@@@
@@@@@@@@@@@@&               &@@@@#              @@@@@@@@@@@@
@@@@@@@@(               @@@@@@@@@@@@(               @@@@@@@@
@@@@@@%            /@@@@@@@@@@@@@@@@@@@@@             @@@@@@
@@@@@@%        %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@
@@@@@@%       /\033[0;32m(((\033[0m@@@@@@@@@@@@@@@@@@@@@@@@@\033[0;32m###\033[0m        @@@@@@
@@@@@@%       /\033[0;32m(((((((\033[0m&@@@@@@@@@@@@@@@%\033[0;32m#######\033[0m        @@@@@@
@@@@@@%       /\033[0;32m((((((((((((\033[0m@@@@@@@\033[0;32m########\033[0m@@@@        @@@@@@
@@@@@@%       /\033[0;32m((((\033[0m@@@@\033[0;32m(((((((\033[0;32m##########\033[0m&@@@@@        @@@@@@
@@@@@@%       /\033[0;32m((((\033[0m#@@@@@%\033[0;32m((((\033[0;32m###\033[0m&@@&\033[0;32m###\033[0m&@@@@@        @@@@@@
@@@@@@%       /\033[0;32m(((((((((\033[0m@%\033[0;32m((((\033[0m&@@@@@&\033[0;32m###\033[0m&@@@@@        @@@@@@
@@@@@@%       /\033[0;32m((((\033[0m@@&\033[0;32m((((((((\033[0m&@@@@@&\033[0;32m###\033[0m&@@@@@        @@@@@@
@@@@@@%         \033[0;32m(((\033[0m@@@@@@%\033[0;32m((((\033[0m&@@@@@&\033[0;32m###\033[0m&@@@@         @@@@@@
@@@@@@%             &@@@@%\033[0;32m((((\033[0m&@@@@@&\033[0;32m###\033[0m(             @@@@@@
@@@@@@@@@               /%\033[0;32m((((\033[0m&@@@@@               /@@@@@@@@
@@@@@@@@@@@@@                (&@               %@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@(                         @@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@                 @@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@        /@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
function error {
  echo -e "\\e[91m$1\\e[39m"
  if [ -d ~/pi-apps ];then
    echo corrupted >$HOME/pi-apps/data/status/ATlauncherPI
  fi
  exit 1
}

#install dependencies
echo "installing java and dependencies..."
PKG_LIST="openjdk-11-jre zip"
echo -n "Waiting until APT locks are released... "
while sudo fuser /var/lib/dpkg/lock &>/dev/null ; do
  sleep 1
done
while sudo fuser /var/lib/apt/lists/lock &>/dev/null ; do
  sleep 1
done
if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
  while sudo fuser /var/log/unattended-upgrades/unattended-upgrades.log &>/dev/null ; do
    sleep 1
  done
fi
echo -n Done!
#exit on apt error
DEBIAN_FRONTEND=noninteractive
LANG=C
LC_ALL=C
#inform user packages are upgradeable
output="$(sudo LANG=C LC_ALL=C apt update 2>&1)"
if [ ! -z "$(echo "$output" | grep 'packages can be upgraded' )" ];then
  echo -e "\e[33mSome packages can be upgraded.\e[39m Please consider running \e[4msudo apt full-upgrade -y\e[0m."
fi
exitcode=$?
errors="$(echo "$output" | grep '^[(W)|(E)|(Err]:')"
if [ $exitcode != 0 ] || [ ! -z "$errors" ];then
  echo -e "\e[91mFailed to run \e[4msudo apt update\e[0m\e[39m!"
  echo -e "APT reported these errors:\n\e[91m$errors\e[39m"
  exit 1
fi
#remove residual packages
sudo apt autoremove --purge -y >/dev/null && sudo apt clean && sudo apt-get purge -y $(dpkg -l | grep '^rc' | awk '{print $2}')

output="$(sudo LANG=C LC_ALL=C apt-get install --no-install-recommends --dry-run openjdk-11-jre zip 2>&1)"
echo "$output"

errors="$(echo "$output" | grep '^[(W)|(E)|(Err]:')"

if [ ! -z "$errors" ];then
  echo -e "\e[91mFailed to check which packages whould be installed!\e[39m"
  echo -e "APT reported these errors:\n\e[91m$errors\e[39m"
  exit 1
fi
INSTALL_LIST="$(echo "$output" | sed -n '/The following NEW packages/,/to remove/p' | sed -e '2,$!d' -e '$d' | tr -d '*' | tr '\n' ' ' | sed 's/The following.*//')"

if [ ! -z "$INSTALL_LIST" ];then
  #save that list of installed packages in the program directory for future removal
  mkdir -p "${DIRECTORY}/data/installed-packages"
  
  echo -e "These packages will be installed: \e[2m$INSTALL_LIST\e[22m"
  
  #normal mode
  output="$(sudo LANG=C LC_ALL=C apt-get install -y --no-install-recommends $PKG_LIST 2>&1)"
  exitcode=$?
  echo 'Apt finished.'
  
  errors="$(echo "$output" | grep '^[(W)|(E)|(Err]:')"
  if [ $exitcode != 0 ] || [ ! -z "$errors" ];then
    echo -e "\e[91mFailed to install the packages!\e[39m"
    echo -e "APT reported these errors:\n\e[91m$errors\e[39m"
    exit 1
  fi
  #re-check package list. This time it should be blank.
  #INSTALL_LIST=''
  #for i in $PKG_LIST
  #do
  #  PKG_OK="$(dpkg-query -W --showformat='${Status}\n' "$i" 2>/dev/null | grep "install ok installed")"
  #  if [ "" == "$PKG_OK" ]; then
  #    INSTALL_LIST="${INSTALL_LIST} ${i}" #add package to install list
  #  fi
  #done
  INSTALL_LIST="$(sudo LANG=C LC_ALL=C apt-get install --no-install-recommends --dry-run $PKG_LIST | sed -n '/The following packages/,/to remove/p' | sed -e '2,$!d' -e '$d' | tr -d '*' | tr '\n' ' ' | sed 's/The following.*//')"
  
  
  if [ ! -z $INSTALL_LIST ];then
    echo -e "\e[91mAPT did not exit with an error, but these packages failed to install somehow: $INSTALL_LIST\e[39m"
    exit 1
  else
    echo -e "\e[32mAll packages were installed succesfully.\e[39m"
  fi
else
  echo -e "\e[32mNo new packages to install. Nothing to do!\e[39m"
fi

echo Done!

#use the error function often!
#If a certain command is necessary for installation to continue, then add this to the end of it:
# || error 'reason'
#example below:

mkdir -p ~/ATlauncher && cd ~/ATlauncher

#determine if host system is 64 bit arm64 or 32 bit armhf
if [ ! -z "$(file "$(readlink -f "/sbin/init")" | grep 64)" ];then
  MACHINE='aarch64'
elif [ ! -z "$(file "$(readlink -f "/sbin/init")" | grep 32)" ];then
  MACHINE='armv7l'
else
  echo "Failed to detect OS CPU architecture! Something is very wrong."
  exit 1
fi


DIR=~/ATlauncher

# create folders
mkdir -p $DIR
cd "$DIR"

if [ "$MACHINE" = "aarch64" ]; then
    echo "Raspberry Pi OS (64 bit)"
    if [ ! -d ~/lwjgl3arm64 ]; then
        mkdir -p ~/lwjgl3arm64
    fi
else
    echo "Raspberry Pi OS (32 bit)"
        mkdir -p ~/lwjgl3arm32
        mkdir -p ~/lwjgl2arm32
fi

# download minecraft launcher
rm -f launcher.jar
echo "Downloading launcher..."
wget -q --show-progress https://atlauncher.com/download/jar --output-document launcher.jar || error "failed to download \"launcher.jar\""
rm -rf launcher && mkdir -p launcher && cd launcher && mkdir -p ./assets/image && wget -q https://raw.githubusercontent.com/pi-dev500/MinecraftMicrosoftPILauncher/main/SplashScreen.png && mv SplashScreen.png assets/image/SplashScreen.png && zip -rm ../launcher.jar * >/dev/null && cd $DIR && rm -rf launcher
cd $DIR
echo "Done!"
# download lwjgl3arm*
echo downloading lwjgl3arm...
if [ "$MACHINE" = "aarch64" ]; then
    if [ ! -f lwjgl3arm64.tar.gz ]; then
        wget -q --show-progress https://github.com/mikehooper/Minecraft/raw/main/lwjgl3arm64.tar.gz || error "failed to download lwjgl3arm64"
    fi
else
    if [ ! -f lwjgl3arm32.tar.gz ]; then
        wget -q --show-progress https://github.com/mikehooper/Minecraft/raw/main/lwjgl3arm32.tar.gz || error "failed to download lwjgl3arm32"
    fi
    if [ ! -f lwjgl2arm32.tar.gz ]; then
        wget -q --show-progress https://github.com/mikehooper/Minecraft/raw/main/lwjgl2arm32.tar.gz || error "failed to download lwjgl2arm32"
    fi
fi
echo Done!
# extract lwjgl*
echo Extracting lwjgl...
if [ "$MACHINE" = "aarch64" ]; then
  mkdir -p ~/.local/share/ATlauncher/lwjgl3arm64
  tar -zxf lwjgl3arm64.tar.gz -C ~/.local/share/ATlauncher/lwjgl3arm64 || exit 1
else
  mkdir -p ~/.local/share/ATlauncher/lwjgl3arm32
  mkdir -p ~/.local/share/ATlauncher/lwjgl2arm32
  tar -zxf lwjgl3arm32.tar.gz -C ~/.local/share/ATlauncher/lwjgl3arm32 || exit 1
  tar -zxf lwjgl2arm32.tar.gz -C ~/.local/share/ATlauncher/lwjgl2arm32 || exit 1
fi

echo done \!


#Move launcher to /usr/share/
cd $DIR
mkdir -p $HOME/.local/share/ATlauncher/jarfile && mv launcher.jar ~/.local/share/ATlauncher/jarfile/launcher.jar

#Create desktop shortcut
echo Creating desktop shortcut ...
wget -q https://github.com/pi-dev500/MinecraftMicrosoftPILauncher/raw/main/ATlauncherPI/icon-64.png && cp icon-64.png ~/.local/share/icons/ATlauncher.png
cd ~/.local/share/applications/
echo "[Desktop Entry]
Version=1.0
Type=Application
Name=ATlauncher
Comment=3D block based sandbox game
Icon=ATlauncher
Exec='$HOME'/.local/share/ATlauncher/jdk/jdk1.8.0_251/bin/java -jar $HOME/.local/share/ATlauncher/jarfile/launcher.jar
Categories=Game;
" >ATlauncher.desktop
cd $HOME/.local/share/ATlauncher
if [ -f /usr/bin/zip ];then
	wget -q https://raw.githubusercontent.com/pi-dev500/MinecraftMicrosoftPILauncher/main/update
	mkdir -p ~/.local/share/ATlauncher/webpage
	cd ~/.local/share/ATlauncher/webpage
	wget -q https://github.com/ATLauncher/ATLauncher/releases/latest
	mkdir -p ~/.local/share/ATlauncher/webpage/old/
	mv latest old/latest
	mkdir -p ~/.config/autostart/ && cd ~/.config/autostart/
	echo "[Desktop Entry]
Version=1.0
Type=Application
Name=ATlauncher
Comment=3D block based sandbox game
Icon=ATlauncher
Exec=$HOME/.local/share/ATlauncher/update
Categories=Game;
" >ATlauncher.desktop
fi
echo Creating configuration file...
chmod +x ATlauncher.desktop
cd
mkdir -p $HOME/.local/share/ATlauncher/jarfile/configs && cd $HOME/.local/share/ATlauncher/jarfile/configs
if [  "$MACHINE" == "armv7l" ];then
  echo '{
  "usingCustomJavaPath": true,
  "hideOldJavaWarning": false,
  "firstTimeRun": false,
  "hideJava9Warning": true,
  "addedPacks": [],
  "ignoreOneDriveWarning": false,
  "ignoreProgramFilesWarning": false,
  "rememberWindowSizePosition": false,
  "consoleSize": {
    "width": 650,
    "height": 400
  },
  "consolePosition": {
    "x": 0,
    "y": 0
  },
  "launcherSize": {
    "width": 1200,
    "height": 700
  },
  "language": "anglais",
  "theme": "com.atlauncher.themes.Vuesion",
  "dateFormat": "dd/MM/yyyy",
  "selectedTabOnStartup": 0,
  "sortPacksAlphabetically": false,
  "showPackNameAndVersion": true,
  "keepLauncherOpen": true,
  "enableConsole": true,
  "enableTrayMenu": true,
  "enableDiscordIntegration": true,
  "enableFeralGamemode": true,
  "disableAddModRestrictions": false,
  "disableCustomFonts": false,
  "useNativeFilePicker": false,
  "initialMemory": 512,
  "maximumMemory": 2048,
  "metaspace": 256,
  "windowWidth": 854,
  "windowHeight": 480,
  "javaPath": "'$HOME'/.local/share/ATlauncher/jdk/jdk1.8.0_251/bin/java",
  "javaParameters": "-Dorg.lwjgl.librarypath='$HOME'/.local/share/ATlauncher/lwjgl3arm32 -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -XX:-UseAdaptiveSizePolicy -Xmn128M",
  "maximiseMinecraft": false,
  "ignoreJavaOnInstanceLaunch": false,
  "concurrentConnections": 8,
  "connectionTimeout": 30,
  "enableProxy": false,
  "proxyHost": "",
  "proxyPort": 8080,
  "proxyType": "HTTP",
  "forgeLoggingLevel": "INFO",
  "enableLogs": true,
  "enableAnalytics": true,
  "analyticsClientId": "30662333-d88f-4e21-8d77-95739af9bf78",
  "enableOpenEyeReporting": true,
  "enableServerChecker": false,
  "serverCheckerWait": 5,
  "enableModsBackups": false,
  "enableAutomaticBackupAfterLaunch": false
}' >ATLauncher.json
else
  echo '{
  "usingCustomJavaPath": true,
  "hideOldJavaWarning": false,
  "firstTimeRun": false,
  "hideJava9Warning": true,
  "addedPacks": [],
  "ignoreOneDriveWarning": false,
  "ignoreProgramFilesWarning": false,
  "rememberWindowSizePosition": false,
  "consoleSize": {
    "width": 650,
    "height": 400
  },
  "consolePosition": {
    "x": 0,
    "y": 0
  },
  "launcherSize": {
    "width": 1200,
    "height": 700
  },
  "language": "anglais",
  "theme": "com.atlauncher.themes.Vuesion",
  "dateFormat": "dd/MM/yyyy",
  "selectedTabOnStartup": 0,
  "sortPacksAlphabetically": false,
  "showPackNameAndVersion": true,
  "keepLauncherOpen": true,
  "enableConsole": true,
  "enableTrayMenu": true,
  "enableDiscordIntegration": true,
  "enableFeralGamemode": true,
  "disableAddModRestrictions": false,
  "disableCustomFonts": false,
  "useNativeFilePicker": false,
  "initialMemory": 512,
  "maximumMemory": 2048,
  "metaspace": 256,
  "windowWidth": 854,
  "windowHeight": 480,
  "javaPath": "'$HOME'/.local/share/ATlauncher/jdk/jdk1.8.0_251/bin/java",
  "javaParameters": "-Dorg.lwjgl.librarypath='$HOME'/.local/share/ATlauncher/lwjgl3arm64 -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -XX:-UseAdaptiveSizePolicy -Xmn128M",
  "maximiseMinecraft": false,
  "ignoreJavaOnInstanceLaunch": false,
  "concurrentConnections": 8,
  "connectionTimeout": 30,
  "enableProxy": false,
  "proxyHost": "",
  "proxyPort": 8080,
  "proxyType": "HTTP",
  "forgeLoggingLevel": "INFO",
  "enableLogs": true,
  "enableAnalytics": true,
  "analyticsClientId": "30662333-d88f-4e21-8d77-95739af9bf78",
  "enableOpenEyeReporting": true,
  "enableServerChecker": false,
  "serverCheckerWait": 5,
  "enableModsBackups": false,
  "enableAutomaticBackupAfterLaunch": false
}' >ATLauncher.json
fi

sudo rm -rf ~/ATlauncher
echo 'Installation is now done! You can open the launcher by going to Menu > Games > ATlauncher'

