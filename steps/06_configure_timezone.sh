#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Configuring timezone
# ONFAIL=Failed to set timezone. You can set it manually later with timedatectl.

echo "Setting timezone to $TIMEZONE..."
sleep 1
echo "Syncing hardware clock..."
sleep 1

exit 0
