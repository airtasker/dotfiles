#!/usr/bin/env bash

set -eou pipefail

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `bootstrap.sh` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if [[ ! $(command -v brew) ]]; then
    # Install brew if not already installed
    # This will automatically install xcode command-line tools for us
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Install Rosetta2 on M1 Macs
    softwareupdate --install-rosetta --agree-to-license
else
    # Update brew if already installed
    brew update
fi

# Ensure brew command is available in PATH
if [[ ! $(command -v brew) ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/Homebrew/bin/brew shellenv)"
    fi
fi

if [[ ! -d $HOME/.oh-my-zsh ]]; then
    # Install Oh My Zsh if not already installed
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    # Update Oh My Zsh if already installed
    if [[ $(command -v omz) ]]; then
    	omz update
    fi
fi

# Install powerlevel10k
if [[ ! -d ${ZSH_CUSTOM:-$HOME/custom}/themes/powerlevel10k ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/custom}/themes/powerlevel10k
fi

if [[ ! -d $HOME/.asdf ]]; then
    # Install asdf version manager
    git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.10.2
fi
if [[ ! $(command -v asdf) ]]; then
    . $HOME/.asdf/asdf.sh
    . $HOME/.asdf/completions/asdf.bash
fi

if [[ ! -d $HOME/dotfiles ]]; then
    # Clone airtasker dotfiles locally
    git clone https://github.com/airtasker/dotfiles.git $HOME/dotfiles
    cd $HOME/dotfiles
else
    cd $HOME/dotfiles
    git pull
fi

brew install stow
for d in "$HOME"/dotfiles/*/ ; do
    d=$(basename "$d")
    stow "$d"
done

# Ensure $HOME/.z exists to suppress warning on first run
touch $HOME/.z

# Install brew packages in the background
brew bundle install --no-lock --file $HOME/dotfiles/Brewfile 2>/dev/null

asdf_plugins=( golang java kubectl nodejs python ruby terraform )
for p in "${asdf_plugins[@]}"; do
    if [[ ! -d $HOME/.asdf/plugins/$p ]]; then
        asdf plugin add $p
    else
        asdf plugin update $p >/dev/null 2>&1
    fi
    if ! grep "$p" < $HOME/.tool-versions >/dev/null 2>&1 ; then
       asdf global "$p" latest || true
    fi
done
asdf install

if [[ $SHELL != "$(which zsh)" ]]; then
    chsh -s $(which zsh) $USER
fi

echo "Bootstrap complete."

