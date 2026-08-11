#!/bin/bash
# Shared implementation for project-local multi-agent runtime commands.

DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME

runtime_error() {
  printf 'FAIL: %s\n' "$*" >&2
}

runtime_require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    runtime_error "required command not found: $1"
    return 1
  fi
}

runtime_prepare() {
  config_source="$MULTI_AGENT_HOME/hcom/config.toml"
  config_link="$HCOM_DIR/config.toml"

  if [ ! -f "$config_source" ]; then
    runtime_error "global hcom configuration is missing: $config_source"
    return 1
  fi

  if [ ! -d "$HCOM_DIR" ]; then
    if ! mkdir -p "$HCOM_DIR"; then
      runtime_error "could not create project runtime: $HCOM_DIR"
      return 1
    fi
  fi

  if [ -L "$config_link" ]; then
    current_target=$(readlink "$config_link" 2>/dev/null || printf '')
    if [ "$current_target" = "$config_source" ]; then
      return 0
    fi
    runtime_error "refusing non-managed config symlink: $config_link -> $current_target"
    return 1
  fi

  if [ -e "$config_link" ]; then
    runtime_error "refusing non-managed config conflict: $config_link"
    return 1
  fi

  if ! ln -s "$config_source" "$config_link"; then
    runtime_error "could not link project config: $config_link"
    return 1
  fi
}

runtime_role_is_known() {
  case "$1" in
    lead|craft|audit|build|debug|scout|trace|ideas) return 0 ;;
    *) return 1 ;;
  esac
}

runtime_role_provider() {
  case "$1" in
    craft|audit) printf '%s\n' claude ;;
    build|debug) printf '%s\n' codex ;;
    scout|trace|ideas) printf '%s\n' agy ;;
    *) return 1 ;;
  esac
}

runtime_role_prompt() {
  case "$1" in
    craft|audit) printf '%s/claude/roles/%s.md\n' "$MULTI_AGENT_HOME" "$1" ;;
    build|debug) printf '%s/codex/roles/%s.md\n' "$MULTI_AGENT_HOME" "$1" ;;
    scout|trace|ideas) printf '%s/antigravity/roles/%s.md\n' "$MULTI_AGENT_HOME" "$1" ;;
    *) return 1 ;;
  esac
}
