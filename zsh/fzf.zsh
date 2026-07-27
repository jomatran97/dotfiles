# =========================================================
# fzf
# =========================================================

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
  export FZF_FILE_NO_HIDDEN_COMMAND='fd --type f --strip-cwd-prefix --exclude .git'
else
  export FZF_DEFAULT_COMMAND='find . -type f | sed "s#^\./##"'
  export FZF_FILE_NO_HIDDEN_COMMAND='find . -type f ! -path "*/.*" | sed "s#^\./##"'
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS='
  --height=60%
  --layout=reverse
  --border=rounded
  --prompt="  "
  --pointer="  "
  --preview-window=right:65%:wrap:border-left
'

if command -v bat >/dev/null 2>&1; then
  export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 {}'
elif command -v batcat >/dev/null 2>&1; then
  export _FZF_PREVIEW_CMD='batcat --color=always --style=plain,numbers --line-range=:500 {}'
else
  export _FZF_PREVIEW_CMD='sed -n "1,500p" {}'
fi
export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"

_fzf_file_no_hidden() {
  if ! command -v fzf >/dev/null 2>&1; then
    zle -M 'fzf is not installed'
    return 1
  fi
  local cmd result
  cmd="${FZF_FILE_NO_HIDDEN_COMMAND:-$FZF_DEFAULT_COMMAND}"
  result=$(eval "$cmd" | fzf --preview "$_FZF_PREVIEW_CMD") \
    && LBUFFER+="$result"
  zle reset-prompt
}
zle -N _fzf_file_no_hidden
