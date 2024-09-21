#!/bin/bash

echo "Kaunsa server install karna hai?"
echo "1. Apache"
echo "2. Nginx"
read -p "Aapka choice (1 ya 2): " choice

case $choice in
    1)
        echo "Apache install kiya ja raha hai..."
        sudo curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/apache.sh
        sudo chmod +x apache.sh
        sudo ./apache.sh
        ;;
    2)
        echo "Nginx install kiya ja raha hai..."
        sudo curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/nginx.sh
        sudo chmod +x nginx.sh
        sudo ./nginx.sh
        ;;
    *)
        echo "Default Apache install kiya ja raha hai..."
        sudo curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/apache.sh
        sudo chmod +x apache.sh
        sudo ./apache.sh
        ;;
esac
