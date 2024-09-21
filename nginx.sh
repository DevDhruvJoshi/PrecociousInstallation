#!/bin/bash

# Exit script on any error
set -e

# Function to display messages
function echo_msg() {
    echo ">>> $1"
}

# Function to display error messages in red
function echo_error() {
    echo -e "\033[31m>>> ERROR: $1\033[0m"
}

# Validate the domain format
function validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo_error "Invalid domain name. Please enter a valid domain (e.g., dhruvjoshi.dev)."
        return 1
    fi
    return 0
}

# Check if the domain points to the server's IP
function check_dns() {
    local domain="$1"
    local server_ip=$(hostname -I | awk '{print $1}')
    local dns_ip=$(dig +short "$domain" A | head -n 1)

    if [[ "$dns_ip" != "$server_ip" ]]; then
        echo_error "The domain '$domain' does not point to this server's IP ($server_ip)."
        echo "Please update the DNS A record for '$domain' to point to this server's IP."
        read -p "Do you want to continue with the installation? (y/n, default: y): " CONTINUE_INSTALL
        CONTINUE_INSTALL=${CONTINUE_INSTALL:-y}
        if [[ ! "$CONTINUE_INSTALL" =~ ^[yY]$ ]]; then
            echo_msg "Exiting installation."
            exit 1
        fi
    fi
}

# Function to add domain to /etc/hosts
function add_to_hosts() {
    local domain="$1"
    local ip=$(hostname -I | awk '{print $1}')
    
    echo_msg "You are about to add $domain to /etc/hosts with IP $ip."
    echo_msg "Adding this entry can improve local resolution for testing purposes."

    read -p "Do you want to add this entry to /etc/hosts? (y/n, default: n): " ADD_TO_HOSTS
    ADD_TO_HOSTS=${ADD_TO_HOSTS:-n}

    if [[ "$ADD_TO_HOSTS" =~ ^[yY]$ ]]; then
        if ! grep -q "$ip $domain" /etc/hosts; then
            echo "$ip $domain" | sudo tee -a /etc/hosts > /dev/null
            echo_msg "Added $domain to /etc/hosts with IP $ip."
        else
            echo_msg "$domain with IP $ip is already in /etc/hosts."
        fi
    else
        echo_msg "Skipping addition of $domain to /etc/hosts."
    fi
}

# Get the package manager
function detect_package_manager() {
    if command -v apt &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    else
        echo_error "No supported package manager found (apt, yum, dnf). Exiting."
        exit 1
    fi
}

# Function to install Nginx
function install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo_msg "Installing Nginx..."
        sudo $PACKAGE_MANAGER install nginx -y
        sudo systemctl start nginx
        sudo systemctl enable nginx
        sudo ufw allow 'Nginx Full'
    else
        echo_msg "Nginx is already installed."
    fi
}

# Function to create directories for the website
function create_web_directory() {
    if [ ! -d "/var/www/$DOMAIN" ]; then
        echo_msg "Creating directory /var/www/$DOMAIN..."
        sudo mkdir -p /var/www/$DOMAIN
    else
        echo_msg "Directory /var/www/$DOMAIN already exists."
    fi
}

# Function to create Nginx server block configuration
function create_nginx_config() {
    echo_msg "Creating Nginx server block configuration..."
    cat <<EOF | sudo tee /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock; # Update PHP version if needed
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    echo_msg "Enabling Nginx configuration..."
    sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    sudo nginx -t  # Test Nginx configuration
    sudo systemctl reload nginx
}

# Function to set ownership for web directories
function set_ownership() {
    echo_msg "Setting ownership for the web directories..."
    sudo chown -R www-data:www-data /var/www/$DOMAIN
}

# Install Git if not already installed
function install_git() {
    if ! command -v git &> /dev/null; then
        echo_msg "Installing Git..."
        sudo $PACKAGE_MANAGER install git -y
    else
        echo_msg "Git is already installed."
    fi
}

# Install PHP and its extensions
function install_php() {
    echo_msg "Installing PHP and extensions..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo apt update -y
        sudo apt install -y php php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath
    else
        sudo yum install php php-fpm php-mysqlnd php-curl php-gd php-mbstring php-xml php-zip php-bcmath -y
    fi
}

# Main script execution starts here

# Prompt for domain name
while true; do
    read -p "Enter your domain name (default: dhruvjoshi.dev): " DOMAIN
    DOMAIN=${DOMAIN:-dhruvjoshi.dev}

    if validate_domain "$DOMAIN"; then
        break
    fi
done

# Check if the domain points to this server's IP
check_dns "$DOMAIN"

# Add domain to /etc/hosts
add_to_hosts "$DOMAIN"

# Determine package manager
detect_package_manager

# Check if it's a new server
read -p "Is this a new server setup? (y/n, default: y): " NEW_SERVER
NEW_SERVER=${NEW_SERVER:-y}

if [[ "$NEW_SERVER" =~ ^[yY]$ ]]; then
    sudo $PACKAGE_MANAGER update -y
    install_git
    install_nginx
    install_php
else
    read -p "Do you want to install Nginx? (y/n, default: y): " INSTALL_NGINX
    INSTALL_NGINX=${INSTALL_NGINX:-y}
    [[ "$INSTALL_NGINX" =~ ^[yY]$ ]] && install_nginx

    read -p "Do you want to install PHP and its extensions? (y/n, default: y): " INSTALL_PHP
    INSTALL_PHP=${INSTALL_PHP:-y}
    [[ "$INSTALL_PHP" =~ ^[yY]$ ]] && install_php
fi

create_web_directory
create_nginx_config
set_ownership

echo_msg "Setup complete! Please remember to configure your database connection as needed."
