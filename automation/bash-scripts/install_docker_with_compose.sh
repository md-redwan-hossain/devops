#!/bin/bash

# Prompt for the Ubuntu codename
read -p "Enter the Ubuntu codename (e.g., focal, jammy): " codename

# Check if codename is empty
if [[ -z "$codename" ]]; then
  echo "Codename cannot be empty. Exiting."
  exit 1
fi

# Update package lists and install prerequisites
sudo apt update
sudo apt install apt-transport-https ca-certificates curl gnupg -y

# Import Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

# Determine the system architecture
arch=$(dpkg --print-architecture)

# Add Docker repository
echo "deb [arch=$arch signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
sudo apt update

# Install Docker packages
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Add the current user to the Docker group
sudo usermod -aG docker ${USER}

echo "Docker installation and setup completed for Ubuntu $codename."
