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
- SSH commit signing is enabled against `~/.ssh/ryan_parker.pub`. If that key path differs on another machine, update `user.signingkey` in [`config`](./config).
- For GitHub verification, add the same public key as a **signing key** in GitHub if you have only registered it for SSH auth so far.
