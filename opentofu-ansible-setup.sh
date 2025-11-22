#!/bin/bash
# install-opentofu-and-ansible.sh
# Installs OpenTofu and Ansible on Debian/Ubuntu systems

set -e

echo "Updating package list and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common

echo "Adding OpenTofu GPG keys..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://get.opentofu.org/opentofu.gpg | sudo tee /etc/apt/keyrings/opentofu.gpg >/dev/null
curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --no-tty --batch --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg >/dev/null
sudo chmod a+r /etc/apt/keyrings/opentofu.gpg

echo "Adding OpenTofu APT repository..."
echo \
"deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main
deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
sudo tee /etc/apt/sources.list.d/opentofu.list > /dev/null

echo "Updating package list..."
sudo apt-get update

echo "Installing OpenTofu..."
sudo apt-get install -y tofu

echo "Installing Ansible..."
sudo apt-get install -y ansible

echo "Checking OpenTofu version..."
tofu --version

echo "Checking Ansible version..."
ansible --version

echo "OpenTofu and Ansible installation complete!"
