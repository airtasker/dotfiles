# Clean local repo(s) of deleted upstream branches
function git-clean {
  if [[ $1 == "-r" ]]; then
    # Clean all repos
    # Assumes all your repos are in a single folder
    # Relies on cleanup-local-branches function
    echo "Cleaning all folders..."
    for dir in */; do
    echo "- Cleaning local branches in repo $dir..."
      cd $dir
      cleanup-local-branches
      cd ..
    done
  else
    cleanup-local-branches
  fi
}

# Clean deleted upstream branches
function cleanup-local-branches {
  # fetch all branches
  git fetch --all
  # Prune remote branches
  git remote prune origin
  # Delete local branches that are ":gone" from origin
  git branch -vv | grep 'origin/.*: gone]' | awk '{print $1}' | xargs git branch -D
}

# function to return main branch
git_main_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local ref
	for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk}
	do
		if command git show-ref -q --verify $ref
		then
			echo ${ref:t}
			return
		fi
	done
	echo master
}

# Install brew packages
function install_brew_defaults() {
brew bundle install --file $HOME/dotfiles/Brewfile 2>/dev/null
}

# Nicely formatted diff for announcements - Alias here as it depends on function above
alias deploydiff="git log production..$(git_main_branch) --pretty=format:'%<(23)%an    %s' --abbrev-commit"

# Install asdf defaults
install_asdf_defaults() {
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
      asdf set --home "$p" latest || true
      fi
  done
}

# Install NvChad (neovim config providing solid defaults and beautiful UI)
function install_nvchad() {
  if [[ ! -d $HOME/.config/nvim ]]; then
      git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
  fi
  nvim
  cd ~/dotfiles
  stow nvim
}
# Uninstall NvChad
function uninstall_nvchad() {
  rm -rf ~/.config/nvim
  rm -rf ~/.local/share/nvim
  rm -rf ~/.cache/nvim
}
