#!/usr/bin/env zsh

set -eo pipefail

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `bootstrap.sh` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Source Environment
mkdir -p $HOME/environment
touch $HOME/environment/environment.zsh $HOME/environment/secrets.zsh $HOME/environment/aliases.zsh $HOME/environment/functions.zsh
for file in $(find -L $HOME/environment -type f -type f \( -name "*.rc" -o -name "*.zsh" -o -name "*.sh" \) ); do 
    source "${file}"
done

# Read from user
if [ -z ${GITHUB_EMAIL+x} ]; then 
    read -p "Enter Github Email: " GITHUB_EMAIL
    echo "GITHUB_EMAIL=${GITHUB_EMAIL}" >> $HOME/environment/secrets.zsh
fi
if [ -z ${GITHUB_PAT+x} ]; then 
    read -p "Enter Github Personal Access Token: " GITHUB_PAT
    echo "GITHUB_PAT=${GITHUB_PAT}" >> $HOME/environment/secrets.zsh
fi

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

# Install brew packages
brew bundle install --no-lock --file $HOME/dotfiles/Brewfile 2>/dev/null

# Setup SSH Key
brew install gh
# Get Serial Number
serial_number=$(system_profiler SPHardwareDataType | grep Serial | sed 's/^.*: //')
echo "$GITHUB_PAT" | gh auth login --with-token -p ssh -h github.com
if [[ ! -f $HOME/.ssh/id_ed25519 ]]; then 
    ssh-keygen -t ed25519 -C "$github_email" -f $HOME/.ssh/id_ed25519
    gh ssh-key add -t "$(hostname)-${serial_number}" $HOME/.ssh/id_ed25519.pub
fi

DOTFILES_REPO=${DOTFILES_REPO:-airtasker\/dotfiles.git}
if [[ ! -d $HOME/dotfiles ]]; then
    # Clone airtasker dotfiles locally
    git clone https://github.com/"$DOTFILES_REPO" $HOME/dotfiles
    cd $HOME/dotfiles
else
    cd $HOME/dotfiles
    git pull
fi

# Install NvChad (neovim config providing solid defaults and beautiful UI)
if [[ ! -d $HOME/.config/nvim ]]; then
    git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
    nvim
fi

# Install Stow and Symlink stow packages (dotfiles)
brew install stow
for d in "$HOME"/dotfiles/*/ ; do
    d=$(basename "$d")
    array=( $(stow "$d" 2>&1 >/dev/null | grep "* existing targe" |sed 's/^.*: //' || true) )
    if ! (( ${#array[@]} > 0)); then
        # If array is empty then stow was successful
	    echo "successfully stowed $d"
    else
    for file in "${array[@]}"; do
        read -q "remove_file?Delete $file from home directory in order to sync with dotfiles? (yes/no) "
        if [[ "$remove_file" = y* ]]; then
            rm -f "$HOME"/"$file"
        fi
    done
    if [[ "$remove_file" = y* ]]; then stow "$d"; fi
    fi
done

if [[ ! -d $HOME/.oh-my-zsh ]]; then
    # Install Oh My Zsh if not already installed
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
    # Update Oh My Zsh if already installed
    if [[ $(command -v omz) ]]; then
    	omz update
    fi
fi

# Install zsh-autosuggestions
if [[ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-autosuggestions
fi

# Install zsh-syntax-highlighting
if [[ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-syntax-highlighting
fi

# Install powerlevel10k
if [[ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Install asdf version manager
if [[ ! -d $HOME/.asdf ]]; then
    git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.10.2
fi

# Verify asdf command exists and source otherwise
if [[ ! $(command -v asdf) ]]; then
    . $HOME/.asdf/asdf.sh
    . $HOME/.asdf/completions/asdf.bash
fi

# Ensure $HOME/.z exists to suppress warning on first run
touch $HOME/.z

# Setup git
git config --global user.name "$(gh api user | jq -r '.login')"
git config --global user.email "${GITHUB_EMAIL}"

# Install ASDF plugins and install latest packages by default
asdf_plugins=( golang java kubectl nodejs python ruby terraform )
for p in "${asdf_plugins[@]}"; do
    if [[ ! -d $HOME/.asdf/plugins/$p ]]; then
        asdf plugin add $p
    else
        asdf plugin update $p >/dev/null 2>&1
    fi
    touch $HOME/.tool-versions
    if ! grep "$p" < $HOME/.tool-versions >/dev/null 2>&1 ; then
       asdf install "$p" latest
       asdf global "$p" latest || true
    fi
done
asdf install

if [[ $SHELL != "$(which zsh)" ]]; then
    chsh -s $(which zsh) $USER
fi

echo "Bootstrap complete."

