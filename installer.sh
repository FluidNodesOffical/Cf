#!/bin/bash
# ----------------------------------------------------------
# 🚀 EnderCloud / FluidNodes Discord + LXD Bot Installer
# ----------------------------------------------------------
# Author: Satyam
# Description: Installs LXD, Python3, pip3, Discord.py, and dependencies.
# Adds security key verification before installation.
# ----------------------------------------------------------

set -e  # Stop script on error

# ----------------------------------------------------------
# 🔐 Installation Key Check
# ----------------------------------------------------------
INSTALL_KEY="ENDERCLOUD"  # <-- Change this to your own secret key

echo "🔑 Please enter your installation key to continue:"
read -s -p "👉 Key: " USER_KEY
echo ""

if [ "$USER_KEY" != "$INSTALL_KEY" ]; then
    echo "❌ Invalid key! Installation aborted."
    exit 1
fi

echo "✅ Key accepted! Continuing installation..."
sleep 1

# ----------------------------------------------------------
# 🧩 Start of installation
# ----------------------------------------------------------
echo "🔄 Updating system..."
sudo apt update -y && sudo apt upgrade -y

echo "📦 Installing LXD..."
sudo apt install -y lxd

echo "⚙️ Initializing LXD..."
sudo lxd init --auto

echo "🧱 Allowing firewall ports 2222–3000..."
sudo ufw allow 2222:3000/tcp

echo "🐍 Installing Python3, Pip3, and Git..."
sudo apt install -y python3 python3-pip python3-venv git

echo "💾 Upgrading pip..."
pip3 install --upgrade pip

# ----------------------------------------------------------
# 📦 Install Python packages
# ----------------------------------------------------------
PYTHON_PACKAGES=("discord.py" "aiosqlite" "requests" "python-dotenv" "docker" "colorama" "psutil" "pylxd")

echo "📚 Installing required Python packages..."
for package in "${PYTHON_PACKAGES[@]}"; do
    echo "→ Installing $package..."
    pip3 install "$package"
done

echo "🔑 Checking LXD group access..."
if ! groups $USER | grep -q '\blxd\b'; then
    echo "Adding $USER to lxd group..."
    sudo usermod -aG lxd $USER
    echo "⚠️ Please log out and log back in for group changes to apply!"
fi

echo "📁 Cloning the GitHub repo..."
if [ ! -d "Cf" ]; then
    git clone https://github.com/FluidNodesOffical/Cf.git
else
    echo "Repo already exists. Pulling latest changes..."
    cd Cf && git pull && cd ..
fi

cd Cf

# ----------------------------------------------------------
# 🔧 Ask user for bot configuration
# ----------------------------------------------------------
echo "🔧 Please enter your bot configuration details:"
read -p "👉 Discord Bot Token: " TOKEN
read -p "👉 Discord Guild ID: " GUILD_ID
read -p "👉 Discord Admin Role ID: " ADMIN_ROLE_ID

# ----------------------------------------------------------
# 🧠 Add or update configuration section in v4.py
# ----------------------------------------------------------
if grep -q "BOT_TOKEN" v4.py; then
    echo "🔄 Updating existing configuration in v4.py..."
    sed -i "s|BOT_TOKEN = .*|BOT_TOKEN = \"${TOKEN}\"|" v4.py
    sed -i "s|GUILD_ID = .*|GUILD_ID = ${GUILD_ID}|" v4.py
    sed -i "s|ADMIN_ROLE_ID = .*|ADMIN_ROLE_ID = ${ADMIN_ROLE_ID}|" v4.py
else
    echo "⚙️ Adding configuration section to v4.py..."
    sed -i "1i\
# ------------------------------------------------------\n# 🔧 CONFIGURATION SECTION\n# ------------------------------------------------------\nUSE_ENV = False\nBOT_TOKEN = \"${TOKEN}\"\nGUILD_ID = ${GUILD_ID}\nADMIN_ROLE_ID = ${ADMIN_ROLE_ID}\n" v4.py
fi

echo "✅ Installation complete!"
echo "----------------------------------------"
echo "BOT LOCATION: $(pwd)/v4.py"
echo "----------------------------------------"

# ----------------------------------------------------------
# 🚀 Ask user to start bot now
# ----------------------------------------------------------
read -p "🚀 Do you want to start the bot now? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo "Starting bot..."
    python3 v4.py
else
    echo "Bot installation finished. You can start it anytime with:"
    echo "cd Cf && python3 v4.py"
fi
