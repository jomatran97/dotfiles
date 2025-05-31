#!/bin/bash
#  This script is used to install and configure various tools and applications on a macOS system.
brew bundle --file=~/.config/brewapp/Brewfile
#git clone git@github.com:jomatran97/dotfiles.git /Users/haitran/Documents/code_base/personal/codefun/
#ln -s /Users/haitran/Documents/code_base/personal/codefun/Dotfiles ~/.config

# Install and config oh-my-zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
rm -rf ~/.zshrc
ln -s ~/.config/zsh/zshrc ~/.zshrc
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'>> ~/.zprofile

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
# Install and config tmux
rm -rf ~/.tumux.conf
ln -s ~/.config/tmux/tmux.conf ~/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


#  set up git config
ln -s ~/.config/git-config/gitconfig ~/.gitconfig

# Install and config fzf
git clone https://github.com/junegunn/fzf-git.sh.git ~/fzf-git.sh
