# Compatibility with Alacritty, tmux and fzf. Sourced after OMZ.

# Alacritty sends ^A/^E/^U/^L and ESC b/f for Cmd/Alt shortcuts: stay on emacs keys.
bindkey -e

# tmux owns ^A as its prefix, so Cmd+Left cannot reach the line start there.
bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line
bindkey '^[[F' end-of-line '^[OF' end-of-line

# tmux consumes M-c (fzf cd) and M-. (insert-last-word); offer prefix-free keys.
if (( ${+widgets[fzf-cd-widget]} )); then
  bindkey '^G' fzf-cd-widget
fi
bindkey '^[,' insert-last-word

# Fall back to a plain compinit when OMZ is absent so completion still works.
if (( ! ${+functions[compdef]} )); then
  autoload -Uz compinit && compinit -i -d "${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump}"
fi
