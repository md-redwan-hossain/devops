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
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  export PATH="$HOME/.local/bin:$PATH"  # Apply to current session
fi

# Initialize McFly in Bash if not already present
INIT_CMD='eval "$(mcfly init bash)"'
if ! grep -qxF "$INIT_CMD" "$HOME/.bashrc"; then
  echo -e "\n# Initialize McFly shell history search\n$INIT_CMD" >> "$HOME/.bashrc"
fi

# Apply McFly to current session
if command -v mcfly &> /dev/null; then
  eval "$(mcfly init bash)"
fi

source ~/.bashrc
echo "✅ Installation complete!"
