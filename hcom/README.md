# hcom module

hcom's **home** lives at `$HCOM_DIR` (`~/config/hcom`), not in this repo, and not at `~/.hcom`.

## Tracked here (safe to commit)

- `env` — env vars hcom passes to every launched agent. This is what makes the
  `~/config/{claude,codex,gemini}` symlinks take effect. Symlinked to `$HCOM_DIR/env`.
- `config.defaults.sh` — idempotent application of non-secret `hcom config` settings.
- `scripts/` — optional custom hcom workflow scripts.

## Generated, NEVER tracked

`$HCOM_DIR/config.toml`, the SQLite DB, hooks and logs. **`config.toml` can contain a
relay PSK**, which is equivalent to shell access on every enrolled device — it must never
be symlinked into this repo or committed. `.gitignore` guards against it. Do not enable
`hcom relay` unless you have read its security model.

## Re-apply

```sh
bash multiagent/bin/install.sh      # links env + runs config.defaults.sh
bash hcom/config.defaults.sh        # settings only
```
