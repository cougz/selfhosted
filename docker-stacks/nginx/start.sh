#!/bin/bash

DOMAIN="${DOMAIN:-example.com}"

# Check if acme.sh is installed
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
    echo "acme.sh not found. Installing..."
    curl https://get.acme.sh | sh
fi

# Set acme.sh default CA to Let's Encrypt
set_default_ca () {
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# Function to issue/renew certificate
issue_cert() {
    /root/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN" --ocsp-must-staple --keylength ec-384 --force
}

# Check if certificate exists
if [ ! -f "/etc/nginx/ssl/$DOMAIN.crt" ] || [ ! -f "/etc/nginx/ssl/$DOMAIN.key" ]; then
    echo "Certificate not found. Issuing new certificate..."
    set_default_ca
    issue_cert
    /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
        --key-file /etc/nginx/ssl/$DOMAIN.key \
        --fullchain-file /etc/nginx/ssl/$DOMAIN.crt
else
    echo "Certificate exists. Checking for renewal..."
    /root/.acme.sh/acme.sh --cron
fi

# Generate dhparams.pem if it doesn't exist
if [ ! -f "/etc/nginx/ssl/dhparam.pem" ]; then
    echo "Generating dhparam.pem in 4096 length..."
    openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096
    echo "Generating dhparam.pem done!"
fi

# Complete
echo "start.sh complete"

# Start NGINX
echo "Starting nginx..."
nginx -g 'daemon off;'