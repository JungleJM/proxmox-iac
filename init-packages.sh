#!/bin/bash

# This script sets up initial development tools for an apt-based VM (e.g., Ubuntu or Debian).
# Designed for root execution. Save to GitHub and run: curl -sSfL <script-url> | bash

set -e

echo "Updating system packages..."
apt update -y
apt upgrade -y

echo "Installing dependencies and git..."
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release git

echo "Adding Docker's official GPG key and repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

echo "Installing Docker and docker-compose..."
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-compose

echo "Installing Podman and podman-compose..."
apt install -y podman podman-compose

echo "Setup complete. Docker, Docker Compose, Podman, Podman Compose, and Git are ready to use!"
