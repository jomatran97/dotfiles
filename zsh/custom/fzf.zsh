# Commands consumed by fzf's standard Ctrl-T integration.
if (( ${+commands[fd]} )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
  export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
else
  export FZF_DEFAULT_COMMAND='find . -type f ! -path "*/.git/*" -print'
  export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
fi

export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border=rounded --prompt="  " --pointer="❯ " --preview-window=right:65%:wrap:border-left'

if (( ${+commands[bat]} )); then
  export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 -- {}'
elif (( ${+commands[batcat]} )); then
  export _FZF_PREVIEW_CMD='batcat --color=always --style=plain,numbers --line-range=:500 -- {}'
else
  export _FZF_PREVIEW_CMD='cat -- {}'
fi
export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"

# Emit NUL-delimited paths so embedded newlines are not ambiguous.
_fzf_files_no_hidden() {
  if (( ${+commands[fd]} )); then
    command fd --type f --strip-cwd-prefix --exclude .git --print0
  else
    command find . -type f ! -path '*/.*' -print0
  fi
}

_fzf_file_no_hidden() {
  (( ${+commands[fzf]} )) || return 127

  local selected
  while IFS= read -r -d $'\0' selected; do
    [[ $selected == -* ]] && selected="./$selected"
    LBUFFER+="${(q)selected} "
  done < <(_fzf_files_no_hidden | command fzf --read0 --print0 --preview "$_FZF_PREVIEW_CMD")

  [[ -o interactive ]] && zle reset-prompt
}

# ZLE is unavailable when this module is sourced by syntax/noninteractive tests.
if [[ -o interactive ]]; then
  zle -N _fzf_file_no_hidden
  bindkey '^F' _fzf_file_no_hidden
fi
