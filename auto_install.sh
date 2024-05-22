#!/bin/bash

# Execute Me: curl -s https://raw.githubusercontent.com/clustervision/trinityx/main/auto_install.sh | bash
# Execute Me [DEV]: curl --insecure -s https://gitlab.taurusgroup.one/clustervision/trinityx-combined/-/raw/cloud_init/auto_install.sh | bash

# Function to display usage message
usage() {
    echo
    echo "+------------------------------------------------------------+"
    echo "|                                                            |"
    echo "|              Welcome to TrinityX                           |"
    echo "|                                                            |"
    echo "| Usage: auto_install.sh [installation_type]                 |"
    echo "| Installation types:                                        |"
    echo "|   1: Ansible Installation (Default)                        |"
    echo "|   2: TUI Installation                                      |"
    echo "|   3: GUI Installation                                      |"
    echo "|                                                            |"
    echo "+------------------------------------------------------------+"
    echo
}

installation_procedure() {
    echo
    echo "+------------------------------------------------------------+"
    echo "|                                                            |"
    echo "|              TrinityX Installation                         |"
    echo "|                                                            |"
    echo "| Set the host in file trinityx      /hosts                  |"
    echo "| Set the variables under the trinityx      /group_vars/     |"
    echo "| According to the Cloud Providers available files are...    |"
    echo "|   1. all.yml (Common file)                                 |"
    echo "|   2: azure.yml (Microsoft Azure Support)                   |"
    echo "|   3: aws.yml (Amazone Web Service Support)                 |"
    echo "|   4: gcp.yml (Google Cloud Platform Support)               |"
    echo "|                                                            |"
    echo "| After Setting the YAML files, execute:                     |"
    echo "| ansible-playbook cloud.yml                                 |"
    echo "|                                                            |"
    echo "+------------------------------------------------------------+"
    echo
}

# Function to check package manager and install git if needed
install_git_and_clone_repo() {
    # Check the package manager
    if command -v yum &>/dev/null; then
        echo "You have a package manager: yum"
    elif command -v dnf &>/dev/null; then
        echo "You have a package manager: dnf"
    elif command -v apt &>/dev/null; then
        echo "You have a package manager: apt"
    else
        echo "Unknown package manager."
        exit 1
    fi

    # Check if git is installed
    if ! command -v git &>/dev/null; then
        echo "Git is not installed. Installing..."
        # Install git based on the package manager
        if command -v yum &>/dev/null; then
            sudo yum install -y git
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y git
        elif command -v apt &>/dev/null; then
            sudo apt-get install -y git
        else
            echo "Cannot install git: Unknown package manager."
            exit 1
        fi
    fi

    # Check if the trinityX directory exists
    if [ -d "trinityX" ]; then
        echo "TrinityX directory already exists. Renaming..."
        mv trinityX "trinityX-$(date +"%Y%m%d%H%M%S")"
    fi

    # Clone the repository
    echo "Cloning TrinityX repository..."
    # GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone git@github.com:clustervision/trinityX.git trinityX
    GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone -c http.sslVerify=false git@gitlab.taurusgroup.one:clustervision/trinityx-combined.git trinityX

    cd trinityX/
    sh prepare.sh
    echo
    echo "TrinityX-Cloud is downloaded, Kindly Follow the installation procedure..."
    echo
    installation_procedure
}


# Counter for invalid inputs
invalid_input_count=0

# Check if --help option is provided
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
else
    usage
fi

# Check if an argument is provided
if [[ $# -eq 1 ]]; then
    # Check if the argument is a number and in the valid range (1, 2, or 3)
    if [[ $1 =~ ^[1-3]$ ]]; then
        choice=$1
    else
        echo "Invalid argument. Please specify a number between 1 and 3."
        usage
        exit 1
    fi
else
    # Loop until a valid number is entered or invalid attempts reach 3
    while true; do
        # read -n 1 -p "Kindly, select your installation type: (1, 2, 3) " choice # For Countinue Checking.
        read  -p "Kindly, select your installation type(Default is 1): (1, 2, 3)" choice
         # If user just hits Enter, set choice to 1
        if [[ -z "$choice" ]]; then
            choice=1
            break
        fi
        echo # Move to a new line after the user input
        # Check if the input is a number
        if [[ $choice =~ ^[0-9]$ ]]; then
            # Check if the number is in the valid range (1, 2, or 3)
            if (( choice >= 1 && choice <= 3 )); then
                break
            else
                echo "Invalid choice. Please select a number between 1 and 3."
                ((invalid_input_count++))
            fi
        else
            echo "Invalid input. Please enter a number."
            ((invalid_input_count++))
        fi
        
        # If invalid attempts reach 3, exit the program
        if (( invalid_input_count >= 3 )); then
            echo "Too many invalid inputs. Exiting."
            exit 1
        fi
    done
fi


case $choice in
    1)
        echo "TrinityX installation type selected: Ansible Installation (Default)"
        install_git_and_clone_repo
        ;;
    2)
        echo "TrinityX installation type selected: TUI Installation"
        echo
        echo "TUI Installation is in Development, It will be available from 01 August 2024 onwards."
        ;;
    3)
        echo "TrinityX installation type selected: GUI Installation"
        echo
        echo "GUI Installation is in Development, It will be available from 01 August 2024 onwards."
        ;;
    *)
        echo "Invalid choice. Please select 1, 2, or 3."
        ;;
esac
