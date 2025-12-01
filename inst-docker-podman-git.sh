#!/bin/bash

# This script sets up initial development tools for a Debian Bookworm VM.
# Make sure you run as root.
# Command to run: 
# curl https://raw.githubusercontent.com/JungleJM/proxmox-iac/refs/heads/main/inst-docker-podman-git.sh | bash

set -e

echo "Updating system packages..."
apt update -y
apt upgrade -y

echo "Installing dependencies and git..."
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release git

# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "Installing Docker and docker-compose..."
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Installing Podman and podman-compose..."
apt install -y podman podman-compose

echo "Setup complete. Docker, Docker Compose, Podman, Podman Compose, and Git are ready to use!"

echo
timeout=60

while [ "$timeout" -gt 0 ]; do
    printf "\rInstall Dockge? (y/n) [%02ds left]: " "$timeout"
    # -t timeout in seconds, -n 1 reads a single character
    if read -t 1 -n 1 answer; then
        echo    # move to new line after keypress
        case "$answer" in
            [yY])
                echo "Installing Dockge..."
                curl -fsSL https://raw.githubusercontent.com/JungleJM/proxmox-iac/refs/heads/main/inst_dockge.sh | sudo bash
                break
                ;;
            [nN])
                echo "Skipping Dockge install."
                break
                ;;
            *)
                echo "Invalid choice, please press y or n."
                ;;
        esac
    fi
    timeout=$((timeout - 1))
done

if [ "$timeout" -eq 0 ]; then
    echo    # ensure newline after countdown
    echo "No input received within 60 seconds. Skipping Dockge install."
fi

