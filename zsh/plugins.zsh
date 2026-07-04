# =========================================================
# Plugins
# =========================================================

ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"
typeset -a ZPLUGIN_REPOS=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-history-substring-search
  jeffreytse/zsh-vi-mode
  zdharma-continuum/fast-syntax-highlighting
)

_zplugin_clone() {
  local owner="$1"
  local repo="$2"
  local plugin_path="${ZPLUGINDIR}/${repo}"

  mkdir -p "$ZPLUGINDIR"
  if [[ -d "$plugin_path" ]]; then
    return 0
  fi

  echo "Installing ${repo}..."
  git clone --depth=1 "https://github.com/${owner}/${repo}" "$plugin_path" \
    || { echo "ERROR: failed to install ${repo}" >&2; return 1; }
}

zplugin-install() {
  local spec owner repo
  for spec in "${ZPLUGIN_REPOS[@]}"; do
    owner="${spec%%/*}"
    repo="${spec#*/}"
    _zplugin_clone "$owner" "$repo" || return 1
  done
}

_zplugin_load() {
  local plugin_path="${ZPLUGINDIR}/${2}"
  if [[ ! -d "$plugin_path" ]]; then
    echo "WARNING: plugin ${2} is missing at ${plugin_path}; run zplugin-install to install it" >&2
    return 0
  fi
  if [[ -r "${plugin_path}/${2}.plugin.zsh" ]]; then
    source "${plugin_path}/${2}.plugin.zsh"
  else
    echo "WARNING: ${2}.plugin.zsh not found in ${plugin_path}" >&2
  fi
}

zplugin-update() {
  local dir
  for dir in "${ZPLUGINDIR}"/*/(N); do
    echo "Updating ${dir:t}..."
    git -C "$dir" pull --ff-only
  done
}

for spec in "${ZPLUGIN_REPOS[@]}"; do
  owner="${spec%%/*}"
  repo="${spec#*/}"
  _zplugin_load "$owner" "$repo"
done
