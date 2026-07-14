# Powerful but minimal zsh configuration
# Author: Radley E. Sidwell-Lewis
# GitHub: https://www.github.com/radleylewis/zsh
#
# Uses:
#   Plugins:      fast-syntax-highlighting, zsh-autosuggestions,
#                 zsh-history-substring-search, zsh-vi-mode
#   Prompt:       starship
#   Navigation:   zoxide, fzf, fd
#   History:      atuin
#   Tooling:      mise
#   CLI tools:    eza, bat, nvim, ripgrep

# =========================================================
# History
# =========================================================

HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# =========================================================
# Shell behaviour
# =========================================================

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT

# =========================================================
# Smart directory navigation & lf
# =========================================================

if [[ -f ~/.config/lf/icons ]]; then
  LF_ICONS=$(tr '\n' ':' < ~/.config/lf/icons)
  export LF_ICONS
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# =========================================================
# Completion
# =========================================================

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# =========================================================
# Fuzzy finder
# =========================================================

for fzf_dir in \
  /opt/homebrew/opt/fzf/shell \
  /usr/local/opt/fzf/shell \
  /usr/share/fzf \
  /usr/share/doc/fzf/examples
do
  if [[ -f "$fzf_dir/key-bindings.zsh" && -f "$fzf_dir/completion.zsh" ]]; then
    source "$fzf_dir/key-bindings.zsh"
    source "$fzf_dir/completion.zsh"
    break
  fi
done

# =========================================================
# Modular Config Files
# =========================================================

for config_file in \
  "$ZDOTDIR/fzf.zsh" \
  "$ZDOTDIR/aliases.zsh" \
  "$ZDOTDIR/bindings.zsh" \
  "$ZDOTDIR/plugins.zsh"
do
  if [[ -r "$config_file" ]]; then
    source "$config_file"
  else
    echo "WARNING: missing zsh config file: $config_file" >&2
  fi
done

# =========================================================
# Shell history UI
# =========================================================

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

# =========================================================
# Command correction
# =========================================================

if command -v thefuck >/dev/null 2>&1; then
  eval "$(thefuck --alias)"
fi

# =========================================================
# Prompt
# =========================================================

if [[ -r "$ZDOTDIR/prompt.zsh" ]]; then
  source "$ZDOTDIR/prompt.zsh"
else
  echo "WARNING: missing zsh config file: $ZDOTDIR/prompt.zsh" >&2
fi
