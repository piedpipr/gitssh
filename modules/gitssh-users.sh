#!/bin/sh

#================================================================#
# GIT-SSH USER MANAGEMENT MODULE
# Functions for managing user configurations
#================================================================#

#================================================================#
# USER MANAGEMENT FUNCTIONS
#================================================================#

# Add new user interactively for git inside user config file
user_add() {
    if ! _check_dependencies; then
        return 1
    fi
    
    # Handle CLI arguments
    cli_name=""
    cli_email=""
    cli_ssh_host=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)
                cli_name="$2"
                shift 2
                ;;
            --email)
                cli_email="$2"
                shift 2
                ;;
            --ssh-host)
                cli_ssh_host="$2"
                shift 2
                ;;
            --help|-h)
                _show_user_add_help
                return 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    printf "Adding new Git user...\n\n"
    
    # Get username
    printf "Username (for SSH host github-<username>): "
    read -r username
    if _is_empty "$username"; then
        _print_error "Username cannot be empty"
        return 1
    fi
    
    if ! _validate_username "$username"; then
        _print_error "Username can only contain letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    if _user_exists "$username"; then
        _print_warning "User '$username' already exists"
        printf "Overwrite? (y/N): "
        read -r overwrite
        case "$overwrite" in
            [Yy]*) ;;
            *) printf "Cancelled\n"; return 0 ;;
        esac
    fi
    
    # Get display name
    if [ -n "$cli_name" ]; then
        display_name="$cli_name"
        printf "Display name: %s\n" "$display_name"
    else
        printf "Display name [%s]: " "$username"
        read -r display_name
        display_name=${display_name:-$username}
    fi
    
    # Get email
    if [ -n "$cli_email" ]; then
        email="$cli_email"
        printf "Email: %s\n" "$email"
    else
        printf "Email address: "
        read -r email
    fi
    
    if _is_empty "$email"; then
        _print_error "Email cannot be empty"
        return 1
    fi
    
    if ! _validate_email "$email"; then
        _print_error "Invalid email format"
        return 1
    fi
    
    # Get SSH host
    if [ -n "$cli_ssh_host" ]; then
        ssh_host="$cli_ssh_host"
        printf "SSH host: %s\n" "$ssh_host"
    else
        printf "SSH host [github-%s]: " "$username"
        read -r ssh_host
        ssh_host=${ssh_host:-github-$username}
    fi
    
    printf "\nSummary:\n"
    printf "  Username:  %s\n" "$username"
    printf "  Name:      %s\n" "$display_name"
    printf "  Email:     %s\n" "$email"
    printf "  SSH Host:  %s\n" "$ssh_host"
    printf "\n"
    
    printf "Add this user? (Y/n): "
    read -r confirm
    case "$confirm" in
        [Nn]*) printf "Cancelled\n"; return 0 ;;
    esac
    
    # Add user to config
    if _add_user_to_config "$username" "$display_name" "$email" "$ssh_host"; then
        _print_success "Added user '$username'"
        
        # Test SSH connection
        printf "Testing SSH connection...\n"
        if _test_ssh_connection "$ssh_host" 5; then
            _print_success "SSH connection successful!"
        else
            _print_warning "SSH connection failed - check your SSH config and keys"
            printf "Make sure ~/.ssh/config has an entry for '%s'\n" "$ssh_host"
        fi
    else
        _print_error "Failed to add user to configuration"
        return 1
    fi
}

# Remove user interactively
user_remove() {
    if ! _check_dependencies; then
        return 1
    fi
    
    # Handle direct user argument
    if [ $# -gt 0 ]; then
        target_user="$1"
        if _user_exists "$target_user"; then
            printf "Remove user '%s'? (y/N): " "$target_user"
            read -r confirm
            case "$confirm" in
                [Yy]*) 
                    if _remove_user_from_config "$target_user"; then
                        _print_success "Removed user '$target_user'"
                    else
                        _print_error "Failed to remove user"
                        return 1
                    fi
                    ;;
                *) 
                    printf "Cancelled\n"
                    return 0
                    ;;
            esac
        else
            _print_error "User '$target_user' not found"
            return 1
        fi
        return 0
    fi
    
    # Interactive mode
    users=$(_get_configured_users)
    if [ -z "$users" ]; then
        _print_info "No users configured"
        printf "Use 'gitssh user add' to add users first\n"
        return 1
    fi
    
    printf "Remove Git user...\n"
    printf "Available users:\n"
    i=1
    for user in $users; do
        user_details=$(_get_user_details "$user")
        name=$(printf "%s" "$user_details" | jq -r '.name')
        email=$(printf "%s" "$user_details" | jq -r '.email')
        printf "  %d. %s (%s <%s>)\n" "$i" "$user" "$name" "$email"
        i=$((i + 1))
    done
    printf "\n"
    
    while true; do
        printf "Select user to remove (1-%d): " "$((i-1))"
        read -r choice
        if [ "$choice" -ge 1 ] && [ "$choice" -le "$((i-1))" ] 2>/dev/null; then
            break
        fi
        printf "Invalid choice\n"
    done
    
    selected_user=$(printf "%s" "$users" | sed -n "${choice}p")
    printf "This will remove user '%s'\n" "$selected_user"
    printf "Are you sure? (y/N): "
    read -r confirm
    
    case "$confirm" in
        [Yy]*) 
            if _remove_user_from_config "$selected_user"; then
                _print_success "Removed user '$selected_user'"
            else
                _print_error "Failed to remove user from configuration"
                return 1
            fi
            ;;
        *) 
            printf "Cancelled\n"
            return 0
            ;;
    esac
}

