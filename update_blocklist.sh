#!/bin/bash

# ----------------------------
# Script: update_blocklist.sh
# Purpose: Automatically update Nginx blocklist.conf with malicious IPs from multiple sources, including Tor exit nodes
#          and clean up backup files older than 1 month.
# ----------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
BLOCKLIST_CONF="/etc/nginx/secuNX/blocklist.conf"
WHITELIST_CONF="/etc/nginx/secuNX/whitelist.conf"
TEMP_BLOCKLIST="/tmp/blocklist_temp.conf"
BACKUP_DIR="/etc/nginx/secuNX/blocklist_backups"
ABUSEIPDB_API_KEY="YOUR_ABUSEIPDB_API_KEY"  # Replace with your AbuseIPDB API key
ABUSEIPDB_THRESHOLD=50  # Minimum number of reports to consider
ABUSEIPDB_URL="https://api.abuseipdb.com/api/v2/blacklist"
TOR_EXIT_NODES_URL="https://check.torproject.org/torbulkexitlist"  # URL to fetch Tor exit node IPs

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
    RESPONSE=$(curl -s -G "$ABUSEIPDB_URL" \
        --data-urlencode "maxAgeInDays=90" \
        --data-urlencode "confidenceMinimum=$ABUSEIPDB_THRESHOLD" \
        -H "Key: $ABUSEIPDB_API_KEY" \
        -H "Accept: application/json")

    # Save the response to a file
    echo "$RESPONSE" > /tmp/abuseipdb.json

    # Check if 'data' exists and is not null
    DATA_EXISTS=$(echo "$RESPONSE" | jq '.data // empty')

    if [ -z "$DATA_EXISTS" ]; then
        # Extract error message if available
        ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.errors[0].detail // .meta.error // "Unknown error"')
        echo "Error fetching AbuseIPDB: $ERROR_MESSAGE"
        # Exit the script or decide to proceed without AbuseIPDB data
        return 1
    fi

    # Extract IPs
    jq -r '.data[] | .ipAddress' /tmp/abuseipdb.json > /tmp/abuseipdb.txt
    echo "Fetched $(wc -l < /tmp/abuseipdb.txt) IPs from AbuseIPDB."
}

# Function to fetch Tor Exit Nodes
fetch_tor_exit_nodes() {
    echo "Fetching Tor Exit Nodes..."
    curl -s "$TOR_EXIT_NODES_URL" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' > /tmp/tor_exit_nodes.txt
    echo "Fetched $(wc -l < /tmp/tor_exit_nodes.txt) Tor Exit Node IPs."
}

# Function to merge and deduplicate IPs, excluding whitelisted IPs
merge_blocklists() {
    echo "Merging blocklists and excluding whitelisted IPs..."
    cat /tmp/blocklist_de.txt /tmp/abuseipdb.txt /tmp/tor_exit_nodes.txt | sort | uniq > /tmp/merged_blocklist.txt

    # Remove whitelisted IPs
    for ip in "${WHITELIST_IPS[@]}"; do
        grep -v "^$ip\$" /tmp/merged_blocklist.txt > /tmp/merged_blocklist_tmp.txt
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
    nginx -t
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        if [ $? -eq 0 ]; then
            echo "Nginx reloaded successfully."
        else
            echo "Nginx reload failed. Restoring from backup."
            cp "$BACKUP_DIR/blocklist.conf.$TIMESTAMP.bak" "$BLOCKLIST_CONF"
            systemctl reload nginx
            exit 1
        fi
    else
        echo "Nginx configuration test failed. Restoring from backup."
        cp "$BACKUP_DIR/blocklist.conf.$TIMESTAMP.bak" "$BLOCKLIST_CONF"
        exit 1
    fi
}

# Function to clean up old backups older than 1 month
cleanup_old_backups() {
    echo "Cleaning up backup files older than 1 month..."
    find "$BACKUP_DIR" -type f -name "blocklist.conf.*.bak" -mtime +30 -exec rm -f {} \;
    echo "Old backup files deleted."
}

# Main Execution Flow
fetch_blocklist_de
if fetch_abuseipdb; then
    echo "AbuseIPDB fetch succeeded."
else
    echo "AbuseIPDB fetch failed. Proceeding without AbuseIPDB data."
fi
fetch_tor_exit_nodes
merge_blocklists
format_for_nginx
backup_existing_blocklist
update_blocklist_conf
reload_nginx
cleanup_old_backups

# Clean up temporary files
rm -f /tmp/blocklist_de.txt /tmp/abuseipdb.json /tmp/abuseipdb.txt /tmp/tor_exit_nodes.txt /tmp/merged_blocklist.txt /tmp/blocklist_temp.conf

echo "Blocklist update process completed."
