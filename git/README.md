# git

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/git" ~/.config/git
```

Git reads `~/.config/git/config` automatically when `~/.gitconfig` is absent. If you already keep a `~/.gitconfig`, add this include once:

```gitconfig
[include]
    path = ~/.config/git/config
```

## Local overrides

The tracked config intentionally avoids machine-specific signing key paths. Copy the example file and edit it for your machine:

```sh
cp ~/.config/git/config.local.example ~/.config/git/config.local
```

If this repo is your source-of-truth checkout and `git/` is symlinked to `~/.config/git`, you can also copy `git/config.local.example` to `git/config.local` in the repo checkout. The repo ignores that file.

## Extras

Install the diff tools used by this config:

```sh
brew install git-delta difftastic
```

Then enable Git's background maintenance once:

```sh
git maintenance start
```

## Notes

- `delta` is the default pager for regular Git diffs.
- `difftastic` stays opt-in through aliases such as `git dft`, `git dshow`, and `git dlog`.
- `rerere` is enabled so repeated merge/rebase conflicts can reuse prior resolutions.
- SSH signing defaults stay enabled in the tracked config, but the actual `user.signingkey` now lives in `config.local` so different machines can keep different key paths without editing tracked files.
- For GitHub verification, add the same public key as a **signing key** in GitHub if you have only registered it for SSH auth so far.
