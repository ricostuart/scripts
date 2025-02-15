#!/bin/bash
#
# Created by Patrick Stuart
# (c) 2025 All rights reserved.
#
###############################################
#### Reboot / Poweroff Interception Script#####
###############################################
# How the Updated Script Works
# Countdown Timer with Progress Bar:
#
# The countdown timer runs for 10 seconds and updates the progress bar every second.
# The progress bar consists of = symbols indicating the elapsed time relative to the total countdown time.
# The remaining seconds are displayed alongside the progress bar.
# Interrupt Functionality:
#
# During the countdown, if the user presses any key, the countdown is interrupted, and a message is displayed.
# Steps to Use the Updated Script
# Save the code into a file named:
#    /usr/local/bin/shutdown_interceptor
# Make it executable:
#    chmod +x /usr/local/bin/shutdown_interceptor
#
# Set up the aliases as previously described to ensure that the reboot and poweroff commands use this script.
# Reload your shell configuration:
#    source ~/.bashrc
#
# Example Output
# When you execute the reboot or poweroff command, the script will prompt for confirmation and then display the countdown timer with a progress bar like this:
#
#         Starting in 10 seconds...
#         [==========          ]  5 seconds remaining
#
# With this implementation, you now have a user-friendly countdown timer that visually indicates how much time is left before the command executes.
#_______
#
# Usage:
# nano /etc/profile.d/confirm-shutdown.sh
#       alias poweroff='/usr/local/bin/shutdown_interceptor poweroff'
# nano /etc/profile.d/confirm-reboot.sh
#       alias reboot='/usr/local/bin/shutdown_interceptor reboot'
#
#  1. Save the script to a file, e.g., shutdown_interceptor in the directory /usr/local/bin
#  2. Make it executable with the command: chmod +x shutdown_interceptor.
#  3. To use this script instead of the standard reboot and poweroff commands, you can create aliases in your shell configuration:
#       alias poweroff='/usr/local/bin/shutdown_interceptor poweroff'
#       alias reboot='/usr/local/bin/shutdown_interceptor reboot'

# ________
#  OR
#  3. Create a file in /etc/profile.d directory called
#          confirm-reboot.sh
#    alias reboot='/usr/local/bin/shutdown_interceptor'
#          confirm-shutdown.sh
#    alias poweroff='/usr/local/bin/shutdown_interceptor'
#
# After saving the changes, make sure to source your configuration file or restart your terminal.
# Now, when the reboot or poweroff command is issued, this script will run, allowing for confirmation and a countdown timer before executing the desired action.
#

###############################################
#####             Script Code             #####
###############################################

# Function to display a countdown timer with a progress bar that can be interrupted
countdown_timer() {
    local duration=10
    local interval=1
    local progress=0
    local bar_length=20

    # Determine the action based on the command
    if [[ "$1" == "reboot" ]]; then
        action="Rebooting"
    elif [[ "$1" == "poweroff" ]]; then
        action="Powering Off"
    else
        echo "Unknown command."
        exit 1
    fi

    echo -n "$action in $duration seconds..."
    echo ""

    for (( i=0; i<duration; i+=interval )); do
        # Calculate progress
        progress=$(( (i + interval) * bar_length / duration ))
        
        # Display the progress bar
        printf "\r["
        for (( j=0; j<bar_length; j++ )); do
            if [ $j -lt $progress ]; then
                printf "="
            else
                printf " "
            fi
        done
        printf "] %d seconds remaining" $(( duration - (i + interval) ))
        
        sleep $interval

        # Check for user input to interrupt
        if read -t 0.1 -n 1 key; then
            echo -e "\n\nCountdown interrupted by user."
            exit 1
        fi
    done
    echo -e "\nTime's up! Executing command..."
}

# Clear the screen
clear

# Display hostname
echo "*****"
hostname
echo "*****"

# Confirm the command
echo "You are about to execute: $1"
read -p "Are you sure you want to continue? (y/n): " reply

# New line added here
echo ""

if [[ "$reply" =~ ^[Yy]$ ]]; then
    countdown_timer "$1"
    # Execute the original command
    exec "$@"
else
    echo "$1 command has been stopped."
fi
