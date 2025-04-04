#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo apt-get update

sudo apt install -y pkg-config
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
sudo apt-get install -y libssl-dev
sudo apt install -y build-essential
sudo apt install -y plocate
sudo updatedb 

openssl_dir=$(dirname $(locate openssl.pc | head -n 1))
if [ -n "$openssl_dir" ]; then
  export PKG_CONFIG_PATH=$openssl_dir
  echo "PKG_CONFIG_PATH set to $PKG_CONFIG_PATH"
else
  echo "openssl.pc not found, PKG_CONFIG_PATH not set."
fi

sudo apt install btop
sudo apt install nginx
sudo apt install certbot python3-certbot-nginx
sudo apt install neofetch
sudo apt install ncdu