# List configured users with detailed information
user_list() {
    if ! _check_dependencies; then
        return 1
    fi
    
    # Handle options
    simple_mode=false
    case "$1" in
        --simple|-s)
            simple_mode=true
            ;;
    esac
    
    users=$(_get_configured_users)
    
    if [ -z "$users" ]; then
        printf "No users configured\n"
        printf "Use 'gitssh user add' to add users\n"
        return 0
    fi
    
    if [ "$simple_mode" = "true" ]; then
        # Simple output for scripting
        printf "%s\n" "$users"
        return 0
    fi
    
    # Detailed output
    printf "Configured Git Users:\n"
    printf "========================\n"
    
    for username in $users; do
        user_details=$(_get_user_details "$username")
        name=$(printf "%s" "$user_details" | jq -r '.name')
        email=$(printf "%s" "$user_details" | jq -r '.email')
        ssh_host=$(printf "%s" "$user_details" | jq -r '.ssh_host')
        
        printf "%s\n" "$username"
        printf "   Name:     %s\n" "$name"
        printf "   Email:    %s\n" "$email"
        printf "   SSH Host: %s\n" "$ssh_host"
        
        # Test SSH connection
        if _test_ssh_connection "$ssh_host" 2; then
            _print_color green "   Status:   SSH Connected"
            printf "\n"
        else
            _print_color red "   Status:   SSH Failed"
            printf "\n"
        fi
        printf "\n"
    done
}

# Show current git and SSH status
user_status() {
    printf "==================================\n"
    printf "Current Git Configuration:\n"
    global_name=$(_get_git_config "user.name" "global")
    global_email=$(_get_git_config "user.email" "global")
    printf "  Global Name:  %s\n" "${global_name:-Not set}"
    printf "  Global Email: %s\n" "${global_email:-Not set}"
    
    if _is_git_repo; then
        local_name=$(_get_git_config "user.name" "local")
        local_email=$(_get_git_config "user.email" "local")
        printf "  Local Name:   %s\n" "${local_name:-Not set}"
        printf "  Local Email:  %s\n" "${local_email:-Not set}"
        
        effective_user=$(_get_effective_git_user)
        printf "  Effective:    %s\n" "$effective_user"
    fi
    
    printf "==================================\n"
    printf "SSH Agent Status:\n"
    if _is_ssh_agent_running; then
        _print_success "SSH Agent is running"
        printf "Loaded SSH keys:\n"
        _get_loaded_ssh_keys | sed 's/^/  /'
    else
        _print_warning "SSH Agent not running or no keys loaded"
    fi
    
    printf "==================================\n"
    printf "Testing GitHub connections:\n"
    hosts=$(_get_ssh_hosts)
    if [ -n "$hosts" ]; then
        for host in $hosts; do
            if _test_ssh_connection "$host" 3; then
                _print_color green "%s: Connected" "$host"
                printf "\n"
            else
                _print_color red "%s: Failed" "$host"
                printf "\n"
            fi
        done
    else
        printf "No GitHub SSH hosts found in ~/.ssh/config\n"
    fi
    printf "==================================\n"
}

