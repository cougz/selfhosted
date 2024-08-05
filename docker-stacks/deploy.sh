#!/bin/bash

install_docker() {
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        echo "Installing Docker and Docker Compose..."
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

deploy_service() {
    local service=$1
    echo "Deploying service: $service"
    echo "Current directory: $(pwd)"
    ls -la
    
    if [ -d "$service" ]; then
        echo "Contents of $service directory:"
        ls -la "$service"
        
        if [ -f "$service/compose.yml" ]; then
            cd "$service"
            
            if [ "$service" = "nginx" ]; then
                # Create necessary directories
                sudo mkdir -p /docker_data/nginx/certs /docker_data/nginx/ssl /docker_data/nginx/conf.d
                
                # Copy nginx.conf if it doesn't exist
                if [ ! -f /docker_data/nginx/nginx.conf ]; then
                    sudo cp nginx.conf /docker_data/nginx/nginx.conf
                fi
                
                # Create .env file if it doesn't exist
                if [ ! -f .env ]; then
                    echo "Enter Cloudflare API token:"
                    read -p "CF_Token: " cf_token
                    echo "CF_Token=$cf_token" > .env
                    echo "Enter your domain for acme.sh certificate creation:"
                    read -p "DOMAIN: " domain
                    echo "DOMAIN=$domain" >> .env
                fi
                fi
            
            echo "Running docker compose for $service"
            docker compose -f compose.yml up --build -d
            cd ..
        else
            echo "compose.yml not found in $service directory"
        fi
    else
        echo "Service directory $service not found"
    fi
}

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

install_docker

git pull

echo "Current directory: $(pwd)"
ls -la

if [ $# -eq 0 ]; then
    echo "No service specified, deploying all"
    for dir in */; do
        if [ -f "${dir}compose.yml" ]; then
            deploy_service "${dir%/}"
        else
            echo "No compose.yml in ${dir}"
        fi
    done
else
    for service in "$@"; do
        deploy_service "$service"
    done
fi

echo "Deployment completed!"