#!/usr/bin/env zsh

set -eo pipefail

echo "####### SSH Key Rotation Script #######"

# Source environment files to get GITHUB_EMAIL and GITHUB_TOKEN
for file in environment.zsh secrets.zsh aliases.zsh functions.zsh; do
    if [[ -f $HOME/environment/${file} ]]; then
        . "$HOME/environment/${file}"
    fi
done

# Prompt for GITHUB_EMAIL with default
current_email="${GITHUB_EMAIL:-}"
read "input_email?Enter Github Email [${current_email}]: "
if [[ -n "$input_email" ]]; then
    GITHUB_EMAIL="$input_email"
    sed -i '' '/^GITHUB_EMAIL=/d' $HOME/environment/environment.zsh
    echo "GITHUB_EMAIL=${GITHUB_EMAIL}" >> $HOME/environment/environment.zsh
elif [[ -z "$current_email" ]]; then
    echo "ERROR: GITHUB_EMAIL is required"
    exit 1
else
    GITHUB_EMAIL="$current_email"
fi

# Prompt for GITHUB_TOKEN with default
current_token="${GITHUB_TOKEN:-}"
if [[ -n "$current_token" ]]; then
    token_display="(already set)"
else
    token_display=""
fi
read "input_token?Enter Github Personal Access Token [${token_display}]: "
if [[ -n "$input_token" ]]; then
    GITHUB_TOKEN="$input_token"
    sed -i '' '/^GITHUB_TOKEN=/d' $HOME/environment/environment.zsh
    echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> $HOME/environment/environment.zsh
    export GITHUB_TOKEN="${GITHUB_TOKEN}"
elif [[ -z "$current_token" ]]; then
    echo "ERROR: GITHUB_TOKEN is required"
    exit 1
else
    GITHUB_TOKEN="$current_token"
    export GITHUB_TOKEN="${GITHUB_TOKEN}"
fi

# Check if SSH key exists
if [[ ! -f $HOME/.ssh/id_ed25519 ]]; then
    echo "ERROR: No SSH key found at $HOME/.ssh/id_ed25519"
    echo "Run bootstrap.sh first to create an initial SSH key"
    exit 1
fi

# Confirm rotation
read "confirm?Are you sure you want to rotate your SSH key? This will backup the old key and create a new one. (y/n) "
if [[ ! "$confirm" =~ ^[Yy] ]]; then
    echo "SSH key rotation cancelled"
    exit 0
fi

echo "####### Rotating SSH Key #######"

# Backup old keys
mv $HOME/.ssh/id_ed25519 $HOME/.ssh/id_ed25519.backup
mv $HOME/.ssh/id_ed25519.pub $HOME/.ssh/id_ed25519.pub.backup
echo "Old keys backed up to ~/.ssh/id_ed25519.backup"

# Remove old key from GitHub
old_public_key=$(cat $HOME/.ssh/id_ed25519.pub.backup)
echo "Removing old SSH key from GitHub..."
echo "Refreshing GitHub CLI authentication with required scope..."
gh auth refresh -h github.com -s admin:public_key || true
gh ssh-key list | grep "${old_public_key:0:50}" | awk '{print $5}' | xargs -I {} gh ssh-key delete {} --yes || true

# Generate new SSH key
echo "####### Generating New SSH Key #######"
echo "####### Optional - Type in passphrase for newly created SSH Key #######"
ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f $HOME/.ssh/id_ed25519

# Add new SSH key to keychain
echo "Adding new SSH key to keychain..."
echo "Type in SSH Key Passphrase to add this key to your keychain (The one you entered above)"
ssh-add -q --apple-use-keychain $HOME/.ssh/id_ed25519

# Add new SSH key to GitHub
echo "Adding new SSH key to GitHub..."
serial_number=$(system_profiler SPHardwareDataType | grep Serial | sed 's/^.*: //')
public_key=$(cat $HOME/.ssh/id_ed25519.pub)
if ! gh ssh-key list | grep -q "${public_key:0:50}"; then
    gh ssh-key add -t "$(hostname)-${serial_number}" $HOME/.ssh/id_ed25519.pub || true
    echo "New SSH key added to GitHub"
else
    echo "SSH key already exists on GitHub"
fi

echo ""
echo "####### SSH Key Rotation Complete #######"
echo "Old keys backed up to:"
echo "  - ~/.ssh/id_ed25519.backup"
echo "  - ~/.ssh/id_ed25519.pub.backup"
