##############################################
# Adds git support for the touchbar in iterm #
##############################################

# TODO
# - optimize bind / unbind phase to not flash twice
# - refactor to have last branches visited

# states
BRANCHES='branches'

# executes non standard escape codes for iterm
itermSet() {
  echo -ne "\033]1337;$*\a"
}

# displays the name of the current git branch
current_branch() {
  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}

# Init touchbar state
touchBarState=''

# Init branches array
gitBranches=()

# F1-12
F1='^[OP'
F2='^[OQ'
F3='^[OR'
F4='^[OS'
F5='^[[15~'
F6='^[[17~'
F7='^[[18~'
F8='^[[19~'
F9='^[[20~'
F10='^[[21~'
F11='^[[23~'
F12='^[[24~'

fnKeys=($F1 $F2 $F3 $F4 $F5 $F6 $F7 $F8 $F9 $F10 $F11 $F12)

function setKeyLabel(){
  itermSet "SetKeyLabel=$1=$2"
}

function clearTouchbar() {
  itermSet "PopKeyLabels"
}

function unbindTouchbar() {
  for fnKey in "$fnKeys[@]"; do
    bindkey -s "$fnKey" ''
  done
}

function displayDefault() {
  clearTouchbar
  unbindTouchbar

  touchBarState=''

  # Check if the current directory is in a Git repository.
  command git rev-parse --is-inside-work-tree &>/dev/null || return

  # Check if the current directory is in .git before running git checks.
  if [[ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]]; then

    # Ensure the index is up to date.
    git update-index --really-refresh -q &>/dev/null

    # set key names on touch bar
    setKeyLabel 'F1' 'status'
    setKeyLabel 'F2' $(current_branch)
    setKeyLabel 'F3' 'pull'
    setKeyLabel 'F4' 'push'

    # bind git actions
    bindkey -s $F1 'git status \n'
    bindkey    $F2 displayBranches
    bindkey -s $F3 "git pull origin $(current_branch) \n"
    bindkey -s $F4 "git push origin $(current_branch) \n"
  fi
}

function displayBranches() {
  # List of branches for current repo
  gitBranches=($(node -e "console.log('$(echo $(git branch))'.split(/[ ,]+/).toString().split(',').join(' ').toString().replace('* ', ''))"))

  clearTouchbar
  unbindTouchbar

  # change to branches state
  touchBarState=$BRANCHES

  fnKeysIndex=1

  # for each branch name, bind it to a key
  for branch in "$gitBranches[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    bindkey -s $fnKeys[$fnKeysIndex] "git checkout $branch \n"
    setKeyLabel "F$fnKeysIndex" $branch
  done

  # bind back button
  setKeyLabel 'F1' 'back'
  bindkey $F1 displayDefault
}

zle -N displayDefault
zle -N displayBranches

precmd_iterm_touchbar() {
  if [[ $touchBarState == $BRANCHES ]]; then
    displayBranches
  else
    displayDefault
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd precmd_iterm_touchbar
