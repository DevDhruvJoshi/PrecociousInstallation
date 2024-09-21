#!/bin/bash

# Check if apache.sh exists and remove it if it does
if [ -f "apache.sh" ]; then
    echo "Removing existing apache.sh..."
    sudo rm apache.sh
fi

# Check if apache.sh exists and remove it if it does
if [ -f "nginx.sh" ]; then
    echo "Removing existing nginx.sh..."
    sudo rm nginx.sh
fi


echo "Which server would you like to install?"
echo "1. Apache"
echo "2. Nginx"
read -p "Your choice (1 or 2): " choice

case $choice in
    1)
        echo "Installing Apache..."
        sudo curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/apache.sh
        sudo chmod +x apache.sh
        sudo ./apache.sh
        ;;
    2)
        echo "Installing Nginx..."
        sudo curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/nginx.sh
        sudo chmod +x nginx.sh
        sudo ./nginx.sh
        ;;
    *)
        echo "Installing default Apache..."
        sudo curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/apache.sh
        sudo chmod +x apache.sh
        sudo ./apache.sh
        ;;
esac
