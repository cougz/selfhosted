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
    
    # Create directories if they don't exist
    sudo mkdir -p /var/docker/data/$service
    sudo mkdir -p /var/docker/stacks/$service
    sudo mkdir -p /var/docker/data/$service/ssl
    
    echo "Current directory: $(pwd)"
    ls -la
    
    if [ -d "docker-stacks/$service" ]; then
        echo "Contents of docker-stacks/$service directory:"
        ls -la "docker-stacks/$service"
        
        if [ -f "docker-stacks/$service/compose.yml" ]; then
            # Copy compose file to the new location
            sudo cp "docker-stacks/$service/compose.yml" "/var/docker/stacks/$service/compose.yml"
            echo "Copied compose.yml to /var/docker/stacks/$service/"
            
            # Copy Dockerfile if it exists
            if [ -f "docker-stacks/$service/Dockerfile" ]; then
                sudo cp "docker-stacks/$service/Dockerfile" "/var/docker/stacks/$service/Dockerfile"
                echo "Copied Dockerfile to /var/docker/stacks/$service/"
            else
                echo "Warning: Dockerfile not found in docker-stacks/$service directory."
            fi
            
            # Copy start.sh if it exists
            if [ -f "docker-stacks/$service/start.sh" ]; then
                sudo cp "docker-stacks/$service/start.sh" "/var/docker/stacks/$service/start.sh"
                echo "Copied start.sh to /var/docker/stacks/$service/"
            else
                echo "Warning: start.sh not found in docker-stacks/$service directory."
            fi
            
            cd "/var/docker/stacks/$service"
            
            # Service-specific configurations
            if [ "$service" = "nginx" ]; then
                configure_nginx
            elif [ "$service" = "authentik" ]; then
                configure_authentik
            else
                echo "No specific configuration for $service. Proceeding with default deployment."
            fi
            
            echo "Running docker compose for $service"
            if docker compose -f compose.yml up --build -d; then
                echo "$service deployed successfully."
            else
                echo "Error deploying $service. Check the compose.yml and Dockerfile (if needed)."
                echo "Contents of /var/docker/stacks/$service:"
                ls -la
                echo "Contents of compose.yml:"
                cat compose.yml
            fi
            cd "$OLDPWD"
        else
            echo "compose.yml not found in docker-stacks/$service directory"
        fi
    else
        echo "Service directory docker-stacks/$service not found"
    fi
}

configure_nginx() {
    # Copy nginx.conf if it doesn't exist
    if [ ! -f /var/docker/data/nginx/nginx.conf ]; then
        sudo cp "docker-stacks/nginx/nginx.conf" /var/docker/data/nginx/nginx.conf
    fi
    
    # Copy ssl_params.conf to the ssl folder
    sudo cp "docker-stacks/nginx/ssl_params.conf" /var/docker/data/nginx/ssl/ssl_params.conf
    echo "Copied ssl_params.conf to /var/docker/data/nginx/ssl/"

    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        echo "Enter Cloudflare API token:"
        read -p "CF_Token: " cf_token
        echo "CF_Token=$cf_token" > .env
        echo "Enter your domain for acme.sh certificate creation:"
        read -p "DOMAIN: " domain
        echo "DOMAIN=$domain" >> .env
    fi
}

configure_authentik() {
    # This function is a placeholder for future authentik configuration
    echo "Authentik configuration placeholder"
    # You can add specific authentik configuration here when needed
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
    for dir in docker-stacks/*/; do
        service=$(basename "$dir")
        if [ -f "docker-stacks/$service/compose.yml" ]; then
            deploy_service "$service"
        else
            echo "No compose.yml in docker-stacks/$service"
        fi
    done
else
    for service in "$@"; do
        deploy_service "$service"
    done
fi

echo "Deployment completed!"