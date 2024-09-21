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

# Function to install Apache
function install_apache() {
    echo_msg "Installing Apache..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo systemctl enable apache2
        sudo ufw allow 'Apache Full'
    else
        sudo yum install httpd -y
        sudo systemctl start httpd
        sudo systemctl enable httpd
    fi
}

# Function to install Nginx
function install_nginx() {
    echo_msg "Installing Nginx..."
    if ! command -v nginx &> /dev/null; then
        sudo $PACKAGE_MANAGER install nginx -y
        sudo systemctl start nginx
        sudo systemctl enable nginx
        sudo ufw allow 'Nginx Full'
    else
        echo_msg "Nginx is already installed."
    fi
}

# Function to install PHP and its extensions
function install_php() {
    echo_msg "Installing PHP and extensions..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo add-apt-repository ppa:ondrej/php -y
        sudo apt update -y
        sudo apt install -y php libapache2-mod-php php-mysql php-fpm php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json
        sudo a2enmod php8.3
        sudo a2enconf php8.3-fpm
    else
        sudo yum install php php-mysqlnd php-fpm php-curl php-gd php-mbstring php-xml php-zip php-bcmath -y
    fi
}

# Function to create web directory
function create_web_directory() {
    if [ ! -d "/var/www/$DOMAIN" ]; then
        echo_msg "Creating directory /var/www/$DOMAIN..."
        sudo mkdir -p /var/www/$DOMAIN
    else
        echo_msg "Directory /var/www/$DOMAIN already exists."
    fi
}

# Function to set ownership for web directories
function set_ownership() {
    echo_msg "Setting ownership for the web directories..."
    if [[ "$SERVER_TYPE" == "apache" ]]; then
        sudo chown -R www-data:www-data /var/www/$DOMAIN || sudo chown -R apache:apache /var/www/$DOMAIN
    else
        sudo chown -R www-data:www-data /var/www/$DOMAIN
    fi
}

# Main script execution starts here

# Prompt for server type
while true; do
    read -p "Which server do you want to install? (1. Apache, 2. Nginx, default: 1): " SERVER_CHOICE
    SERVER_CHOICE=${SERVER_CHOICE:-1}
    
    if [[ "$SERVER_CHOICE" == "1" ]]; then
        SERVER_TYPE="apache"
        break
    elif [[ "$SERVER_CHOICE" == "2" ]]; then
        SERVER_TYPE="nginx"
        break
    else
        echo_error "Invalid choice. Please enter 1 or 2."
    fi
done

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

    # Install selected server
    if [[ "$SERVER_TYPE" == "apache" ]]; then
        install_apache
    else
        install_nginx
    fi

    install_php
} else {
    if [[ "$SERVER_TYPE" == "apache" ]]; then
        read -p "Do you want to install Apache? (y/n, default: y): " INSTALL_APACHE
        INSTALL_APACHE=${INSTALL_APACHE:-y}
        [[ "$INSTALL_APACHE" =~ ^[yY]$ ]] && install_apache
    else
        read -p "Do you want to install Nginx? (y/n, default: y): " INSTALL_NGINX
        INSTALL_NGINX=${INSTALL_NGINX:-y}
        [[ "$INSTALL_NGINX" =~ ^[yY]$ ]] && install_nginx
    fi

    read -p "Do you want to install PHP and its extensions? (y/n, default: y): " INSTALL_PHP
    INSTALL_PHP=${INSTALL_PHP:-y}
    [[ "$INSTALL_PHP" =~ ^[yY]$ ]] && install_php
}

create_web_directory
set_ownership

echo_msg "Setup complete! Please remember to run 'mysql_secure_installation' manually."
