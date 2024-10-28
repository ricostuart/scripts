#!/bin/bash 

# Check if the script is run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "   This script must be run as root. Please use sudo."
   exit 1
fi

# Function to center text and make it bold and red
center_text() {
    local text="$1"
    local width=$(tput cols)   # Get the width of the terminal
    local text_length=${#text}  # Get the length of the text
    local spaces=$(( (width - text_length) / 2 ))  # Calculate leading spaces
    # Print the centered text in bold red
    printf "\033[1;31m%${spaces}s%s\033[0m\n" "" "$text"  # Bold red text
}
# Function to print bold red text
bold_red_text() {
    local text="$1"
    printf "\033[1;31m%s\033[0m\n" "$text"  # Bold red text
}

# Function to clear the screen
setup_screen() {
    clear
}

# Function to get the color based on seconds remaining
get_color() {
    case $1 in
        10) echo "\033[1;32m" ;;  # Green
        9) echo "\033[1;32m" ;;  # Green
        8) echo "\033[1;32m" ;;  # Green
        7) echo "\033[1;32m" ;;  # Green
        6) echo "\033[1;33m" ;;  # Yellow
        5) echo "\033[1;33m" ;;  # Yellow
        4) echo "\033[1;33m" ;;  # Yellow
        3) echo "\033[1;31m" ;;  # Red
        2) echo "\033[1;31m" ;;  # Red
        1) echo "\033[1;31m" ;;  # Red
        0) echo "\033[1;31m" ;;  # Red
        *) echo "\033[0m" ;;     # Default
    esac
}

# Ask for confirmation
setup_screen
center_text "Proxmox Reboot Script!"  # Centered welcome message
read -p "   Do you want to reboot the system? (y/n): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "   Rebooting in 15 seconds..."

    # Countdown timer (in seconds)
    seconds_remaining=15  # Updated timer to 15 seconds
    total_time=$seconds_remaining
    col=$(tput cols)
    col=$((col - 5))

    while (( seconds_remaining > 0 )); do 
        clear 
        date "+%A, %d %B %Y | %I:%M %p"
        (( seconds_remaining-- )) 
        seconds=$((seconds_remaining % 60)) 

        echo "----------------------------------------------" 
        printf "\n"
        
        # Get the color based on the remaining seconds
        color=$(get_color $seconds)
        echo -e "   Seconds: ${color}$seconds\033[0m"  # Set color for seconds

        echo -n "   ["
        progress=$((total_time - seconds_remaining))
        _R=$((col * progress / total_time))
        printf "%${_R}s" | tr ' ' '='
        echo -n "]"

        # Print instruction to cancel underneath the progress bar
        printf "\n\n"
        bold_red_text "Press any key to cancel!"

        # Check for key press (non-blocking)
        read -t 1 -n 1 key
        if [[ $? -eq 0 ]]; then
            clear  # Clear the screen before displaying the cancel message
            center_text "   Countdown canceled!"  # Centered message
            sleep 0.2  # Wait for 0.2 seconds before clearing
            clear  # Clear the screen again
            exit 0
        fi
    done

    clear
    # Center and display "Rebooting..."
    center_text ""  # Centered message
    echo -e "\033[1;31m   !! !!! REBOOTING !!! !!\033[0m"  # Red color for rebooting message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;33m   !! !!! REBOOTING !!! !!\033[0m"  # Yellow color for rebooting message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;31m   !! !!! REBOOTING !!! !!\033[0m"  # Red color for rebooting message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;33m   !! !!! REBOOTING !!! !!\033[0m"  # Yellow color for rebooting message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;31m   !! !!! REBOOTING !!! !!\033[0m"  # Red color for rebooting message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;33m   !! !!! REBOOTING !!! !!\033[0m"  # Yellow color for rebooting message
    sleep 0.2  # Wait for 0.2 seconds before clearing

    # sleep 2  # Pause for 2 seconds before the next action

    # Echo "Reboot Placeholder" instead of rebooting
    echo "   Reboot Placeholder"

    printf "\n"

else
    clear  # Clear the screen before showing the cancel message
    echo -e "\033[1;32m   !! Reboot canceled !!\033[0m"  # Green color for canceled message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;33m   !! Reboot canceled !!\033[0m"  # Yellow color for canceled message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;32m   !! Reboot canceled !!\033[0m"  # Green color for canceled message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;33m   !! Reboot canceled !!\033[0m"  # Yellow color for canceled message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;32m   !! Reboot canceled !!\033[0m"  # Green color for canceled message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    clear  # Clear the screen again
    echo -e "\033[1;33m   !! Reboot canceled !!\033[0m"  # Yellow color for canceled message
    sleep 0.2  # Wait for 0.2 seconds before clearing
    exit 0
fi
