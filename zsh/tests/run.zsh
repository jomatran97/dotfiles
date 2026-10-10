#!/bin/zsh
emulate -LR zsh
setopt errexit nounset pipefail

readonly ROOT=${0:A:h:h}
typeset -gi checks=0

fail() {
  print -u2 -r -- "not ok - $*"
  exit 1
}

pass() {
  (( ++checks ))
  print -r -- "ok $checks - $*"
}

assert_eq() {
  [[ $1 == $2 ]] || fail "$3 (expected ${(qqq)2}, got ${(qqq)1})"
}

assert_contains() {
  [[ $1 == *$2* ]] || fail "$3 (missing ${(qqq)2})"
}

readonly SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/zsh-config-tests.XXXXXX")
trap 'rm -rf -- "$SANDBOX"' EXIT INT TERM

for file in "$ROOT"/core/* "$ROOT"/custom/*.zsh "$ROOT"/zshrc "$ROOT"/tests/*.zsh; do
  /bin/zsh -n "$file" || fail "syntax: $file"
done
pass 'zsh syntax'

line_count=$(wc -l < "$ROOT/zshrc" | tr -d ' ')
(( line_count <= 80 )) || fail "zshrc has $line_count lines (maximum 80)"
zshrc=$(<"$ROOT/zshrc")
assert_contains "$zshrc" 'plugins=(' 'static plugin list'
for removed in '_zsh_find_plugin' '_zsh_add_plugin' '_ZSH_ENABLED_PLUGINS' 'compinit -d' '/opt/homebrew/opt/fzf' 'integration_dirs' 'zsh-autosuggestions' 'ZSH_AUTOSUGGEST_'; do
  [[ $zshrc != *$removed* ]] || fail "removed orchestration remains: $removed"
done
fzf_module_line=$(grep -n 'custom/fzf.zsh' "$ROOT/zshrc" | cut -d: -f1)
omz_line=$(grep -n 'source "$ZSH/oh-my-zsh.sh"' "$ROOT/zshrc" | cut -d: -f1)
alias_line=$(grep -n 'custom/aliases.zsh' "$ROOT/zshrc" | cut -d: -f1)
restore_line=$(grep -n "bindkey '\^F' _fzf_file_no_hidden" "$ROOT/zshrc" | cut -d: -f1)
(( fzf_module_line < omz_line && omz_line < alias_line && omz_line < restore_line )) || fail 'custom source ordering around OMZ'
pass 'minimal static architecture and source ordering'

home="$SANDBOX/home"
omz="$home/.oh-my-zsh"
bin="$SANDBOX/bin"
mkdir -p "$home/.config" "$omz" "$bin"
ln -s "$ROOT" "$home/.config/zsh"
ln -s "$ROOT/core/zshenv" "$home/.zshenv"
ln -s "$ROOT/core/zprofile" "$home/.zprofile"
ln -s "$ROOT/zshrc" "$home/.zshrc"

cat > "$omz/oh-my-zsh.sh" <<'OMZ'
print -r -- "${(j: :)plugins}" > "$TEST_PLUGIN_LIST"
print -r -- "$ZSH_COMPDUMP" > "$TEST_COMPDUMP_PATH"
print -r -- omz >> "$TEST_ORDER"
print -r -- compinit >> "$TEST_COMP_COUNT"
eval "$(thefuck --alias)"
omz_ctrl_f() { :; }
zle -N omz_ctrl_f
bindkey '^F' omz_ctrl_f
OMZ

cat > "$bin/fzf" <<'EOF'
#!/bin/sh
if [ "${1-}" = --zsh ]; then
  printf '%s\n' call >> "$TEST_FZF_COUNT"
  printf '%s\n' 'print -r -- fzf >> "$TEST_ORDER"'
fi
EOF
cat > "$bin/starship" <<'EOF'
#!/bin/sh
if [ "${1-}" = init ] && [ "${2-}" = zsh ]; then
  printf '%s\n' call >> "$TEST_STARSHIP_COUNT"
  printf '%s\n' 'print -r -- starship >> "$TEST_ORDER"'
fi
EOF
cat > "$bin/zoxide" <<'EOF'
#!/bin/sh
if [ "${1-}" = init ] && [ "${2-}" = zsh ]; then
  printf '%s\n' call >> "$TEST_ZOXIDE_COUNT"
  printf '%s\n' 'print -r -- zoxide >> "$TEST_ORDER"'
fi
EOF
cat > "$bin/thefuck" <<'EOF'
#!/bin/sh
printf '%s\n' call >> "$TEST_TF_COUNT"
printf '%s\n' "alias fuck='print corrected'"
EOF
chmod +x "$bin/fzf" "$bin/starship" "$bin/zoxide" "$bin/thefuck"

export TEST_PLUGIN_LIST="$SANDBOX/plugins"
export TEST_COMPDUMP_PATH="$SANDBOX/compdump"
export TEST_ORDER="$SANDBOX/order"
export TEST_COMP_COUNT="$SANDBOX/comp-count"
export TEST_FZF_COUNT="$SANDBOX/fzf-count"
export TEST_STARSHIP_COUNT="$SANDBOX/starship-count"
export TEST_ZOXIDE_COUNT="$SANDBOX/zoxide-count"
export TEST_TF_COUNT="$SANDBOX/tf-count"

startup_out="$SANDBOX/startup.out"
startup_err="$SANDBOX/startup.err"
env -i HOME="$home" PATH="$bin:/usr/bin:/bin" TERM=dumb ZSH="$omz" \
  TEST_PLUGIN_LIST="$TEST_PLUGIN_LIST" TEST_COMPDUMP_PATH="$TEST_COMPDUMP_PATH" \
  TEST_ORDER="$TEST_ORDER" TEST_COMP_COUNT="$TEST_COMP_COUNT" \
  TEST_FZF_COUNT="$TEST_FZF_COUNT" TEST_STARSHIP_COUNT="$TEST_STARSHIP_COUNT" TEST_ZOXIDE_COUNT="$TEST_ZOXIDE_COUNT" TEST_TF_COUNT="$TEST_TF_COUNT" \
  /bin/zsh -dfic 'source "$1"; source "$2"; eval fk; print -r -- "$XDG_CONFIG_HOME|$XDG_CACHE_HOME|$XDG_STATE_HOME|$HISTFILE|$STARSHIP_CONFIG|$ZSH_COMPDUMP"; print -r -- "${options[appendhistory]}|${options[sharehistory]}|${options[autocd]}"; bindkey "^F"' \
  zsh "$ROOT/core/zshenv" "$ROOT/zshrc" > "$startup_out" 2> "$startup_err" || fail 'hermetic OMZ startup returned nonzero'
[[ ! -s "$startup_err" ]] || fail "hermetic OMZ startup wrote stderr: $(<"$startup_err")"

expected_plugins='command-not-found dotenv docker gitignore colorize thefuck tldr tmux fast-syntax-highlighting'
plugin_list=$(cat -- "$TEST_PLUGIN_LIST")
assert_eq "$plugin_list" "$expected_plugins" 'static plugin list and order'
[[ $plugin_list == *' fast-syntax-highlighting' ]] || fail 'fast-syntax-highlighting must be the last plugin'
[[ $plugin_list != *'zsh-autosuggestions'* ]] || fail 'zsh-autosuggestions must stay disabled'
[[ $plugin_list != *' fzf '* && $plugin_list != fzf* && $plugin_list != *' fzf' ]] || fail 'OMZ fzf plugin must stay disabled'
assert_eq "$(wc -l < "$TEST_FZF_COUNT" | tr -d ' ')" 1 'fzf initialization count'
assert_eq "$(wc -l < "$TEST_STARSHIP_COUNT" | tr -d ' ')" 1 'Starship initialization count'
assert_eq "$(wc -l < "$TEST_ZOXIDE_COUNT" | tr -d ' ')" 1 'zoxide initialization count'
assert_eq "$(wc -l < "$TEST_TF_COUNT" | tr -d ' ')" 1 'TheFuck generation count'
assert_eq "$(wc -l < "$TEST_COMP_COUNT" | tr -d ' ')" 1 'OMZ completion ownership'
assert_eq "$(cat -- "$TEST_ORDER")" $'fzf\nomz\nzoxide\nstarship' 'initializer order'
startup_value=$(cat -- "$startup_out")
assert_contains "$startup_value" corrected 'fk reuses initialized TheFuck alias'
assert_contains "$startup_value" "$home/.config|$home/.cache|$home/.local/state|$home/.local/state/zsh/history|$home/.config/starship/starship.toml|$home/.cache/zsh/zcompdump-$ZSH_VERSION" 'portable XDG paths'
assert_contains "$startup_value" 'on|on|on' 'shell and history options'
assert_contains "$startup_value" '_fzf_file_no_hidden' 'Ctrl-F restored after OMZ'
[[ -d "$home/.cache/zsh" && -d "$home/.local/state/zsh" ]] || fail 'history/cache directories missing'
assert_eq "$(stat -f '%Lp' "$home/.cache/zsh" 2>/dev/null || stat -c '%a' "$home/.cache/zsh")" 700 'cache directory mode'
assert_eq "$(stat -f '%Lp' "$home/.local/state/zsh" 2>/dev/null || stat -c '%a' "$home/.local/state/zsh")" 700 'state directory mode'
pass 'clean hermetic OMZ startup and persistent XDG state'

caller_dump="$SANDBOX/caller-zcompdump"
caller_err="$SANDBOX/caller-compdump.err"
caller_out=$(env -i HOME="$home" PATH="$bin:/usr/bin:/bin" TERM=dumb ZSH="$omz" CALLER_DUMP="$caller_dump" \
  TEST_PLUGIN_LIST="$TEST_PLUGIN_LIST" TEST_COMPDUMP_PATH="$TEST_COMPDUMP_PATH" TEST_ORDER="$TEST_ORDER" \
  TEST_COMP_COUNT="$TEST_COMP_COUNT" TEST_FZF_COUNT="$TEST_FZF_COUNT" TEST_STARSHIP_COUNT="$TEST_STARSHIP_COUNT" TEST_ZOXIDE_COUNT="$TEST_ZOXIDE_COUNT" TEST_TF_COUNT="$TEST_TF_COUNT" \
  /bin/zsh -dfc 'source "$1"; typeset -gr ZSH_COMPDUMP="$CALLER_DUMP"; source "$2"; print -r -- "$ZSH_COMPDUMP"' \
  zsh "$ROOT/core/zshenv" "$ROOT/zshrc" 2>"$caller_err") || fail 'caller compdump startup failed'
assert_eq "$caller_out" "$caller_dump" 'readonly caller-provided ZSH_COMPDUMP'
[[ ! -s "$caller_err" ]] || fail "caller compdump emitted diagnostics: $(<"$caller_err")"
pass 'caller-preserving completion dump ownership'

cat > "$bin/fzf" <<'EOF'
#!/bin/sh
if [ "${1-}" = --zsh ]; then
  printf '%s\n' ':'
else
  printf '%s\0' "$FZF_TEST_SELECTION"
fi
EOF
chmod +x "$bin/fzf"
for selected in 'space name' "single'quote" 'glob*[x]?' '$(touch nope)' $'line\nbreak' '-danger'; do
  escaped=$(FZF_TEST_SELECTION="$selected" env ROOT="$ROOT" PATH="$bin:/usr/bin:/bin" /bin/zsh -d -c '
    source "$ROOT/custom/fzf.zsh"
    LBUFFER="prefix "
    _fzf_file_no_hidden
    print -r -- "$LBUFFER"
  ')
  normalized=$selected
  [[ $normalized == -* ]] && normalized="./$normalized"
  expected=$(SELECTED="$normalized" /bin/zsh -d -c 'print -r -- "prefix ${(q)SELECTED} "')
  assert_eq "$escaped" "$expected" "fzf escaping for ${(qqq)selected}"
done
! grep -q 'eval' "$ROOT/custom/fzf.zsh" || fail 'custom/fzf.zsh uses eval'
pass 'FZF NUL handling, shell escaping, and leading-dash safety'

alias_out=$(env -i HOME="$home" PATH=/usr/bin:/bin /bin/zsh -d -c '
  source "$1"
  print -r -- "${aliases[ll]-}|${aliases[la]-}|${aliases[cat]-}|${aliases[grep]-}|${aliases[diff]-}"
' zsh "$ROOT/custom/aliases.zsh")
diff_alias=''
command diff --color=auto /dev/null /dev/null >/dev/null 2>&1 && diff_alias='diff --color=auto'
assert_eq "$alias_out" "ls -lh|ls -lah|||$diff_alias" 'portable native alias fallbacks'
pass 'portable aliases'

zmodload zsh/datetime
start=$EPOCHREALTIME
for _ in {1..5}; do
  env -i HOME="$home" PATH="$bin:/usr/bin:/bin" TERM=dumb ZSH="$omz" ZSH_DISABLE_HOMEBREW=1 \
    TEST_PLUGIN_LIST="$TEST_PLUGIN_LIST" TEST_COMPDUMP_PATH="$TEST_COMPDUMP_PATH" TEST_ORDER="$TEST_ORDER" \
    TEST_COMP_COUNT="$TEST_COMP_COUNT" TEST_FZF_COUNT="$TEST_FZF_COUNT" TEST_STARSHIP_COUNT="$TEST_STARSHIP_COUNT" TEST_ZOXIDE_COUNT="$TEST_ZOXIDE_COUNT" TEST_TF_COUNT="$TEST_TF_COUNT" \
    /bin/zsh -dlic exit >/dev/null 2>"$SANDBOX/timing.err" || fail 'timed startup failed'
done
elapsed=$(( EPOCHREALTIME - start ))
(( elapsed < 10.0 )) || fail "five hermetic startups took ${elapsed}s"
[[ ! -s "$SANDBOX/timing.err" ]] || fail "timed startup emitted diagnostics: $(<"$SANDBOX/timing.err")"
pass "startup guard (${elapsed}s for five runs)"

print -r -- "1..$checks"
