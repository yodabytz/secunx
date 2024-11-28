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
ABUSEIPDB_API_KEY="a6666cfdbbbea3690f4ae848961e943ddf0293157fa9ad0b3e1de4e420f28c9bc3027c425f14100f"  # Replace with your AbuseIPDB API key
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
    echo "Fetched $(wc -l < /tmp/blocklist_de.txt) IPs from Blocklist.de."
}

# Function to fetch AbuseIPDB
fetch_abuseipdb() {
    echo "Fetching AbuseIPDB..."
    curl -s -G "$ABUSEIPDB_URL" \
        --data-urlencode "maxAgeInDays=90" \
        --data-urlencode "confidenceMinimum=$ABUSEIPDB_THRESHOLD" \
        -H "Key: $ABUSEIPDB_API_KEY" \
        -H "Accept: application/json" \
        > /tmp/abuseipdb.json

    # Extract IPs
    jq -r '.data[] | .ipAddress' /tmp/abuseipdb.json > /tmp/abuseipdb.txt
    echo "Fetched $(wc -l < /tmp/abuseipdb.txt) IPs from AbuseIPDB."
}

# Function to merge and deduplicate IPs, excluding whitelisted IPs
merge_blocklists() {
    echo "Merging blocklists and excluding whitelisted IPs..."
    cat /tmp/blocklist_de.txt /tmp/abuseipdb.txt | sort | uniq > /tmp/merged_blocklist.txt

    # Remove whitelisted IPs
    for ip in "${WHITELIST_IPS[@]}"; do
        grep -v "^$ip$" /tmp/merged_blocklist.txt > /tmp/merged_blocklist_tmp.txt
        mv /tmp/merged_blocklist_tmp.txt /tmp/merged_blocklist.txt
    done

    echo "Total unique IPs after excluding whitelisted IPs: $(wc -l < /tmp/merged_blocklist.txt)"
}

# Function to format IPs for Nginx
format_for_nginx() {
    echo "Formatting IPs for Nginx..."
    awk '{print "deny " $1 ";"}' /tmp/merged_blocklist.txt > "$TEMP_BLOCKLIST"
}

# Function to backup existing blocklist
backup_existing_blocklist() {
    TIMESTAMP=$(date +%F_%T)
    echo "Backing up existing blocklist.conf to $BACKUP_DIR/blocklist.conf.$TIMESTAMP.bak"
    cp "$BLOCKLIST_CONF" "$BACKUP_DIR/blocklist.conf.$TIMESTAMP.bak"
}

# Function to update blocklist.conf
update_blocklist_conf() {
    echo "Updating blocklist.conf..."
    cp "$TEMP_BLOCKLIST" "$BLOCKLIST_CONF"
    echo "blocklist.conf updated successfully."
}

# Function to reload Nginx
reload_nginx() {
    echo "Reloading Nginx to apply changes..."
    nginx -t && systemctl reload nginx
    if [ $? -eq 0 ]; then
        echo "Nginx reloaded successfully."
    else
        echo "Nginx reload failed. Restoring from backup."
        cp "$BACKUP_DIR/blocklist.conf.$TIMESTAMP.bak" "$BLOCKLIST_CONF"
        systemctl reload nginx
    fi
}

# Main Execution Flow
fetch_blocklist_de
fetch_abuseipdb
merge_blocklists
format_for_nginx
backup_existing_blocklist
update_blocklist_conf
reload_nginx

# Clean up temporary files
rm -f /tmp/blocklist_de.txt /tmp/abuseipdb.json /tmp/abuseipdb.txt /tmp/merged_blocklist.txt /tmp/blocklist_temp.conf

echo "Blocklist update process completed."
