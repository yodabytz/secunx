# SecuNX - Nginx Security Automation

**SecuNX** is an automated security solution for Nginx servers, designed to enhance your website's protection by managing IP blocklists and whitelists. It fetches malicious IP addresses from trusted sources, updates your Nginx configuration automatically, and ensures that trusted IPs are never inadvertently blocked. Additionally, SecuNX provides a custom 403 error page to inform blocked users appropriately.

## 🛡️ Features

- **Automated Blocklist Updates:** Regularly fetches and updates blocklists from reputable sources like Blocklist.de, AbuseIPDB, and Tor Exit Nodes.
- **Custom Whitelist:** Allows specific IPs to always have access, overriding any blocklist entries.
- **Custom 403 Error Page:** Provides informative feedback to blocked users with a tailored error page.
- **Cron Job Integration:** Ensures blocklists are updated daily without manual intervention.
- **Backup Mechanism:** Automatically backs up existing blocklists before updates.
- **Secure Configuration:** Implements best practices for file permissions and ownership.

## ⚙️ Prerequisites

Before installing SecuNX, ensure your system meets the following requirements:

- **Operating System:** Ubuntu 20.04 LTS or later.
- **Nginx:** Installed and running.
- **PHP-FPM:** Installed and configured (version 8.3 recommended).
- **Root Access:** Required to modify Nginx configurations and install dependencies.
- **Git:** Installed for cloning the repository.
- **API Key:** Obtain an API key from [AbuseIPDB](https://www.abuseipdb.com/register) for accessing their blacklist API.

## 🚀 Installation

Follow the steps below to set up SecuNX on your server.

### 1. Clone the Repository

First, clone the SecuNX repository to your server:

```bash
git clone https://github.com/yourusername/SecuNX.git
cd SecuNX
```

### 2. Run the Installation Script
The install.sh script automates the installation of dependencies, configuration files, and sets appropriate permissions. However, it does not modify Nginx server blocks, which must be done manually to ensure proper integration with your specific server environment.

```
sudo bash install.sh
```
### 3. Configure Nginx Server Blocks
After running the installation script, you need to manually configure your Nginx server blocks to integrate the whitelist and blocklist configurations.

#### 3.1. Locate Your Nginx Configuration
Typically, Nginx server blocks are located in /etc/nginx/sites-available/. Open your server block configuration file (e.g., yourdomain.conf) with a text editor:
```
sudo nano /etc/nginx/sites-available/yourdomain.conf
```
#### 3.2. Modify the Server Block
Insert the following lines into both the HTTP (listen 80) and HTTPS (listen 443 ssl) server blocks before including the blocklist. This ensures that the whitelist is processed before any blocklist rules.
```
# Include Whitelist BEFORE Blocklist
include /etc/nginx/secuNX/whitelist.conf;
```
Ensure that the error_page directive and custom error page location are correctly set up as described below.

#### 3.3. Server Block Example
Here's a sample snippet to include in your server block:
```
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    root /var/www/yourdomain.com;
    index index.php index.html index.htm;

    # Define custom 403 error page BEFORE including blocklist
    error_page 403 /secuNX_403.php;

    # Handle custom 403 error page
    location = /secuNX_403.php {
        internal;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root/secuNX_403.php;
    }

    # Include Whitelist BEFORE Blocklist
    include /etc/nginx/secuNX/whitelist.conf;

    # Include SecuNX Blocklist AFTER defining error_page and whitelist
    include /etc/nginx/secuNX/blocklist.conf;

    # Handle PHP scripts
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    # Deny access to .htaccess files
    location ~ /\.ht {
        deny all;
    }

    # Main site configuration
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Handle specific URL patterns
    location ~ ^/([a-zA-Z0-9_-]+)$ {
        try_files /$1.html =404;
    }

    # Internal handling for HTML files
    location ~ \.html$ {
        internal;
    }

    # Custom 404 error page
    error_page 404 /404.html;

    # Serve the custom 404 page
    location = /404.html {
        internal;
        root /var/www/yourdomain.com;
    }
}
```
### 4. Set Up the Whitelist
Edit the whitelist configuration file to include trusted IP addresses.
```
sudo nano /etc/nginx/secuNX/whitelist.conf
```
#### Sample whitelist.conf:
```
# Whitelist Configuration
# Allow access to trusted IPs

# Allow localhost
allow 127.0.0.1;
allow ::1;

# Allow specific trusted IPs
allow 203.0.113.5;      # Replace with your trusted IP
allow 198.51.100.10;    # Replace with another trusted IP

# Add more allowed IPs or ranges as needed
# allow 192.0.2.0/24;
```
Important:

Replace the example IPs (203.0.113.5, 198.51.100.10) with the actual IPs you wish to whitelist.
Use CIDR Notation for IP ranges if needed (e.g., 192.0.2.0/24).

### 5. Create the Custom 403 Error Page
The installation script creates the secuNX_403.php file. However, ensure it contains the desired content and is correctly configured.
```
sudo nano /var/www/yourdomain.com/secuNX_403.php
```
#### Sample Content:
```
<?php
// secuNX_403.php

// Set the response status code to 403 Forbidden
http_response_code(403);

// Gather necessary information
$remote_addr = $_SERVER['REMOTE_ADDR'] ?? 'N/A';
$request_uri = $_SERVER['REQUEST_URI'] ?? 'N/A';
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'N/A';
$time_local = date('Y-m-d H:i:s'); // Server's current time
$server_id = '15013'; // Static Server ID

// Block details
$block_id = 'BLACK02';
$block_reason = 'Your IP address is listed in our blacklist and blocked from completing this request.';

// HTML Content
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Access Denied - SecuNX Website Firewall</title>
    <style>
        body {
            background-color: #f8f9fa;
            font-family: Arial, sans-serif;
            color: #333;
            text-align: center;
            padding: 50px;
        }
        .container {
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            display: inline-block;
            padding: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #dc3545;
            margin-bottom: 20px;
        }
        p {
            font-size: 16px;
            line-height: 1.5;
        }
        .details {
            background-color: #f1f3f5;
            border: 1px solid #ced4da;
            border-radius: 4px;
            padding: 15px;
            margin-top: 20px;
            text-align: left;
        }
        .details strong {
            display: inline-block;
            width: 150px;
        }
        a {
            color: #007bff;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        footer {
            margin-top: 30px;
            font-size: 12px;
            color: #6c757d;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Access Denied</h1>
        <h2>SecuNX Website Firewall</h2>
        <p>If you are the site owner (or you manage this site), please whitelist your IP or if you think this block is an error, please <a href="/support">open a support ticket</a> and make sure to include the block details (displayed below), so we can assist you in troubleshooting the issue.</p>
        <div class="details">
            <p><strong>Your IP:</strong> <?php echo htmlspecialchars($remote_addr); ?></p>
            <p><strong>URL:</strong> <?php echo htmlspecialchars($request_uri); ?></p>
            <p><strong>Your Browser:</strong> <?php echo htmlspecialchars($user_agent); ?></p>
            <p><strong>Block ID:</strong> <?php echo htmlspecialchars($block_id); ?></p>
            <p><strong>Block Reason:</strong> <?php echo htmlspecialchars($block_reason); ?></p>
            <p><strong>Time:</strong> <?php echo htmlspecialchars($time_local); ?></p>
            <p><strong>Server ID:</strong> <?php echo htmlspecialchars($server_id); ?></p>
        </div>
    </div>
    <footer>
        &copy; 2024 SecuNX Web Application Firewall
    </footer>
</body>
</html>
```
#### Set Correct Permissions and Ownership:
```
sudo chmod 644 /var/www/yourdomain.com/secuNX_403.php
sudo chown www-data:www-data /var/www/yourdomain.com/secuNX_403.php
```
### 6. Set Up Automated Blocklist Updates
SecuNX includes an update_blocklist.sh script that fetches and updates blocklists from Blocklist.de and AbuseIPDB. It also integrates with the whitelist to ensure trusted IPs are never blocked.
#### 6.1. Configure the Script
The installation script places the update_blocklist.sh script in /usr/local/bin/. Ensure it has the correct API key for AbuseIPDB.
```
sudo nano /usr/local/bin/update_blocklist.sh
```
#### Replace the Placeholder:
```
ABUSEIPDB_API_KEY="YOUR_ABUSEIPDB_API_KEY"  # Replace with your AbuseIPDB API key
```
Important: Keep your API key secure and do not expose it publicly.

#### 6.2. Schedule the Script with Cron
The installation script sets up a daily cron job to run update_blocklist.sh. Verify that the cron job is correctly scheduled.
```
sudo crontab -l
```
#### Expected Entry:
```
0 0 * * * /usr/local/bin/update_blocklist.sh >> /var/log/update_blocklist.log 2>&1
```
This cron job runs the update script daily at midnight and logs output to /var/log/update_blocklist.log.

### 7. Verification
After completing the installation and configuration steps, perform the following verifications:
#### 7.1. Test the Custom 403 Error Page
Access the custom error page directly to ensure it displays correctly.
```
http://yourdomain.com/secuNX_403.php
```
Expected Result: Your custom "Access Denied - SecuNX Website Firewall" page should appear.

#### 7.2. Test Blocking Mechanism
Add a Test IP to blocklist.conf:
```
sudo nano /etc/nginx/secuNX/blocklist.conf
```
Add:
```
deny 203.0.113.100;  # Replace with your test IP
```
#### Reload Nginx:
```
sudo nginx -t
sudo systemctl reload nginx
```
### Troubleshooting
If you encounter issues during installation or configuration, consider the following steps:

### Check Nginx Configuration:
```
sudo nginx -t
```
Resolve any syntax errors reported before reloading.

#### Review Logs:

   #### Access Logs:
```
sudo tail -f /var/log/nginx/access.log
```
   #### Error Logs:
```
sudo tail -f /var/log/nginx/error.log
```
   ### Blocklist Update Logs:
```
sudo tail -f /var/log/update_blocklist.log
```
### Verify Permissions:
Ensure all configuration files and scripts have the correct permissions and ownership.

### Ensure PHP-FPM is Running:
```
sudo systemctl status php8.3-fpm
```
   #### Start or Restart PHP-FPM if necessary:
   ```
   sudo systemctl restart php8.3-fpm
   ```
### 9. License
This project is licensed under the MIT License.

### 10. Contact
For any questions or support, please contact yodabytz@gmail.com
