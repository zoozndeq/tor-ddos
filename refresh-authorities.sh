#!/bin/bash
set -e  # Exit on error

# Configuration
TMP_DIR="/var/tmp"
BASE_URL="https://raw.githubusercontent.com/Enkidu-6/tor-relay-lists/main"
TIMESTAMP_FILE="$TMP_DIR/tor_lists_timestamp"

# Function for downloads with error handling
download_list() {
    local list_name=$1
    local output_file=$2
    local append=${3:-false}
    
    echo "Downloading $list_name..."
    
    if [ "$append" = true ]; then
        curl -s -H 'Cache-Control: no-cache' "$BASE_URL/$list_name" | sed -e '1,3d' >> "$output_file"
    else
        curl -s -H 'Cache-Control: no-cache' "$BASE_URL/$list_name" | sed -e '1,3d' > "$output_file"
    fi
    
    # Check if download was successful and contains data
    if [ ! -s "$output_file" ]; then
        echo "ERROR: $list_name is empty or download failed"
        exit 1
    fi
}

# Function to update ipsets
update_ipset() {
    local ipset_name=$1
    local data_file=$2
    
    echo "Updating ipset: $ipset_name"
    /usr/sbin/ipset flush "$ipset_name" 2>/dev/null || echo "Note: ipset $ipset_name does not exist, creating it"
    for i in $(cat "$data_file"); do
        /usr/sbin/ipset add -exist "$ipset_name" "$i"
    done
}

# Function to count IPs in ipset safely
count_ips() {
    local ipset_name=$1
    local count=$(ipset list "$ipset_name" 2>/dev/null | grep -c '^[0-9]')
    if [ $? -eq 0 ] && [ $count -gt 0 ]; then
        echo $count
    else
        echo "0"
    fi
}

count_ips6() {
    local ipset_name=$1
    local count=$(ipset list "$ipset_name" 2>/dev/null | grep -c '^[0-9a-fA-F:]')
    if [ $? -eq 0 ] && [ $count -gt 0 ]; then
        echo $count
    else
        echo "0"
    fi
}

# Main Script
echo "=== Starting Tor Lists Update: $(date) ==="

# Clean up temporary files (if they exist)
/bin/rm -f /var/tmp/allow /var/tmp/allow6 /var/tmp/dual /var/tmp/dual6 /var/tmp/multi /var/tmp/multi6

# === Download ALL available lists ===

# IPv4 Allow lists (authorities + snowflake)
download_list "authorities-v4.txt" "/var/tmp/allow"
download_list "snowflake.txt" "/var/tmp/allow" true

# IPv6 Allow lists (authorities + snowflake) 
download_list "authorities-v6.txt" "/var/tmp/allow6"
download_list "snowflake-v6.txt" "/var/tmp/allow6" true

# Dual-Stack lists
download_list "2-or.txt" "/var/tmp/dual"
download_list "2-or-v6.txt" "/var/tmp/dual6"

# Multi-Address lists
download_list "above2-or.txt" "/var/tmp/multi"
download_list "above2-or-v6.txt" "/var/tmp/multi6"

# === Update ipsets ===

echo "Updating ipsets..."

# Main ipsets
update_ipset "allow-list" "/var/tmp/allow"
update_ipset "allow-list6" "/var/tmp/allow6"
update_ipset "dual-or" "/var/tmp/dual"
update_ipset "dual-or6" "/var/tmp/dual6"
update_ipset "multi-or" "/var/tmp/multi"
update_ipset "multi-or6" "/var/tmp/multi6"

# Cleanup
/bin/rm -f /var/tmp/allow /var/tmp/allow6 /var/tmp/dual /var/tmp/dual6 /var/tmp/multi /var/tmp/multi6

# Save timestamp
date +%Y%m%d > "$TIMESTAMP_FILE"

echo "=== Update successfully completed: $(date) ==="
echo "Statistics:"
echo "  allow-list: $(count_ips allow-list) IPs"
echo "  allow-list6: $(count_ips6 allow-list6) IPs"
echo "  dual-or: $(count_ips dual-or) IPs"
echo "  dual-or6: $(count_ips6 dual-or6) IPs"
echo "  multi-or: $(count_ips multi-or) IPs"
echo "  multi-or6: $(count_ips6 multi-or6) IPs"
