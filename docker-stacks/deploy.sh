#!/bin/bash

# Function to install Docker and Docker Compose
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Installing Docker..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        sudo usermod -aG docker $USER
        echo "Docker installed successfully."
    else
        echo "Docker is already installed."
    fi

    if ! command -v docker compose &> /dev/null; then
        echo "Docker Compose not found. Installing Docker Compose..."
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        echo "Docker Compose installed successfully."
    else
        echo "Docker Compose is already installed."
    fi
}

# Function to deploy a specific service
deploy_service() {
    local service=$1
    echo "Deploying $service..."
    cd $service
    
if [ "$service" = "nginx" ]; then
    if [ ! -f .env ]; then
        echo "Cloudflare API token not found for nginx. Please enter your Cloudflare API token:"
        read -p "Cloudflare API Token: " cf_token
        echo "CF_Token=$cf_token" > .env
    fi
    docker compose -f compose.yml --env-file .env up --build -d
else
    docker compose -f compose.yml up --build -d
fi
    
    cd ..
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit
fi

# Install Docker and Docker Compose
install_docker

# Ensure the script can be run after adding the user to the docker group
exec su -l $SUDO_USER <<EOF

# Pull the latest changes
cd $(pwd)
git pull

# Deploy specified services or all if none specified
if [ $# -eq 0 ]; then
    for dir in */; do
        if [ -f "$dir/compose.yml" ]; then
            deploy_service "${dir%/}"
        fi
    done
else
    for service in "$@"; do
        if [ -d "$service" ] && [ -f "$service/compose.yml" ]; then
            deploy_service "$service"
        else
            echo "Service $service not found or missing compose.yml"
        fi
    done
fi

echo "Deployment completed!"
EOF