# Prefer enhanced tools when available and retain native fallbacks otherwise.
# if (( ${+commands[eza]} )); then
#   alias ls='eza --icons'
#   alias ll='eza -lh --icons --git'
#   alias la='eza -lah --icons --git'
#   alias tree='eza --tree --icons'
#   (( ${+functions[compdef]} )) && compdef eza=ls
# elif (( ${+commands[ls]} )); then
#   alias ll='ls -lh'
#   alias la='ls -lah'
# fi

if (( ${+commands[bat]} )); then
  alias cat='bat'
elif (( ${+commands[batcat]} )); then
  alias cat='batcat'
fi

if (( ${+commands[rg]} )); then
  alias grep='rg --color=auto'
fi

if (( ${+commands[df]} )); then
  alias df='df -h'
fi

# BSD diff rejects --color; probe the installed implementation first.
if (( ${+commands[diff]} )) && command diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff='diff --color=auto'
fi

alias -- -='cd -'

lf() {
  if (( ! ${+commands[lf]} )); then
    print -u2 -r -- 'lf is not installed'
    return 127
  fi

  local tmp dir
  tmp=$(mktemp) || return 1
  command lf -last-dir-path="$tmp" "$@"
  if [[ -f $tmp ]]; then
    dir=$(<$tmp)
    command rm -f -- "$tmp"
    [[ -d $dir && $dir != $PWD ]] && builtin cd -- "$dir"
  fi
}

if (( ${+commands[nvim]} )); then
  alias vim='nvim'
fi

if (( ${+commands[git]} )); then
  alias glog='PAGER="less -F -X" git log'
  alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
  alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
fi

# Python Configuration
alias venv='pyenv virtualenv 3.14.7'
alias vactivate='pyenv activate'
