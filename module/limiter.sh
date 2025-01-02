#!/bin/bash

# Improved UDP limiter script
LIMIT_CONF="/etc/udp/limit.conf"
LOG_FILE="/var/log/udp-limit.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_limit() {
    if [ -f "$LIMIT_CONF" ]; then
        local ip=$1
        local current_connections=$(netstat -anp | grep :$port | grep ESTABLISHED | wc -l)
        local limit=$(grep "^$ip=" "$LIMIT_CONF" | cut -d= -f2)
        
        if [ -n "$limit" ] && [ "$current_connections" -ge "$limit" ]; then
            log "Connection limit reached for IP: $ip (Limit: $limit)"
            return 1
        fi
    fi
    return 0
}

# Main loop
while true; do
    if [ -f "$LIMIT_CONF" ]; then
        while read -r line; do
            ip=$(echo $line | cut -d= -f1)
            limit=$(echo $line | cut -d= -f2)
            check_limit "$ip"
        done < "$LIMIT_CONF"
    fi
    sleep 1
done
