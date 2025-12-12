#!/usr/bin/env bash
set -euo pipefail

# 1) Detect distro and package manager
detect_distro() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "ubuntu"
    elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
    else
        echo "Unsupported distro. Need apt or pacman." >&2
        exit 1
    fi
}

DISTRO="$(detect_distro)"

# 2) Update packages
if [[ "$DISTRO" == "ubuntu" ]]; then
    sudo apt-get update
    sudo apt-get upgrade -y
elif [[ "$DISTRO" == "arch" ]]; then
    sudo pacman -Syu --noconfirm
fi

# 3) Install essentials and dev tools: git, zsh, curl, neovim, lazygit, fzf, ripgrep, tree-sitter, gcc, node.js, pandoc
PKGS_COMMON="git zsh curl neovim lazygit fzf ripgrep tree-sitter-cli gcc nodejs pandoc"
if [[ "$DISTRO" == "ubuntu" ]]; then
  for pkg in $PKGS_COMMON; do
    if ! sudo apt-get install -y "$pkg"; then
      echo "Package $pkg not available in Ubuntu repos. Install it manually, then rerun."
      exit 1
    fi
  done
elif [[ "$DISTRO" == "arch" ]]; then
  for pkg in $PKGS_COMMON; do
    if ! sudo pacman -S --noconfirm "$pkg"; then
      echo "Package $pkg not available in Arch repos. Install it manually, then rerun."
      exit 1
    fi
  done
fi

# 4) Set zsh as default shell
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    chsh -s "$(command -v zsh)"
fi

# 5) Install oh-my-zsh (non-interactive)
export RUNZSH=no
export CHSH=no
if [[ ! -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 6) Install zsh plugins: autosuggestions + syntax highlighting
ZSH_CUSTOM="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# 7) Ensure plugins are enabled in .zshrc
ZSHRC="$HOME/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
    cp "${ZSH:-$HOME/.oh-my-zsh}/templates/zshrc.zsh-template" "$ZSHRC"
fi
if ! grep -q "plugins=(.*zsh-autosuggestions.*zsh-syntax-highlighting" "$ZSHRC"; then
    sed -i.bak -E 's/^plugins=\(.*\)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC"
fi

# 8) Add NoteOnGithub/bin to PATH
if ! grep -q "NoteOnGithub/bin" "$ZSHRC"; then
  {
    echo ""
    echo "# Add NoteOnGithub/bin to PATH"
    echo 'export PATH="$HOME/NoteOnGithub/bin:$PATH"'
  } >> "$ZSHRC"
fi

# 9) Generate SSH key (ed25519) and display public key
SSH_KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
if [[ ! -f "$SSH_KEY" ]]; then
    ssh-keygen -t ed25519 -C "$USER@$(hostname)" -f "$SSH_KEY" -N ""
fi

echo "----- Public key below: add it to GitHub before continuing -----"
cat "${SSH_KEY}.pub"
echo "----------------------------------------------------------------"
read -rp "Added to GitHub? Type 'yes' to continue: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Exiting until key is added."
    exit 1
fi

# 10) Configure git user/email
git config --global user.name "$USER"
git config --global user.email "$USER@$(hostname)"

# 11) Clone repositories into home
cd "$HOME"
for repo in git@github.com:xingyuXXX/NoteOnGithub.git git@github.com:xingyuXXX/XingJsdelivr.git git@github.com:xingyuXXX/XingPage.git; do
  dir="$(basename "$repo" .git)"
  if [[ -d "$dir/.git" ]]; then
    echo "Repo $dir already exists, skipping."
  else
    git clone "$repo"
  fi
done

# 12) Symlink Neovim config into ~/.config
NVIM_SRC="$HOME/NoteOnGithub/MyConfigs/nvim"
NVIM_DEST="$HOME/.config/nvim"
if [[ -d "$NVIM_SRC" ]]; then
  mkdir -p "$HOME/.config"
  rm -rf "$NVIM_DEST"
  ln -s "$NVIM_SRC" "$NVIM_DEST"
else
  echo "Neovim config source $NVIM_SRC not found; ensure NoteOnGithub is cloned."
fi

echo "All done. Please restart your shell (or log out/in) to start using zsh."
