## 📄 Apache Configuration Directives
Add the following directives within your `<VirtualHost>, <Directory>`, or appropriate context in your Apache configuration file:
```
# Custom 403 Error Page
ErrorDocument 403 /secuNX_403.php

# Whitelist Configuration
<RequireAny>
    Include /etc/apache2/secuNX/whitelist.conf
</RequireAny>

# Blocklist Configuration
<RequireAll>
    Require all granted
    Include /etc/apache2/secuNX/blocklist.conf
</RequireAll>
```
## 📂 File Structure and Locations
### Whitelist File (whitelist.conf):

`Path: /etc/apache2/secuNX/whitelist.conf`

#### Content:
```
Require ip 127.0.0.1
Require ip ::1
Require ip 203.0.113.5
Require ip 198.51.100.10
# Add more whitelisted IPs or ranges as needed
```

## Blocklist File (blocklist.conf):

`Path: /etc/apache2/secuNX/blocklist.conf`
#### Content:
```
Require not ip 107.189.13.253
Require not ip 192.0.2.1
Require not ip 198.51.100.23
Require not ip YOUR.TOR.IP.ADDRESS
# Add more blocklisted IPs as needed
```

## 🛠️ Steps to Implement
#### Create the Directory Structure:

Ensure that the directory /etc/apache2/secuNX/ exists. If not, create it:

`sudo mkdir -p /etc/apache2/secuNX`

#### Create and Populate whitelist.conf:
```
sudo bash -c 'cat > /etc/apache2/secuNX/whitelist.conf <<EOL
Require ip 127.0.0.1
Require ip ::1
Require ip 203.0.113.5
Require ip 198.51.100.10
# Add more whitelisted IPs or ranges as needed
EOL'
```
* Note: Replace YOUR.TOR.IP.ADDRESS with the actual Tor exit node IP addresses you intend to block. You can automate updating this file using scripts similar to the Nginx setup.

#### Update Your Apache Virtual Host Configuration:

Open your site's virtual host file, typically located in /etc/apache2/sites-available/yourdomain.conf, and add the previously mentioned directives within the appropriate context.
```
sudo nano /etc/apache2/sites-available/yourdomain.conf
```
Insert the directives:
```
<VirtualHost *:80>
    ServerName yourdomain.com
    DocumentRoot /var/www/yourdomain

    # Custom 403 Error Page
    ErrorDocument 403 /secuNX_403.php

    # Whitelist Configuration
    <RequireAny>
        Include /etc/apache2/secuNX/whitelist.conf
    </RequireAny>

    # Blocklist Configuration
    <RequireAll>
        Require all granted
        Include /etc/apache2/secuNX/blocklist.conf
    </RequireAll>

    # PHP Handling (if not already configured)
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.3-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    # Other configurations...
</VirtualHost>
```
## Restart Apache to Apply Changes:
```
sudo apachectl configtest
sudo systemctl reload apache2
```

## 📋 Summary of Changes
#### Dynamic IP Lists: 
By separating whitelisted and blocklisted IPs into whitelist.conf and blocklist.conf, you can easily manage and update these lists without modifying the main Apache configuration.

#### Include Directives: 
The Include directive allows Apache to incorporate external configuration files, making your setup modular and maintainable.

## Access Control Logic:

<RequireAny> with Include /etc/apache2/secuNX/whitelist.conf ensures that any request from a whitelisted IP is granted access.

<RequireAll> with Require all granted and Include /etc/apache2/secuNX/blocklist.conf ensures that all other requests are granted unless they match a blocklisted IP.

## 🧪 Testing Your Configuration
#### Verify Whitelisted IP Access:

From a whitelisted IP, attempt to access your website. You should have full access.

#### Verify Blocklisted IP Access:

From a blocklisted IP, attempt to access your website. You should receive the custom 403 error page.

#### Verify Non-listed IP Access:

From an IP not listed in either whitelist.conf or blocklist.conf, you should have normal access.

## 🔄 Automating Blocklist and Whitelist Updates
To keep your blocklist and whitelist up-to-date:

#### Scripts: 
Utilize scripts to fetch and update blocklist.conf and whitelist.conf as needed. Ensure these scripts handle synchronization and avoid duplication.

#### Cron Jobs: 
Schedule cron jobs to run these scripts at regular intervals, ensuring your IP lists are current without manual intervention.
