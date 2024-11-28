
---

## 🖥️ install.sh

```bash
#!/bin/bash

# ----------------------------
# Script: install.sh
# Purpose: Automate the installation of dependencies, configuration files, and permissions for SecuNX Nginx Security Setup
# ----------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages
print_msg() {
    echo -e "\n=== $1 ===\n"
}

# 1. Update System Packages
print_msg "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install Required Dependencies
print_msg "Installing required dependencies (curl, jq, mailutils)..."
sudo apt install -y curl jq mailutils

# 3. Create Necessary Directories
print_msg "Creating necessary directories..."
sudo mkdir -p /etc/nginx/secuNX
sudo mkdir -p /etc/nginx/blocklist_backups
sudo mkdir -p /var/www/secuNX

# 4. Create Whitelist Configuration File
print_msg "Creating whitelist configuration file..."
sudo bash -c 'cat > /etc/nginx/secuNX/whitelist.conf <<EOL
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
EOL'

# 5. Create Blocklist Configuration File
print_msg "Creating blocklist configuration file..."
sudo bash -c 'cat > /etc/nginx/secuNX/blocklist.conf <<EOL
# SecuNX Blocklist
# Deny access to listed IPs

deny 107.189.13.253;
deny 192.0.2.1;
deny 198.51.100.23;
deny YOUR.TOR.IP.ADDRESS;  # Replace with the actual Tor exit node IP you want to block
# Add more IPs as needed
EOL'

# 6. Create the Blocklist Update Script
print_msg "Creating blocklist update script..."
sudo bash -c 'cat > /usr/local/bin/update_blocklist.sh <<EOL
#!/bin/bash

# ----------------------------
# Script: update_blocklist.sh
# Purpose: Automatically update Nginx blocklist.conf with malicious IPs
# ----------------------------

# Configuration
BLOCKLIST_CONF="/etc/nginx/secuNX/blocklist.conf"
WHITELIST_CONF="/etc/nginx/secuNX/whitelist.conf"
TEMP_BLOCKLIST="/tmp/blocklist_temp.conf"
BACKUP_DIR="/etc/nginx/blocklist_backups"
ABUSEIPDB_API_KEY="YOUR_ABUSEIPDB_API_KEY"  # Replace with your AbuseIPDB API key
ABUSEIPDB_THRESHOLD=50  # Minimum number of reports to consider
ABUSEIPDB_URL="https://api.abuseipdb.com/api/v2/blacklist"

# Whitelisted IPs (same as in whitelist.conf)
WHITELIST_IPS=(
    "127.0.0.1"
    "::1"
    "203.0.113.5"
    "198.51.100.10"
    # Add more whitelisted IPs as needed
)

# URLs of blocklists to fetch
BLOCKLIST_DE_URL="https://lists.blocklist.de/lists/all.txt"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to fetch Blocklist.de
fetch_blocklist_de() {
    echo "Fetching Blocklist.de..."
    curl -s "$BLOCKLIST_DE_URL" | grep -v '^#' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' > /tmp/blocklist_de.txt
    echo "Fetched \$(wc -l < /tmp/blocklist_de.txt) IPs from Blocklist.de."
}

# Function to fetch AbuseIPDB
fetch_abuseipdb() {
    echo "Fetching AbuseIPDB..."
    RESPONSE=\$(curl -s -G "$ABUSEIPDB_URL" \
        --data-urlencode "maxAgeInDays=90" \
        --data-urlencode "confidenceMinimum=$ABUSEIPDB_THRESHOLD" \
        -H "Key: \$ABUSEIPDB_API_KEY" \
        -H "Accept: application/json")

    # Save the response to a file
    echo "\$RESPONSE" > /tmp/abuseipdb.json

    # Check if 'data' exists and is not null
    DATA_EXISTS=\$(echo "\$RESPONSE" | jq '.data // empty')

    if [ -z "\$DATA_EXISTS" ]; then
        # Extract error message if available
        ERROR_MESSAGE=\$(echo "\$RESPONSE" | jq -r '.errors[0].detail // .meta.error // "Unknown error"')
        echo "Error fetching AbuseIPDB: \$ERROR_MESSAGE"
        # Exit the script or decide to proceed without AbuseIPDB data
        return 1
    fi

    # Extract IPs
    jq -r '.data[] | .ipAddress' /tmp/abuseipdb.json > /tmp/abuseipdb.txt
    echo "Fetched \$(wc -l < /tmp/abuseipdb.txt) IPs from AbuseIPDB."
}

# Function to merge and deduplicate IPs, excluding whitelisted IPs
merge_blocklists() {
    echo "Merging blocklists and excluding whitelisted IPs..."
    cat /tmp/blocklist_de.txt /tmp/abuseipdb.txt | sort | uniq > /tmp/merged_blocklist.txt

    # Remove whitelisted IPs
    for ip in "\${WHITELIST_IPS[@]}"; do
        grep -v "^\$ip\$" /tmp/merged_blocklist.txt > /tmp/merged_blocklist_tmp.txt
        mv /tmp/merged_blocklist_tmp.txt /tmp/merged_blocklist.txt
    done

    echo "Total unique IPs after excluding whitelisted IPs: \$(wc -l < /tmp/merged_blocklist.txt)"
}

# Function to format IPs for Nginx
format_for_nginx() {
    echo "Formatting IPs for Nginx..."
    awk '{print "deny " \$1 ";"}' /tmp/merged_blocklist.txt > "\$TEMP_BLOCKLIST"
}

# Function to backup existing blocklist
backup_existing_blocklist() {
    TIMESTAMP=\$(date +%F_%T)
    echo "Backing up existing blocklist.conf to \$BACKUP_DIR/blocklist.conf.\$TIMESTAMP.bak"
    cp "\$BLOCKLIST_CONF" "\$BACKUP_DIR/blocklist.conf.\$TIMESTAMP.bak"
}

# Function to update blocklist.conf
update_blocklist_conf() {
    echo "Updating blocklist.conf..."
    cp "\$TEMP_BLOCKLIST" "\$BLOCKLIST_CONF"
    echo "blocklist.conf updated successfully."
}

# Function to reload Nginx
reload_nginx() {
    echo "Reloading Nginx to apply changes..."
    nginx -t
    if [ \$? -eq 0 ]; then
        systemctl reload nginx
        if [ \$? -eq 0 ]; then
            echo "Nginx reloaded successfully."
        else
            echo "Nginx reload failed. Restoring from backup."
            cp "\$BACKUP_DIR/blocklist.conf.\$TIMESTAMP.bak" "\$BLOCKLIST_CONF"
            systemctl reload nginx
            exit 1
        fi
    else
        echo "Nginx configuration test failed. Restoring from backup."
        cp "\$BACKUP_DIR/blocklist.conf.\$TIMESTAMP.bak" "\$BLOCKLIST_CONF"
        exit 1
    fi
}

# Main Execution Flow
fetch_blocklist_de
if fetch_abuseipdb; then
    merge_blocklists
    format_for_nginx
    backup_existing_blocklist
    update_blocklist_conf
    reload_nginx
else
    echo "AbuseIPDB fetch failed. Proceeding with only Blocklist.de data."
    merge_blocklists
    format_for_nginx
    backup_existing_blocklist
    update_blocklist_conf
    reload_nginx
fi

# Clean up temporary files
rm -f /tmp/blocklist_de.txt /tmp/abuseipdb.json /tmp/abuseipdb.txt /tmp/merged_blocklist.txt /tmp/blocklist_temp.conf

echo "Blocklist update process completed."
EOL'

# 7. Secure the Update Script
print_msg "Securing the blocklist update script..."
sudo chmod 700 /usr/local/bin/update_blocklist.sh
sudo chown root:root /usr/local/bin/update_blocklist.sh

# 8. Create the Custom 403 Error Page
print_msg "Creating the custom 403 error page..."
sudo mkdir -p /var/www/secuNX
sudo bash -c 'cat > /var/www/secuNX/secuNX_403.php <<EOL
<?php
// secuNX_403.php

// Set the response status code to 403 Forbidden
http_response_code(403);

// Gather necessary information
\$remote_addr = \$_SERVER['REMOTE_ADDR'] ?? 'N/A';
\$request_uri = \$_SERVER['REQUEST_URI'] ?? 'N/A';
\$user_agent = \$_SERVER['HTTP_USER_AGENT'] ?? 'N/A';
\$time_local = date('Y-m-d H:i:s'); // Server's current time
\$server_id = '15013'; // Static Server ID

// Block details
\$block_id = 'BLACK02';
\$block_reason = 'Your IP address is listed in our blacklist and blocked from completing this request.';

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
            <p><strong>Your IP:</strong> <?php echo htmlspecialchars(\$remote_addr); ?></p>
            <p><strong>URL:</strong> <?php echo htmlspecialchars(\$request_uri); ?></p>
            <p><strong>Your Browser:</strong> <?php echo htmlspecialchars(\$user_agent); ?></p>
            <p><strong>Block ID:</strong> <?php echo htmlspecialchars(\$block_id); ?></p>
            <p><strong>Block Reason:</strong> <?php echo htmlspecialchars(\$block_reason); ?></p>
            <p><strong>Time:</strong> <?php echo htmlspecialchars(\$time_local); ?></p>
            <p><strong>Server ID:</strong> <?php echo htmlspecialchars(\$server_id); ?></p>
        </div>
    </div>
    <footer>
        &copy; 2024 SecuNX Web Application Firewall
    </footer>
</body>
</html>
EOL'

# 9. Set Permissions for the Custom 403 Error Page
print_msg "Setting permissions for the custom 403 error page..."
sudo chmod 644 /var/www/secuNX/secuNX_403.php
sudo chown www-data:www-data /var/www/secuNX/secuNX_403.php

# 10. Set Up the Cron Job for Automated Updates
print_msg "Setting up the cron job for automated blocklist updates..."
CRON_JOB="0 0 * * * /usr/local/bin/update_blocklist.sh >> /var/log/update_blocklist.log 2>&1"
(crontab -l 2>/dev/null | grep -v "update_blocklist.sh"; echo "$CRON_JOB") | crontab -
echo "Cron job added: $CRON_JOB"

# 11. Final Message
print_msg "Installation complete! Please ensure you manually configure your Nginx server blocks as per the README instructions."
print_msg "Don't forget to replace 'YOUR_ABUSEIPDB_API_KEY' in /usr/local/bin/update_blocklist.sh with your actual AbuseIPDB API key."
print_msg "Additionally, review and update the whitelist and blocklist configurations to suit your needs."