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

# Function to validate domain
function validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo "Invalid domain name. Please enter a valid domain (e.g., dhruvjoshi.dev)."
        return 1
    fi
    return 0
}

# Function to check if the domain points to the server's IP
function check_dns() {
    local domain="$1"
    local server_ip=$(hostname -I | awk '{print $1}')
    local dns_ip=$(dig +short "$domain" A | head -n 1)

    if [[ "$dns_ip" != "$server_ip" ]]; then
        echo_error "The domain '$domain' does not point to this server's IP ($server_ip)."
        echo "Please update the DNS A record for '$domain' to point to this server's IP."
        read -p "Do you want to continue with the installation? (y/n): " CONTINUE_INSTALL
        if [[ ! "$CONTINUE_INSTALL" =~ ^[yY]$ ]]; then
            echo_msg "Exiting installation."
            exit 1
        fi
    fi
}

# Detect package manager
if command -v apt &> /dev/null; then
    PM="apt"
    INSTALL_CMD="sudo apt install -y"
    UPDATE_CMD="sudo apt update -y && sudo apt upgrade -y"
    RESTART_CMD="sudo systemctl restart"
elif command -v dnf &> /dev/null; then
    PM="dnf"
    INSTALL_CMD="sudo dnf install -y"
    UPDATE_CMD="sudo dnf upgrade --refresh -y"
    RESTART_CMD="sudo systemctl restart"
elif command -v yum &> /dev/null; then
    PM="yum"
    INSTALL_CMD="sudo yum install -y"
    UPDATE_CMD="sudo yum update -y"
    RESTART_CMD="sudo systemctl restart"
else
    echo_error "Unsupported package manager. Exiting."
    exit 1
fi

# Prompt for domain name
while true; do
    read -p "Enter your domain name (default: app.dhruvjoshi.dev): " DOMAIN
    DOMAIN=${DOMAIN:-app.dhruvjoshi.dev}

    if validate_domain "$DOMAIN"; then
        break
    fi
done

# Check if the domain points to this server's IP
check_dns "$DOMAIN"

# Check if it's a new server
read -p "Is this a new server setup? (y/n): " NEW_SERVER

if [[ "$NEW_SERVER" =~ ^[yY]$ ]]; then
    # Update and upgrade the package list
    echo_msg "Updating and upgrading packages..."
    eval $UPDATE_CMD

    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        echo_msg "Installing Nginx..."
        eval $INSTALL_CMD nginx
        sudo systemctl start nginx
        sudo systemctl enable nginx
    else
        echo_msg "Nginx is already installed."
    fi

    # Install PHP and required extensions
    echo_msg "Installing PHP and extensions..."
    if [[ "$PM" == "apt" ]]; then
        sudo add-apt-repository ppa:ondrej/php -y
        eval $UPDATE_CMD
    fi
    eval $INSTALL_CMD php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json

    # Check Nginx configuration
    echo_msg "Checking Nginx configuration..."
    sudo nginx -t

    # Restart Nginx to apply changes
    echo_msg "Restarting Nginx..."
    if ! eval $RESTART_CMD nginx; then
        echo_error "Failed to restart Nginx. Checking logs for details..."
        echo "Check the status with: systemctl status nginx.service"
        echo "View logs with: journalctl -xeu nginx.service"
        exit 1
    fi

    # Install MySQL server
    echo_msg "Installing MySQL server..."
    eval $INSTALL_CMD mysql-server
    echo_msg "Please run 'mysql_secure_installation' manually to secure your MySQL installation."

else
    # Step by step installation
    read -p "Do you want to install Nginx? (y/n): " INSTALL_NGINX
    if [[ "$INSTALL_NGINX" =~ ^[yY]$ ]]; then
        if ! command -v nginx &> /dev/null; then
            echo_msg "Installing Nginx..."
            eval $INSTALL_CMD nginx
            sudo systemctl start nginx
            sudo systemctl enable nginx
        else
            echo_msg "Nginx is already installed."
        fi
    fi

    read -p "Do you want to install PHP and its extensions? (y/n): " INSTALL_PHP
    if [[ "$INSTALL_PHP" =~ ^[yY]$ ]]; then
        if [[ "$PM" == "apt" ]]; then
            sudo add-apt-repository ppa:ondrej/php -y
            eval $UPDATE_CMD
        fi
        echo_msg "Installing PHP and extensions..."
        eval $INSTALL_CMD php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json

        echo_msg "Checking Nginx configuration..."
        sudo nginx -t

        echo_msg "Restarting Nginx..."
        if ! eval $RESTART_CMD nginx; then
            echo_error "Failed to restart Nginx. Checking logs for details..."
            echo "Check the status with: systemctl status nginx.service"
            echo "View logs with: journalctl -xeu nginx.service"
            exit 1
        fi
    fi

    read -p "Do you want to install MySQL server? (y/n): " INSTALL_MYSQL
    if [[ "$INSTALL_MYSQL" =~ ^[yY]$ ]]; then
        echo_msg "Installing MySQL server..."
        eval $INSTALL_CMD mysql-server
        echo_msg "Please run 'mysql_secure_installation' manually to secure your MySQL installation."
    fi
fi

# Create directories for virtual hosts
echo_msg "Creating directories for virtual hosts..."
sudo mkdir -p /var/www/$DOMAIN

# Create Nginx configuration files
echo_msg "Creating Nginx configuration files..."
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
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock; # Adjust PHP version as necessary
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable the new site configuration
echo_msg "Enabling site configuration..."
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Restart Nginx to apply new configurations
echo_msg "Restarting Nginx to apply new configurations..."
if ! eval $RESTART_CMD nginx; then
    echo_error "Failed to restart Nginx. Checking logs for details..."
    echo "Check the status with: systemctl status nginx.service"
    echo "View logs with: journalctl -xeu nginx.service"
    exit 1
fi

# Create index.php files for each site
echo_msg "Creating index.php files..."
echo "<?php echo 'This is the $DOMAIN site.'; ?>" | sudo tee /var/www/$DOMAIN/index.php

# Set ownership for the web directories
echo_msg "Setting ownership for the web directories..."
sudo chown -R www-data:www-data /var/www/$DOMAIN

# Install Composer
read -p "Do you want to install Composer? (y/n): " INSTALL_COMPOSER
if [[ "$INSTALL_COMPOSER" =~ ^[yY]$ ]]; then
    echo_msg "Installing Composer..."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'c3f3cbe12c3c5f5cf2c4b39a37785c9ec12e1670d46d4a7e9e27ef85d5eb5459ee0b68cf421d9b54df5be8dd67a9188d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
fi

echo_msg "Setup complete! Please remember to run 'mysql_secure_installation' manually."
