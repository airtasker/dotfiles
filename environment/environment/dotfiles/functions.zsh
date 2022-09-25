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