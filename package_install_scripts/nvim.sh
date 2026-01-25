#!/usr/bin/env bash
set -e

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) NVIM_ARCH="nvim-linux64" ;;
        aarch64) NVIM_ARCH="nvim-linux-arm64" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"

    curl -LO "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ARCH}.tar.gz"
    tar xzf "${NVIM_ARCH}.tar.gz"
    sudo mv "${NVIM_ARCH}" /opt/nvim
    sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

    cd /
    rm -rf "$TMP_DIR"

elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not installed"
        exit 1
    fi
    brew install neovim
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

nvim --version

