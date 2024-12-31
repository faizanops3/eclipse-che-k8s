#!/bin/bash

# Update the package list
sudo apt-get update

# Install prerequisite packages
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Create the directory for Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings

# Download Docker's GPG key and store it securely
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker's official APT repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package list to include Docker's repository
sudo apt-get update

# Install Docker components
# sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get install -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin

# Log out and log back in for the group change to take effect.
# sudo usermod -aG docker $USER

# without log off 
sudo chown $USER /var/run/docker.sock

# Verify Docker installation
docker --version
containerd --version
