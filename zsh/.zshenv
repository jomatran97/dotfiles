# ~/.config/zsh/.zshenv

# ---------- XDG base directories ----------
# Centralizes config/cache/data locations
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# ---------- Editor ----------
# Default editor used by git, crontab, etc.
export EDITOR="nvim"
export VISUAL="nvim"

# ---------- Pager ----------
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="batcat -l man -p"
fi

# ---------- Starship ----------
export STARSHIP_CONFIG="$ZDOTDIR/starship.toml"

# ---------- PATH ----------
# Personal binaries/scripts. Keep ~/.atuin/bin first so the official Atuin
# installer works without extra shell glue.
export PATH="$HOME/.atuin/bin:$HOME/.local/bin:$PATH"

# Prefer Homebrew Python when a versioned formula is installed so `python3`
# resolves to a modern interpreter for tools like Mason-managed formatters.
for brew_python_bin in /opt/homebrew/opt/python*/libexec/bin(N) /usr/local/opt/python*/libexec/bin(N); do
  case ":$PATH:" in
    *":$brew_python_bin:"*) ;;
    *) export PATH="$brew_python_bin:$PATH" ;;
  esac
  break
done
