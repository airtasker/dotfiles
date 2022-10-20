#!/usr/bin/env zsh

set -eo pipefail

# Ask for the administrator password upfront
sudo -v

## Functions
# Ensure brew command is available in PATH
function brew_in_path() {
    if [[ $(uname -m) == "arm64" ]]; then
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        if [[ -f /usr/local/Homebrew/bin/brew ]]; then
            eval "$(/usr/local/Homebrew/bin/brew shellenv)"
        fi
    fi
}

# Keep-alive: update existing `sudo` time stamp until `bootstrap.sh` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Source ~/environment recursively for files ending with *.rc *.zsh *.sh
mkdir -p $HOME/environment
touch $HOME/environment/environment.zsh $HOME/environment/secrets.zsh $HOME/environment/aliases.zsh $HOME/environment/functions.zsh
for file in $(find -L $HOME/environment -type f -type f \( -name "*.rc" -o -name "*.zsh" -o -name "*.sh" \) | sort ); do
    if [[ ${DEBUG:-FALSE} == "TRUE" ]]; then
      echo "Now sourcing ${file}"
    fi
    . "${file}"
done

# Read from user
if [ -z ${GITHUB_EMAIL+x} ]; then 
    read "GITHUB_EMAIL?Enter Github Email: "
    echo "GITHUB_EMAIL=${GITHUB_EMAIL}" >> $HOME/environment/environment.zsh
fi
if [ -z ${GITHUB_TOKEN+x} ]; then 
    read "GITHUB_PAT?Enter Github Peronal Access Token: "
    echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> $HOME/environment/environment.zsh
fi

# Create SSH Key
if [[ ! -f $HOME/.ssh/id_ed25519 ]]; then 
    echo "####### Writing SSH Key #######"
    echo "####### Optional - Type in passphrase for newly created SSH Key #######"
    ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f $HOME/.ssh/id_ed25519

    # Add SSHKeys to keychain
    echo "Type in SSH Key Passphrase to add this key to your keychain (The one you entered above)"
    for file in ~/.ssh/*.pub; do ssh-add -q --apple-use-keychain "${file%.*}";done
fi

brew_in_path

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

brew_in_path

# Add SSH Key to Github Account
brew install gh
# Get Serial Number
set -x 
serial_number=$(system_profiler SPHardwareDataType | grep Serial | sed 's/^.*: //')
public_key=$(cat $HOME/.ssh/id_ed25519.pub)
export GITHUB_TOKEN="${GITHUB_TOKEN}"
gh auth login -p ssh -h github.com > /dev/null
if ! gh ssh-key list | grep -q "${public_key:0:50}"; then 
    gh ssh-key add -t "$(hostname)-${serial_number}" $HOME/.ssh/id_ed25519.pub || true
fi
set +x

DOTFILES_REPO=${DOTFILES_REPO:-airtasker\/dotfiles.git}
if [[ ! -d $HOME/dotfiles ]]; then
    # Add github.com to known hosts to avoid prompt
    ssh-keyscan github.com >> ~/.ssh/known_hosts
    # Clone airtasker dotfiles locally
    git clone git@github.com:"$DOTFILES_REPO" $HOME/dotfiles
    cd $HOME/dotfiles
else
    cd $HOME/dotfiles
    git pull
fi

# Install brew packages
brew bundle install --no-lock --file $HOME/dotfiles/Brewfile 2>/dev/null

# Install Stow and Symlink stow packages (dotfiles)
brew install stow
for d in "$HOME"/dotfiles/*/ ; do
    d=$(basename "$d")
    array=( $(stow -t $HOME "$d" 2>&1 >/dev/null | grep "* existing targe" |sed 's/^.*: //' || true) )
    if ! (( ${#array[@]} > 0)); then
        # If array is empty then stow was successful
	    echo "successfully stowed $d"
    else
    for file in "${array[@]}"; do
        read -q "remove_file?Delete $file from home directory in order to sync with dotfiles? (y/n) "
        if [[ "$remove_file" = y* ]]; then
            rm -f "$HOME"/"$file"
        fi
    done
    if [[ "$remove_file" = y* ]]; then stow -t $HOME "$d"; fi
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

# Add kubectx completion
if [[ ! -f ~/.oh-my-zsh/completions/_kubectx.zsh ]]; then
    mkdir -p ~/.oh-my-zsh/completions
    curl -fsSL https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/_kubectx.zsh > ~/.oh-my-zsh/completions/_kubectx.zsh
fi 
# Add kubens completion
if [[ ! -f ~/.oh-my-zsh/completions/_kubens.zsh ]]; then
    curl -fsSL https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/_kubens.zsh > ~/.oh-my-zsh/completions/_kubens.zsh
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

if [[ ! -f ~/.tool-versions ]]; then 
    . $HOME/.asdf/asdf.sh
    # Install ASDF plugins and install latest packages by default
    asdf_plugins=( golang kubectl nodejs python ruby terraform )
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
fi

# Ensure $HOME/.z exists to suppress warning on first run
touch $HOME/.z

# Setup git
if ! git config user.name; then 
  git config --global user.name "$(gh api user | jq -r '.login')"
fi
if ! git config user.email; then
  git config --global user.email "${GITHUB_EMAIL}"
fi

if [[ $SHELL != "$(which zsh)" ]]; then
    echo "$(which zsh)" | sudo sponge -a /etc/shells
    chsh -s $(which zsh) $USER
fi

if [[ ${NVIM_FIRST_RUN:-false} != "true" ]]; then
    # Uninstall NvChad
    rm -rf ~/.config/nvim
    rm -rf ~/.local/share/nvim
    rm -rf ~/.cache/nvim
    # Install NvChad
    git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
    nvim
    cd ~/dotfiles
    stow -t $HOME nvim
    # Add NVIM_FIRST_RUN variable to environment
    export NVIM_FIRST_RUN=true
    echo "NVIM_FIRST_RUN=true" >> $HOME/environment/environment.zsh
fi

echo "###################
Bootstrap complete.
###################"
echo 'Open iTerm 2 Application and run `p10k configure` to finish customizing your terminal'
