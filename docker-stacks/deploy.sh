#!/bin/bash

# Function to install Docker and Docker Compose
install_docker() {
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        echo "Docker or Docker Compose not found. Installing Docker and Docker Compose..."
        apt update && \
        apt install sudo -y && \
        apt-get install -y ca-certificates curl && \
        install -m 0755 -d /etc/apt/keyrings && \
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
        chmod a+r /etc/apt/keyrings/docker.asc && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
        apt-get update && \
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        echo "Docker and Docker Compose installed successfully."
    else
        echo "Docker and Docker Compose are already installed."
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