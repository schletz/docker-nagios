#! /bin/bash

# Read the IP address from the output of the route command
GW_IP=$(route | grep default | sed -E 's/default\s+([0-9\.]+).*/\1/')
# Use existing ping command to check.
/opt/nagios/libexec/check_ping -H $GW_IP -w 3000.0,80% -c 5000.0,100% -p 5
