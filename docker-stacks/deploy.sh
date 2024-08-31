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
                if [ ! -d /docker_data/nginx ]; then
                    # Create necessary directories
                    sudo mkdir -p /docker_data/nginx/
                    echo "Created directory /docker_data/nginx/"
                else
                    echo "Directory /docker_data/nginx/ already exists, skipping creation."
                fi
                
                # Copy nginx.conf if it doesn't exist
                if [ ! -f /docker_data/nginx/nginx.conf ]; then
                    sudo cp nginx.conf /docker_data/nginx/nginx.conf
                fi
                
                # Copy ssl_params.conf if it doesn't exist
                if [ ! -f /docker_data/nginx/ssl/ssl_params.conf ]; then
                    sudo cp ssl_params.conf /docker_data/nginx/ssl_params.conf
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
            elif [ "$service" = "authentik" ]; then
                if [ ! -d /docker_data/authentik ]; then
                    # Create necessary directories
                    sudo mkdir -p /docker_data/authentik/{database,redis,media,custom-templates,certs}
                    echo "Created directories for Authentik in /docker_data/authentik/"
                else
                    echo "Directory /docker_data/authentik/ already exists, skipping creation."
                fi

                # Create .env file if it doesn't exist
                if [ ! -f .env ]; then
                    echo "Enter the following details for Authentik:"
                    read -p "PostgreSQL password: " pg_pass
                    read -p "PostgreSQL user (default: authentik): " pg_user
                    pg_user=${pg_user:-authentik}
                    read -p "PostgreSQL database (default: authentik): " pg_db
                    pg_db=${pg_db:-authentik}
                    read -p "Authentik image (default: ghcr.io/goauthentik/server): " authentik_image
                    authentik_image=${authentik_image:-ghcr.io/goauthentik/server}
                    read -p "Authentik tag (default: 2024.6.2): " authentik_tag
                    authentik_tag=${authentik_tag:-2024.6.2}
                    read -p "HTTP port (default: 9000): " http_port
                    http_port=${http_port:-9000}
                    read -p "HTTPS port (default: 9443): " https_port
                    https_port=${https_port:-9443}
                    
                    # Generate AUTHENTIK_SECRET_KEY
                    authentik_secret_key=$(openssl rand -base64 60 | tr -d '\n')
                    
                    cat << EOF > .env
PG_PASS=$pg_pass
PG_USER=$pg_user
PG_DB=$pg_db
AUTHENTIK_IMAGE=$authentik_image
AUTHENTIK_TAG=$authentik_tag
COMPOSE_PORT_HTTP=$http_port
COMPOSE_PORT_HTTPS=$https_port
AUTHENTIK_SECRET_KEY=$authentik_secret_key
EOF
                    echo ".env file created for Authentik with a generated AUTHENTIK_SECRET_KEY"
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
