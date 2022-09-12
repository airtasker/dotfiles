#!/usr/bin/env bash

set -eou pipefail

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `bootstrap.sh` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Install brew
# This will automatically install xcode command-line tools for us
# FIXME: this isn't detecting sudo for some reason
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ensure brew command is available in PATH
echo 'eval "/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "/opt/homebrew/bin/brew shellenv)"

# Install Rosetta2 on M1 Macs
softwareupdate --install-rosetta --agree-to-license

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install asdf version manager
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.10.2

echo "Bootstrap complete."
