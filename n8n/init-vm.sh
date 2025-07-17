#!/bin/bash

set -e  # Terminate if there is any error

# Update system
echo "Update System"
sudo apt-get update && sudo apt-get upgrade -y

# Uninstall all conflicting packages for Docker installation
echo "Uninstall all conflicting packages for Docker installation..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Set up Docker's apt repository.
echo "Set up Docker's apt repository"
##  Add Docker's official GPG key:
echo "Add Docker's official GPG key..."
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

## Add the repository to Apt sources:
echo "Add the repository to Apt sources..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install the Docker packages
echo "Install the Docker packages"
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Create the docker group and add user"
# Create the docker group
sudo groupadd docker

# Add user to the `docker` group
sudo usermod -aG docker $USER

# Instalar Nginx y Certbot
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Habilitar servicios
sudo systemctl enable nginx

# Crear carpeta de proyecto
mkdir -p /home/azureuser/app

# Restart VM
sudo reboot

