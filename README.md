Documentation for setup.sh
Overview
The setup.sh script automates the installation and configuration of a web server environment on a fresh Ubuntu server. It installs Apache, PHP, MySQL, and Composer, along with setting up a virtual host for a specified domain.

Prerequisites
Ubuntu Server: The script is designed for Ubuntu systems.
Root Access: You need to have root or sudo privileges on the server.
Domain Name: You should have a domain name that you want to point to this server.
Steps to Run the Script
Connect to Your Server

Use SSH to connect to your server:
bash
Copy code
ssh username@your-server-ip
Replace username with your server username and your-server-ip with the server's IP address.
Download the Script

Use curl or wget to download the script to your server:
bash
Copy code
# Using curl
curl -O https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/setup.sh

# Or using wget
wget https://raw.githubusercontent.com/DevDhruvJoshi/PrecociousServerConfiguration/main/setup.sh
Make the Script Executable

Change the permissions to make the script executable:
bash
Copy code
chmod +x setup.sh
Run the Script

Execute the script:
bash
Copy code
sudo ./setup.sh
The script will prompt you for various inputs during execution, such as your domain name and whether it’s a new server setup.
Follow the Prompts

Enter Your Domain Name: You’ll be asked to input your domain name. You can hit Enter to use the default.
Check DNS Configuration: The script will check if your domain points to the server’s IP. If it doesn’t, you will be asked if you want to continue with the installation despite the DNS issue. Respond with y to proceed or n to exit.
Choose Installation Options: If it’s not a new server setup, you will have the option to install Apache, PHP, and MySQL.
Finalizing Installation

The script will perform the necessary installations and configurations. Once it finishes, you will see a completion message.
Run MySQL Secure Installation: After the setup, you will need to run the command mysql_secure_installation manually to secure your MySQL installation.
Expected Output
You will see messages indicating the progress of the installation, including updates, package installations, and configuration steps.
Any errors will be displayed in red for easy identification.
Post-Installation
Verify Apache Installation: Open your web browser and navigate to your server’s IP address or domain name. You should see a page indicating that the server is running.
Access Your Website: The document root for your domain is located at /var/www/your-domain, where you can place your web files.
Notes
Ensure that your domain’s DNS A record is pointing to your server’s public IP address before accessing it.
It’s recommended to review firewall settings to ensure Apache is allowed to serve traffic (usually set up by the script).
Troubleshooting
If you encounter issues, check the Apache logs located at /var/log/apache2/error.log for errors.
Ensure that your server is updated and that all necessary packages are available.
Conclusion
This script simplifies the process of setting up a web server environment. By following this documentation, users can quickly get their server ready for web hosting with the required software stack.
