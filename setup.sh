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

# Main script execution starts here
# ... other parts of the script

# Validate domain and add to hosts
add_to_hosts "$DOMAIN"


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

# Function to check and stop the conflicting server
function check_and_stop_server() {
    local server_name="$1"
    if systemctl is-active --quiet "$server_name"; then
        echo_msg "$server_name is currently running."
        read -p "Do you want to stop $server_name to free up port 80? (y/n, default: y): " STOP_SERVER
        STOP_SERVER=${STOP_SERVER:-y}
        
        if [[ "$STOP_SERVER" =~ ^[yY]$ ]]; then
            echo_msg "Stopping $server_name service..."
            sudo systemctl stop "$server_name"
            echo_msg "$server_name service stopped."
        else
            echo_error "$server_name must be stopped to run the other server on port 80."
            exit 1
        fi
    else
        echo_msg "$server_name is not running."
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

# Function to set ownership for web directories
function set_ownership() {
    echo_msg "Setting ownership for the web directories..."
    sudo chown -R www-data:www-data /var/www/$DOMAIN || sudo chown -R apache:apache /var/www/$DOMAIN
}

# Main script execution starts here

# Prompt for server type
echo "Select server to install:"
echo "1) Apache"
echo "2) Nginx"
read -p "Enter your choice (default: 1): " SERVER_CHOICE
SERVER_CHOICE=${SERVER_CHOICE:-1}

# Prompt for domain name
while true; do
    read -p "Enter your domain name (default: dhruvjoshi.dev): " DOMAIN
    DOMAIN=${DOMAIN:-dhruvjoshi.dev}

    if validate_domain "$DOMAIN"; t
