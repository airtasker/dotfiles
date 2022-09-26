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

# Intercept well-intentioned brew commands that will break things
function brew() {
  case $@ in
    *elasticsearch|*mysql|*node|*nodenv|*nvm|*postgresql|*rbenv|*ruby|*rvm|*yarn)
      if [[ $1 == "install" || $1 == "upgrade" ]]; then
        echo "Here be dragons, you don't need to do this, ask someone for guidance..."
      else
        command brew $@
      fi
      ;;
    *)
      command brew $@
      ;;
  esac
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

# Nicely formatted diff for announcements - Alias here as it depends on function above
alias deploydiff="git log production..$(git_main_branch) --pretty=format:'%<(23)%an    %s' --abbrev-commit"

#Switch AWS Context as well
function kubectx() {
role=$(printf ${@} | grep -oE '(engineer|admin)')
account=$(printf ${@} | sed 's:.*\.::')
asp "${account}-${role}"
/opt/homebrew/bin/kubectx "$@"
}
