#!/bin/bash

# Exit script on any error
set -e

# Function to display messages
function echo_msg() {
    echo ">>> $1"
}

# Update and upgrade the package list
echo_msg "Updating and upgrading packages..."
sudo apt update -y && sudo apt upgrade -y

# Install Apache
echo_msg "Installing Apache..."
sudo apt install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2
sudo ufw allow 'Apache Full'

# Install PHP and required extensions
echo_msg "Installing PHP and extensions..."
sudo apt install -y php libapache2-mod-php php-mysql php-fpm \
php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json

# Add PHP repository
echo_msg "Adding PHP repository..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y

# Enable PHP module and configuration
echo_msg "Enabling PHP module and configuration..."
sudo a2enmod php8.3
sudo a2enconf php8.3-fpm

# Check Apache configuration
echo_msg "Checking Apache configuration..."
sudo apache2ctl configtest

# Restart Apache to apply changes
echo_msg "Restarting Apache..."
sudo systemctl restart apache2

# Install MySQL server
echo_msg "Installing MySQL server..."
sudo apt install mysql-server -y

# Notify user to run MySQL secure installation manually
echo_msg "Please run 'mysql_secure_installation' manually to secure your MySQL installation."

# Enable Apache rewrite module
echo_msg "Enabling Apache rewrite module..."
sudo a2enmod rewrite
sudo systemctl restart apache2

# Create directories for virtual hosts
echo_msg "Creating directories for virtual hosts..."
sudo mkdir -p /var/www/app.dhruvjoshi.dev
sudo mkdir -p /var/www/prod.dhruvjoshi.dev
sudo mkdir -p /var/www/html

# Create virtual host configuration files
echo_msg "Creating virtual host configuration files..."
cat <<EOF | sudo tee /etc/apache2/sites-available/app.dhruvjoshi.dev.conf
<VirtualHost *:80>
    ServerName app.dhruvjoshi.dev
    ServerAlias *.app.dhruvjoshi.dev
    DocumentRoot /var/www/app.dhruvjoshi.dev
    <Directory /var/www/app.dhruvjoshi.dev>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

cat <<EOF | sudo tee /etc/apache2/sites-available/prod.dhruvjoshi.dev.conf
<VirtualHost *:80>
    ServerName prod.dhruvjoshi.dev
    ServerAlias *.prod.dhruvjoshi.dev
    DocumentRoot /var/www/prod.dhruvjoshi.dev
    <Directory /var/www/prod.dhruvjoshi.dev>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

cat <<EOF | sudo tee /etc/apache2/sites-available/precocious.dhruvjoshi.dev.conf
<VirtualHost *:80>
    ServerName precocious.dhruvjoshi.dev
    ServerAlias *.precocious.dhruvjoshi.dev
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable the new virtual host configurations
echo_msg "Enabling virtual host configurations..."
sudo a2ensite app.dhruvjoshi.dev.conf
sudo a2ensite prod.dhruvjoshi.dev.conf
sudo a2ensite precocious.dhruvjoshi.dev.conf

# Disable the default site
echo_msg "Disabling default site..."
sudo a2dissite 000-default.conf

# Restart Apache to apply new configurations
echo_msg "Restarting Apache to apply new configurations..."
sudo systemctl restart apache2

# Create index.php files for each site
echo_msg "Creating index.php files..."
echo "<?php echo 'This is the App subdomain.'; ?>" | sudo tee /var/www/app.dhruvjoshi.dev/index.php
echo "<?php echo 'This is the Prod subdomain.'; ?>" | sudo tee /var/www/prod.dhruvjoshi.dev/index.php
echo "<?php echo 'This is the Precocious subdomain.'; ?>" | sudo tee /var/www/html/index.php

# Set ownership for the web directories
echo_msg "Setting ownership for the web directories..."
sudo chown -R www-data:www-data /var/www/app.dhruvjoshi.dev
sudo chown -R www-data:www-data /var/www/prod.dhruvjoshi.dev
sudo chown -R www-data:www-data /var/www/html

echo_msg "Setup complete! Please remember to run 'mysql_secure_installation' manually."
