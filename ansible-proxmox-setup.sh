#!/bin/bash
# ansible-proxmox-setup.sh
# Automate modern Ansible & Proxmox cloud-init environment for Debian 12+

set -e

# Colors for status messages
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}[1/8] Updating system packages...${NC}"
apt update

echo -e "${GREEN}[2/8] Installing Python3, pip, venv, and git...${NC}"
apt install -y python3 python3-pip python3-venv git

VENV_DIR="/opt/ansible-venv"

echo -e "${GREEN}[3/8] Setting up Python virtual environment at $VENV_DIR...${NC}"
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

echo -e "${GREEN}[4/8] Upgrading pip...${NC}"
pip install --upgrade pip

echo -e "${GREEN}[5/8] Installing/upgrading latest Ansible...${NC}"
pip install --upgrade ansible

echo -e "${GREEN}[6/8] Installing required Python library for Proxmox integration (proxmoxer)...${NC}"
pip install --upgrade proxmoxer

echo -e "${GREEN}[7/8] Installing/upgrading Proxmox/general Ansible collections...${NC}"
ansible-galaxy collection install community.general --upgrade
ansible-galaxy collection install community.proxmox --upgrade

# Optionally, write the venv activate path to a helper file for user reference
echo "source $VENV_DIR/bin/activate" > activate-ansible-venv.sh
chmod +x activate-ansible-venv.sh

echo -e "${GREEN}[8/8] Installation complete. Ansible and modules for Proxmox/cloud-init are ready!${NC}"
echo -e "To use Ansible in the future, just run: ${GREEN}source $VENV_DIR/bin/activate${NC}"
echo
echo "Test it by running:"
echo "  ansible --version"
echo "  ansible-doc community.general.proxmox_cloud_init"
