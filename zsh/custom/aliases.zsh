alias ll='ls -lh'
alias la='ls -lah'

if (( ${+commands[bat]} )); then
  alias cat='bat --paging=never'
elif (( ${+commands[batcat]} )); then
  alias cat='batcat --paging=never'
fi

alias df='df -h'

# BSD diff rejects --color; probe the installed implementation first.
if (( ${+commands[diff]} )) && command diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff='diff --color=auto'
fi

if (( ${+commands[nvim]} )); then
  alias vim='nvim'
fi

if (( ${+commands[git]} )); then
  alias glog='PAGER="less -F -X" git log'
  alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
fi
