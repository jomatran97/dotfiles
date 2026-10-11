# Cache `<tool> <init args>` output and source it; regenerate when the binary
# is newer than the cache. Usage: _zsh_cached_init <tool> [args...]
_zsh_cached_init() {
  local tool=$1 bin=$commands[$1] cache
  [[ -n $bin ]] || return 1
  cache="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}/init-${tool}.zsh"
  if [[ ! -s $cache || $bin -nt $cache ]]; then
    local out
    out=$(command "$@" 2>/dev/null) || return 1
    print -r -- "$out" >| "$cache"
    zcompile "$cache" 2>/dev/null
  fi
  source "$cache"
}

# TheFuck's alias generation spawns Python; defer it until first use.
if (( ${+commands[thefuck]} )); then
  fuck() {
    unfunction fuck
    eval "$(command thefuck --alias)"
    fuck "$@"
  }
  alias fk=fuck
fi
