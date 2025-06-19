#!/bin/bash

# Install or update lazydocker
echo "Installing/updating lazydocker..."
curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash  \
  || { echo "Failed to install lazydocker"; exit 1; }

# Install McFly
echo "Installing McFly..."
curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sh -s -- --git cantino/mcfly \
  || { echo "Failed to install McFly"; exit 1; }


# Add ~/.local/bin to PATH permanently
if ! grep -q '$HOME/.local/bin' "$HOME/.bashrc"; then
  echo "" >> "$HOME/.bashrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

# Initialize McFly in Bash if not already present
if ! grep -q "mcfly init bash" "$HOME/.bashrc"; then
  echo "" >> "$HOME/.bashrc"
  echo 'eval "$(mcfly init bash)"' >> "$HOME/.bashrc"
fi

source ~/.bashrc
echo "✅ Installation complete!"
