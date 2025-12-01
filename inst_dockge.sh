# create docker group if it doesn't exist
sudo groupadd docker 2>/dev/null || true

# add your user to it
sudo usermod -aG docker $USER

# restart Docker
sudo systemctl restart docker

# Create directories that store your stacks and stores Dockge's stack
sudo mkdir -p /opt/stacks /opt/dockge
cd /opt/dockge

# Download the compose.yaml
sudo curl https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml --output compose.yaml

# Start the server
docker compose up -d
