# Initialize Homebrew when present. Guard both Apple Silicon and Intel layouts
# so login shells stay healthy on machines without brew installed yet.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Prefer Homebrew Python when a versioned formula is installed so `python3`
# resolves to a modern interpreter for tools like Mason-managed formatters.
typeset -U path PATH
for brew_python_bin in /opt/homebrew/opt/python*/libexec/bin(N) /usr/local/opt/python*/libexec/bin(N); do
  path=("$brew_python_bin" $path)
  break
done
export PATH