# Switch to Another User (Local/Repository-specific by default)
user_switch() {
    if [ $# -eq 0 ]; then
        printf "Error: Username required\n"
        printf "Usage: gitssh user switch <username>\n"
        printf "       gitssh user switch -g <username>  (global)\n"
        printf "Available users:\n"
        user_list --simple | sed 's/^/  /'
        return 1
    fi
    
    # Check for global flag
    global_flag=false
    if [ "$1" = "-g" ] || [ "$1" = "--global" ]; then
        global_flag=true
        shift
        if [ $# -eq 0 ]; then
            printf "Error: Username required after -g flag\n"
            return 1
        fi
    fi
    
    username="$1"
    
    if ! _user_exists "$username"; then
        _print_error "User '$username' not found"
        printf "Available users:\n"
        user_list --simple | sed 's/^/  /'
        return 1
    fi
    
    # Get user details
    user_details=$(_get_user_details "$username")
    name=$(printf "%s" "$user_details" | jq -r '.name')
    email=$(printf "%s" "$user_details" | jq -r '.email')
    ssh_host=$(printf "%s" "$user_details" | jq -r '.ssh_host')
    
    if [ "$global_flag" = "true" ]; then
        # Switch globally
        git config --global user.name "$name"
        git config --global user.email "$email"
        _print_success "Switched to $username globally"
        printf "  Name: %s\n" "$name"
        printf "  Email: %s\n" "$email"
        printf "  SSH Host: %s\n" "$ssh_host"
    else
        # Switch locally (repository-specific)
        if ! _is_git_repo; then
            _print_error "Not in a Git repository"
            printf "Use 'gitssh user switch -g $username' for global switch\n"
            return 1
        fi
        
        git config user.name "$name"
        git config user.email "$email"
        _print_success "Switched to $username for this repository"
        printf "  Repository: $(basename "$(pwd)")\n"
        printf "  Name: %s\n" "$name"
        printf "  Email: %s\n" "$email"
        printf "  SSH Host: %s\n" "$ssh_host"
    fi
    
    # Test SSH connection
    printf "Testing SSH connection...\n"
    if _test_ssh_connection "$ssh_host" 3; then
        _print_success "SSH connection verified"
    else
        _print_warning "SSH connection failed - check SSH setup"
    fi
}

# Helper function to check if current directory is a Git repository
_is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Simple user list for other commands
user_list_simple() {
    if _check_dependencies 2>/dev/null; then
        _get_configured_users
    fi
}
#================================================================#
# PRIVATE HELPER FUNCTIONS
#================================================================#

# Add user to configuration file
_add_user_to_config() {
    username="$1"
    name="$2"
    email="$3"
    ssh_host="$4"
    
    temp_file=$(_create_temp_file)
    if jq --arg username "$username" \
       --arg name "$name" \
       --arg email "$email" \
       --arg ssh_host "$ssh_host" \
       '.users[$username] = {"name": $name, "email": $email, "ssh_host": $ssh_host}' \
       "$GIT_SSH_USERS_FILE" > "$temp_file"; then
        _safe_file_replace "$temp_file" "$GIT_SSH_USERS_FILE"
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Remove user from configuration file
_remove_user_from_config() {
    username="$1"
    
    temp_file=$(_create_temp_file)
    if jq --arg username "$username" 'del(.users[$username])' "$GIT_SSH_USERS_FILE" > "$temp_file"; then
        _safe_file_replace "$temp_file" "$GIT_SSH_USERS_FILE"
    else
        rm -f "$temp_file"
        return 1
    fi
}

#================================================================#
# GLOBAL SWITCHING FUNCTIONS
#================================================================#

# Create dynamic global switch functions
_create_global_functions() {
    if ! _check_dependencies 2>/dev/null; then
        return 1
    fi
    
    # Create a script file with all the switch functions
    switch_functions_file="/tmp/git-switch-functions-$$"
    
    users=$(_get_configured_users 2>/dev/null)
    for username in $users; do
        user_details=$(_get_user_details "$username")
        if [ -n "$user_details" ]; then
            name=$(printf "%s" "$user_details" | jq -r '.name')
            email=$(printf "%s" "$user_details" | jq -r '.email')
            ssh_host=$(printf "%s" "$user_details" | jq -r '.ssh_host')
            
            # Write function to file
            cat >> "$switch_functions_file" << EOF
git_switch_${username}() {
    git config --global user.name '$name'
    git config --global user.email '$email'
    
    printf 'Switched to $username account globally\n'
    printf 'Testing SSH connection...\n'
    if _test_ssh_connection '$ssh_host' 5; then
        _print_success 'SSH connection successful!'
    else
        _print_warning 'SSH connection failed'
    fi
    
    printf 'Current Global Git config:\n'
    printf '  Name: %s\n' "\$(_get_git_config "user.name" "global")"
    printf '  Email: %s\n' "\$(_get_git_config "user.email" "global")"
}

EOF
        fi
    done
    
    # Source the functions if file was created
    if [ -f "$switch_functions_file" ] && [ -s "$switch_functions_file" ]; then
        . "$switch_functions_file"
        rm -f "$switch_functions_file"
    fi
}

_show_user_add_help() {
    printf "Usage: gitssh user add [options]\n\n"
    printf "Options:\n"
    printf "  --name <name>       Full display name\n"
    printf "  --email <email>     Email address\n"
    printf "  --ssh-host <host>   SSH hostname\n"
    printf "  --help              Show this help\n\n"
    printf "Interactive mode runs when no options provided.\n"
}