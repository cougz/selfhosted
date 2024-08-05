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
        # Copy initial nginx configuration files if the target directory is empty
        if [ ! -f /docker_data/nginx/nginx.conf ]; then
            sudo cp nginx.conf /docker_data/nginx/nginx.conf
        fi
        if [ ! -d /docker_data/nginx/conf.d ] || [ -z "$(ls -A /docker_data/nginx/conf.d)" ]; then
            sudo mkdir -p /docker_data/nginx/conf.d
            sudo cp -r conf.d/* /docker_data/nginx/conf.d/ 2>/dev/null || true
        fi

        # Check if Cloudflare credentials are set for nginx
        if [ ! -f .env ]; then
            echo "Cloudflare credentials not found for nginx. Please enter your Cloudflare API key and email:"
            read -p "Cloudflare API Key: " cf_key
            read -p "Cloudflare Email: " cf_email
            echo "CF_Key=$cf_key" > .env
            echo "CF_Email=$cf_email" >> .env
        fi
        docker compose -f compose.yml --env-file .env up --build -d
    else
        # For other services, just run docker compose
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