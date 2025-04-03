#!/bin/bash

set -e

echo "[*] Writing /etc/wsl.conf..."
cat <<EOF | sudo tee /etc/wsl.conf > /dev/null
[network]
generateResolvConf = false
EOF

echo "[*] Removing existing /etc/resolv.conf..."
sudo rm -f /etc/resolv.conf

echo "[*] Creating new /etc/resolv.conf with Cloudflare & Google DNS..."
cat <<EOF | sudo tee /etc/resolv.conf > /dev/null
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

echo "[*] Setting permissions..."
sudo chmod 644 /etc/resolv.conf

echo ""
echo "✅ DNS fix applied inside WSL."
echo "🧠 Now run this from Windows PowerShell or CMD to finish:"
echo ""
echo "    wsl --shutdown"
echo ""
echo "Then restart your WSL terminal."
