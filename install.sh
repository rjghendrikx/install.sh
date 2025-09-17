#!/bin/zsh
# ==============================================================================
# Title: install.sh
# Author: Daniel Vier
# Editor: Ruud Hendrikx
# Description: Automates the setup and configuration of macOS, including
#              installation of essential applications and system preferences.
# Last Edited: September 17, 2025
# ==============================================================================

set -e  # Exit on error

# Check prerequisites
check_prerequisites() {
  # Check if config file exists
  if [[ ! -f "./config" ]]; then
    echo "${RED}Error: config file not found${NC}"
    exit 1
  fi

  # Check network connectivity
  if ! curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
    echo "${RED}Error: No internet connection${NC}"
    exit 1
  fi

  echo "${GREEN}Prerequisites check passed${NC}"
}

source ./config

# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

#########
# Start #
#########

clear
echo " _           _        _ _       _     "
echo "(_)         | |      | | |     | |    "
echo " _ _ __  ___| |_ __ _| | |  ___| |__  "
echo "| | |_ \/ __| __/ _  | | | / __| |_ \ "
echo "| | | | \__ \ || (_| | | |_\__ \ | | |"
echo "|_|_| |_|___/\__\__,_|_|_(_)___/_| |_|"
echo
echo

# Run prerequisites check
check_prerequisites

echo
echo "${GREEN}Enter root password${NC}"

# Ask for the administrator password upfront.
sudo -v

# Keep Sudo until script is finished
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# Update macOS
echo
echo "${GREEN}Looking for updates.."
echo
sudo softwareupdate -i -a

# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Homebrew
install_homebrew() {
  if command -v brew &> /dev/null; then
    echo "${GREEN}Homebrew already installed${NC}"
    return 0
  fi

echo
  echo "${GREEN}Installing Homebrew${NC}"
echo
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_homebrew

# Append Homebrew initialization to .zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>${HOME}/.zprofile
# Immediately evaluate the Homebrew environment settings for the current session
eval "$(/opt/homebrew/bin/brew shellenv)"

# Check installation and update
echo
echo "${GREEN}Checking installation.."
echo
brew update && brew doctor
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Check for Brewfile in the current directory and use it if present
if [ -f "./Brewfile" ]; then
  echo
  echo "${GREEN}Brewfile found. Using it to install packages..."
  brew bundle
  echo "${GREEN}Installation from Brewfile complete."
else
  # If no Brewfile is present, continue with the default installation

  # Install Casks and Formulae
  echo
  echo "${GREEN}Installing formulae...${NC}"
  set +e  # Don't exit on error for individual packages
  for formula in "${FORMULAE[@]}"; do
    brew install "$formula" || echo "${RED}✗ Failed to install $formula${NC}"
  done
  set -e  # Re-enable exit on error

  echo
  echo "${GREEN}Installing casks...${NC}"
  set +e  # Don't exit on error for individual packages
  for cask in "${CASKS[@]}"; do
    brew install --cask "$cask" || echo "${RED}✗ Failed to install $cask${NC}"
  done
  set -e  # Re-enable exit on error

  # App Store
  echo
  echo -n "${RED}Install apps from App Store? ${NC}[y/N]"
  read REPLY
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew install mas
    for app in "${APPSTORE[@]}"; do
      eval "mas install $app"
    done
  fi

  # VS Code Extensions
  echo
  echo -n "${RED}Install VSCode Extensions? ${NC}[y/N]"
  read REPLY
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Install VS Code extensions from config.sh file
    for extension in "${VSCODE[@]}"; do
      code --install-extension "$extension"
    done
  fi
fi

# Install Node.js
if command -v node &> /dev/null; then
  echo
  echo "${GREEN}Node.js already installed: $(node --version)${NC}"
else
echo
echo -n "${RED}Install Node.js via NVM or Brew? ${NC}[N/b]"
read REPLY
fi

if [[ -z $REPLY || $REPLY =~ ^[Nn]$ ]]; then
  echo "${GREEN}Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

  # Loads NVM
  export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  echo "${GREEN}Installing Node via NVM..."
  nvm install --lts
  nvm install node
  nvm alias default node
  nvm use default

fi
if [[ $REPLY =~ ^[Bb]$ ]]; then
  echo "${GREEN}Installing Node via Homebrew..."
  brew install node

fi

# Install NPM Packages
echo
echo "${GREEN}Installing Global NPM Packages..."
npm install -g ${NPMPACKAGES[@]}

# Optional Packages
echo
echo -n "${RED}Install .NET? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install dotnet
  export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
fi

echo
echo -n "${RED}Install Firefox Developer Edition? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew tap homebrew/cask-versions
  brew install firefox-developer-edition
fi

echo
echo -n "${RED}Install PostgreSQL, MySQL & MongoDB? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Postgres
  brew install postgresql
  # MySQL
  brew install mysql
  echo -n "${RED}Set up MySQL now? ${NC}[y/N]"
  read REPLY
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "${GREEN}Starting MySQL..."
    brew services start mysql
    sleep 2
    mysql_secure_installation
  fi
  # MongoDB
  brew tap mongodb/brew
  brew install mongodb-community
fi

echo
echo -n "${RED}Install Epic & Steam ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install steam epic-games
fi

echo
echo -n "${RED}Install Unity Hub? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install unity-hub
fi

echo
echo -n "${RED}Install Figma? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install figma
fi

# Cleanup
echo
echo "${GREEN}Cleaning up..."
brew update && brew upgrade && brew cleanup && brew doctor
mkdir -p ~/Library/LaunchAgents
brew tap homebrew/autoupdate
brew autoupdate start $HOMEBREW_UPDATE_FREQUENCY --upgrade --cleanup --immediate --sudo

# Settings
echo
echo -n "${RED}Configure default system settings? ${NC}[Y/n]"
read REPLY
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
  echo "${GREEN}Configuring default settings..."
  for setting in "${SETTINGS[@]}"; do
    eval $setting
  done
fi

# Dock settings
echo
echo -n "${RED}Apply Dock settings?? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install dockutil
  # Handle replacements
  for item in "${DOCK_REPLACE[@]}"; do
    IFS="|" read -r add_app replace_app <<<"$item"
    dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null
  done
  # Handle additions
  for app in "${DOCK_ADD[@]}"; do
    dockutil --add "$app" &>/dev/null
  done
  # Handle removals
  for app in "${DOCK_REMOVE[@]}"; do
    dockutil --remove "$app" &>/dev/null
  done
fi

# Git Login
echo
echo "${GREEN}SET UP GIT"
echo

echo "${RED}Please enter your git username:${NC}"
read name
echo "${RED}Please enter your git email:${NC}"
read email

git config --global user.name "$name"
git config --global user.email "$email"
git config --global color.ui true

echo
echo "${GREEN}GITTY UP!"

clear
echo "${GREEN}______ _____ _   _  _____ "
echo "${GREEN}|  _  \  _  | \ | ||  ___|"
echo "${GREEN}| | | | | | |  \| || |__  "
echo "${GREEN}| | | | | | | .   ||  __| "
echo "${GREEN}| |/ /\ \_/ / |\  || |___ "
echo "${GREEN}|___/  \___/\_| \_/\____/ "

echo
echo
printf "${RED}"
read -s -k $'?Press ANY KEY to REBOOT\n'
sudo reboot
exit
