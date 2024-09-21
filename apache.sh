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
        echo_error "Invalid domain name. Please enter a valid domain (e.g., example.com)."
        return 1
    fi
    return 0
}

# Function to check if the domain points to the server's IP
function check_dns() {
    local domain="$1"
    local server_ip=$(hostname -I | awk '{print $1}') # Get the server's first IP
    local dns_ip=$(dig +short "$domain" A | head -n 1) # Get the A record for the domain

    if [[ "$dns_ip" != "$server_ip" ]]; then
        echo_error "The domain '$domain' does not point to this server's IP ($server_ip)."
        echo "Please update the DNS A record for '$domain' to point to this server's IP."
        read -p "Do you want to continue with the installation? (y/n, default: y): " CONTINUE_INSTALL
        CONTINUE_INSTALL=${CONTINUE_INSTALL:-y}  # Default to 'y' if no input
        if [[ ! "$CONTINUE_INSTALL" =~ ^[yY]$ ]]; then
            echo_msg "Exiting installation."
            exit 1
        fi
    fi
}

# Function to check and install Git
function install_git() {
    if ! command -v git &> /dev/null; then
        echo_msg "Installing Git..."
        sudo $PACKAGE_MANAGER install git -y
    else
        echo_msg "Git is already installed."
    fi
}

# Prompt for domain name
while true; do
    read -p "Enter your domain name (default: app.example.com): " DOMAIN
    DOMAIN=${DOMAIN:-app.example.com}

    if validate_domain "$DOMAIN"; then
        break
    fi
done

# Check if the domain points to this server's IP
check_dns "$DOMAIN"

# Determine package manager
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

# Check if it's a new server
read -p "Is this a new server setup? (y/n, default: y): " NEW_SERVER
NEW_SERVER=${NEW_SERVER:-y}  # Default to 'y' if no input

if [[ "$NEW_SERVER" =~ ^[yY]$ ]]; then
    echo_msg "Updating package list..."
    sudo $PACKAGE_MANAGER update -y

    # Install Git
    install_git

    # Install Apache
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

    # Install PHP and required extensions
    echo_msg "Installing PHP and extensions..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo add-apt-repository ppa:ondrej/php -y
        sudo apt update -y
        sudo apt install -y php libapache2-mod-php php-mysql php-fpm \
        php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json
    else
        sudo yum install php php-mysqlnd php-fpm php-curl php-gd php-mbstring php-xml php-zip php-bcmath -y
    fi

    # Enable PHP module and configuration
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo a2enmod php8.3
        sudo a2enconf php8.3-fpm
    fi

    # Restart Apache to apply changes
    echo_msg "Restarting Apache..."
    sudo systemctl restart apache2 || sudo systemctl restart httpd

    # Install MySQL server
    echo_msg "Installing MySQL server..."
    sudo $PACKAGE_MANAGER install mysql-server -y
    echo_msg "Please run 'mysql_secure_installation' manually to secure your MySQL installation."

    # Enable Apache rewrite module
    echo_msg "Enabling Apache rewrite module..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo a2enmod rewrite
    fi
    sudo systemctl restart apache2 || sudo systemctl restart httpd

else
    # Step by step installation
    read -p "Do you want to install Apache? (y/n, default: y): " INSTALL_APACHE
    INSTALL_APACHE=${INSTALL_APACHE:-y}  # Default to 'y' if no input
    if [[ "$INSTALL_APACHE" =~ ^[yY]$ ]]; then
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
    fi

    read -p "Do you want to install PHP and its extensions? (y/n, default: y): " INSTALL_PHP
    INSTALL_PHP=${INSTALL_PHP:-y}  # Default to 'y' if no input
    if [[ "$INSTALL_PHP" =~ ^[yY]$ ]]; then
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
        echo_msg "Restarting Apache..."
        sudo systemctl restart apache2 || sudo systemctl restart httpd
    fi

    read -p "Do you want to install MySQL server? (y/n, default: y): " INSTALL_MYSQL
    INSTALL_MYSQL=${INSTALL_MYSQL:-y}  # Default to 'y' if no input
    if [[ "$INSTALL_MYSQL" =~ ^[yY]$ ]]; then
        echo_msg "Installing MySQL server..."
        sudo $PACKAGE_MANAGER install mysql-server -y
        echo_msg "Please run 'mysql_secure_installation' manually to secure your MySQL installation."
    fi

    # Enable Apache rewrite module
    echo_msg "Enabling Apache rewrite module..."
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        sudo a2enmod rewrite
    fi
    sudo systemctl restart apache2 || sudo systemctl restart httpd
fi

# Create directories for virtual hosts if they don't already exist
if [ ! -d "/var/www/$DOMAIN" ]; then
    echo_msg "Creating directory /var/www/$DOMAIN..."
    sudo mkdir -p /var/www/$DOMAIN
else
    echo_msg "Directory /var/www/$DOMAIN already exists."
fi

# Create virtual host configuration files
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

# Enable the new virtual host configurations
echo_msg "Enabling virtual host configurations..."
if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    sudo a2ensite $DOMAIN.conf
else
    echo_msg "Ensure to manually include your virtual host configuration in your Apache config."
fi

# Function to fetch and display available branches
function fetch_branches() {
    echo_msg "Fetching branches from the repository..."
    branches=$(git ls-remote --heads https://github.com/DevDhruvJoshi/Precocious.git | awk '{print $2}' | sed 's|refs/heads/||')
    echo_msg "Available branches:"
    echo "$branches" | nl  # List branches with line numbers
}

# Call the function to fetch and display branches
fetch_branches

# Count the number of branches
branch_count=$(echo "$branches" | wc -l)

# Determine branch selection
if [[ $branch_count -eq 1 ]]; then
    selected_branch=$(echo "$branches" | sed -n '1p')
    echo_msg "Only one branch available: '$selected_branch'."
else
    # Prompt user to select a branch
    read -p "Enter the number of the branch you want to clone (default: 1): " branch_number
    branch_number=${branch_number:-1}  # Default to the first branch

    # Get the selected branch from the list
    selected_branch=$(echo "$branches" | sed -n "${branch_number}p")

    if [[ -z "$selected_branch" ]]; then
        echo_error "Invalid selection. Exiting."
        exit 1
    fi
fi

# Clone the specified branch of the Git repository
echo_msg "Cloning the Git repository into /var/www/$DOMAIN from branch '$selected_branch'..."
git clone --branch "$selected_branch" https://github.com/DevDhruvJoshi/Precocious.git /var/www/$DOMAIN

# Restart Apache to apply new configurations
echo_msg "Restarting Apache to apply new configurations..."
sudo systemctl restart apache2 || sudo systemctl restart httpd

# Set ownership for the web directories
echo_msg "Setting ownership for the web directories..."
sudo chown -R www-data:www-data /var/www/$DOMAIN || sudo chown -R apache:apache /var/www/$DOMAIN

# Install Composer
read -p "Do you want to install Composer? (y/n, default: y): " INSTALL_COMPOSER
INSTALL_COMPOSER=${INSTALL_COMPOSER:-y}  # Default to 'y' if no input
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
