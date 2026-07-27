# Better ls/eza aliases. Guard Homebrew tools so a fresh macOS upgrade shell
# still starts cleanly before packages have been restored.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'
  alias la='eza -lah --icons --git'
  alias tree='eza --tree --icons'

  # Reuse ls completions for eza when compinit has already provided compdef.
  (( $+functions[compdef] )) && compdef eza=ls
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi

# Better cat when bat is installed.
if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
fi

# =========================================================
# Core utilities
# =========================================================

if command -v rg >/dev/null 2>&1; then
  alias grep='rg --color=auto'
fi
alias df='df -h'

# diff --color is GNU-only; enable it only if this diff supports it
# (macOS / BSD diff errors on --color, so guard it)
if diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff='diff --color=auto'
fi

# =========================================================
# Navigation
# =========================================================

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

lf() { # cd into the directory where you quit lf
    if ! command -v lf >/dev/null 2>&1; then
        print -u2 'lf is not installed'
        return 127
    fi

    local tmp dir
    tmp=$(mktemp)
    command lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(<"$tmp")"   # builtin read; avoids a possible cat='bat' alias above
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$PWD" ] && cd "$dir"
    fi
}

# =========================================================
# Editor
# =========================================================

if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
fi

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# =========================================================
# Video
# =========================================================

if command -v mpv >/dev/null 2>&1; then
  alias stream='mpv av://v4l2:/dev/video4 --fullscreen --demuxer-lavf-o=input_format=mjpeg,framerate=30 --profile=low-latency --untimed'
fi
