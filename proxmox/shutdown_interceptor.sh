#!/bin/bash
# Created by Patrick Stuart
# (c) 2025 All rights reserved.
#
###############################################
#### Reboot / Poweroff Interception Script#####
###############################################
# Explanation of the Script:
#  1. Command Handling: The script prompts the user to choose between reboot or poweroff. It sets the action variable accordingly.
#  2. Countdown Function: The countdown_timer function executes either the reboot or poweroff command based on the value of the action variable.
#  3. User Confirmation: The script asks for confirmation before proceeding with the action. If the user chooses to proceed, it starts the countdown with the appropriate action message.
#  4. Stopping the Action: Users can stop the countdown and cancel the action by pressing any key.
#
# Usage:
# nano /etc/profile.d/confirm-shutdown.sh
      # alias shutdown="/usr/local/bin/confirm /sbin/shutdown"
# nano /etc/profile.d/confirm-reboot.sh
      # alias reboot="/usr/local/bin/confirm /sbin/reboot

#  1. Save the script to a file, e.g., shutdown_interceptor.sh in the directory /usr/local/bin
#  2. Make it executable with the command: chmod +x shutdown_interceptor.sh.
#  3. To use this script instead of the standard reboot and poweroff commands, you can create aliases in your shell configuration (like .bashrc or .zshrc):
#         alias reboot='/usr/local/bin/shutdown_interceptor.sh'
#         alias poweroff='/usr/local/bin/shutdown_interceptor.sh'
# ________
#  OR 
#  3. Create a file in /etc/profile.d directory called
#          confirm-reboot.sh
#    alias reboot='/usr/local/bin/shutdown_interceptor.sh'
#          confirm-shutdown.sh
#    alias poweroff='/usr/local/bin/shutdown_interceptor.sh'
#          
# After saving the changes, make sure to source your configuration file or restart your terminal.
# Now, when the reboot or poweroff command is issued, this script will run, allowing for confirmation and a countdown timer before executing the desired action.
###############################################

###############################################
#####             Script Code             #####
###############################################

# Function to display the countdown timer with a progress bar
countdown_timer() {
  total_time=10
  for ((i=total_time; i>0; i--)); do
    # Calculate the percentage
    percent=$(( (total_time - i) * 100 / total_time ))

    # Create the progress bar
    progress_bar=""
    for ((j=0; j<percent/5; j++)); do
      progress_bar+="##"  # Two hashes for a solid block
    done
    for ((j=percent/5; j<20; j++)); do
      progress_bar+="  "  # Two spaces for empty blocks
    done

    # Print the timer and progress bar
    printf "\r%s in: %d seconds... [%s] %d%%" "$action" "$i" "$progress_bar" "$percent"
    sleep 1
  done

  # Execute the appropriate command
  if [[ "$action" == "Rebooting" ]]; then
    echo -e "\nExecuting /sbin/reboot command..."
    /sbin/reboot
  elif [[ "$action" == "Powering off" ]]; then
    echo -e "\nExecuting /sbin/poweroff command..."
    /sbin/poweroff
  fi
}

# Clear the screen
clear

# Prompt user for action
read -p "Do you want to reboot or power off? (reboot/poweroff): " command

# Set action based on user input
case "$command" in
  reboot)
    action="Rebooting"
    ;;
  poweroff)
    action="Powering off"
    ;;
  *)
    echo "Invalid command. Please enter 'reboot' or 'poweroff'."
    exit 1
    ;;
esac

# Display the action confirmation message
echo "The $action command has been set."
echo "You are about to execute the /sbin/$command command."
read -p "Do you want to proceed with the $action? (y/n): " response

# Check user input
case "$response" in
  [Yy][Ee][Ss]|[Yy])
    echo "$action is about to start..."
    
    # Create a subshell to handle the timer and key press detection
    {
      countdown_timer &
      timer_pid=$!

      # Wait for any key press
      read -n 1 -s -r -p "Press any key to stop the $action..."
      
      # Kill the timer if a key is pressed
      kill $timer_pid 2>/dev/null
      echo -e "\n$action command has been halted!"
    }
    ;;
  [Nn][Oo]|[Nn])
    echo "$action command has been halted."
    exit 0
    ;;
  *)
    echo "Invalid response. Please enter 'y' or 'n'."
    ;;
esac
