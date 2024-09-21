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

# Install Git if not already installed
function install_git() {
    if ! command -v git &> /dev/null; then
        echo_msg "Installing Git..."
        sudo $PACKAGE_MANAGER install git -y
    else
        echo_msg "Git is already installed."
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

# Function to install PHP and its extensions
function install_php() {
    echo_msg "Installing PHP and extensions..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo add-apt-repository ppa:ondrej/php -y
        sudo apt update -y
        sudo apt install -y php libapache2-mod-php php-mysql php-fpm \
            php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json
        sudo a2enmod php8.3
        sudo a2enconf php8.3-fpm
    else
        sudo yum install php php-mysqlnd php-fpm php-curl php-gd php-mbstring php-xml php-zip php-bcmath -y
    fi
}

# Install MySQL server
function install_mysql() {
    echo_msg "Installing MySQL server..."
    sudo $PACKAGE_MANAGER install mysql-server -y
    echo_msg "Please run 'mysql_secure_installation' manually to secure your MySQL installation."
}

# Enable Apache rewrite module
function enable_rewrite() {
    echo_msg "Enabling Apache rewrite module..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo a2enmod rewrite
    fi
    sudo systemctl restart apache2 || sudo systemctl restart httpd
}

# Create directories for virtual hosts
function create_virtual_host() {
    if [ ! -d "/var/www/$DOMAIN" ]; then
        echo_msg "Creating directory /var/www/$DOMAIN..."
        sudo mkdir -p /var/www/$DOMAIN
    else
        echo_msg "Directory /var/www/$DOMAIN already exists."
    fi
}

# Create virtual host configuration files
function create_virtual_host_config() {
    echo_msg "Creating virtual host configuration files..."
    cat <<EOF | sudo tee /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias *.$DOMAIN
    DocumentRoot /var/www/$DOMAIN
    <Directory /var/www/$DOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
    echo_msg "Enabling virtual host configurations..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo a2ensite $DOMAIN.conf
    else
        echo_msg "Ensure to manually include your virtual host configuration in your Apache config."
    fi
}

# Fetch available Git branches
function fetch_branches() {
    echo_msg "Fetching branches from the repository..."
    branches=$(git ls-remote --heads https://github.com/DevDhruvJoshi/Precocious.git | awk '{print $2}' | sed 's|refs/heads/||')
    echo_msg "Available branches:"
    echo "$branches" | nl
}

# Clone the selected branch from the Git repository
function clone_repository() {
    local selected_branch="$1"
    echo_msg "Cloning the Git repository into /var/www/$DOMAIN from branch '$selected_branch'..."
    git clone --branch "$selected_branch" https://github.com/DevDhruvJoshi/Precocious.git /var/www/$DOMAIN
}

# Set ownership for web directories
function set_ownership() {
    echo_msg "Setting ownership for the web directories..."
    sudo chown -R www-data:www-data /var/www/$DOMAIN || sudo chown -R apache:apache /var/www/$DOMAIN
}

# Install Composer
function install_composer() {
    read -p "Do you want to install Composer? (y/n, default: y): " INSTALL_COMPOSER
    INSTALL_COMPOSER=${INSTALL_COMPOSER:-y}

    if [[ "$INSTALL_COMPOSER" =~ ^[yY]$ ]]; then
        if command -v composer &> /dev/null; then
            echo_msg "Composer is already installed."
        else
            echo_msg "Installing Composer..."
            php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
            expected_hash="$(curl -s https://composer.github.io/installer.sha384sum | awk '{print $1}')"
            actual_hash="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

            if [ "$expected_hash" != "$actual_hash" ]; then
                echo_error "Installer corrupt"
                rm composer-setup.php
                exit 1
            fi

            php composer-setup.php
            php -r "unlink('composer-setup.php');"
            sudo mv composer.phar /usr/local/bin/composer
            sudo chmod +x /usr/local/bin/composer
            echo_msg "Composer has been installed successfully."
        fi
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

# Determine package manager
detect_package_manager

# Check if it's a new server
read -p "Is this a new server setup? (y/n, default: y): " NEW_SERVER
NEW_SERVER=${NEW_SERVER:-y}

if [[ "$NEW_SERVER" =~ ^[yY]$ ]]; then
    sudo $PACKAGE_MANAGER update -y
    install_git
    install_apache
    install_php
    install_mysql
    enable_rewrite
else
    read -p "Do you want to install Apache? (y/n, default: y): " INSTALL_APACHE
    INSTALL_APACHE=${INSTALL_APACHE:-y}
    [[ "$INSTALL_APACHE" =~ ^[yY]$ ]] && install_apache

    read -p "Do you want to install PHP and its extensions? (y/n, default: y): " INSTALL_PHP
    INSTALL_PHP=${INSTALL_PHP:-y}
    [[ "$INSTALL_PHP" =~ ^[yY]$ ]] && install_php

    read -p "Do you want to install MySQL server? (y/n, default: y): " INSTALL_MYSQL
    INSTALL_MYSQL=${INSTALL_MYSQL:-y}
    [[ "$INSTALL_MYSQL" =~ ^[yY]$ ]] && install_mysql

    enable_rewrite
fi

create_virtual_host
create_virtual_host_config

# Fetch branches and clone the selected one
fetch_branches

branch_count=$(echo "$branches" | wc -l)

if [[ $branch_count -eq 1 ]]; then
    selected_branch=$(echo "$branches" | sed -n '1p')
    echo_msg "Only one branch available: '$selected_branch'."
else
    read -p "Enter the number of the branch you want to clone (default: 1): " branch_number
    branch_number=${branch_number:-1}
    selected_branch=$(echo "$branches" | sed -n "${branch_number}p")

    if [[ -z "$selected_branch" ]]; then
        echo_error "Invalid selection. Exiting."
        exit 1
    fi
fi

clone_repository "$selected_branch"
sudo systemctl restart apache2 || sudo systemctl restart httpd
set_ownership
install_composer

echo_msg "Setup complete! Please remember to run 'mysql_secure_installation' manually."
