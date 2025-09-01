#!/bin/sh

#================================================================#
# GIT-SSH SETUP MODULE
# Interactive SSH key setup for GitHub and GitLab
#================================================================#

# Configuration
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_DIR="$HOME/.ssh"

#================================================================#
# MAIN SETUP COMMANDS
#================================================================#

# Setup GitHub SSH key
setup_github() {
    if ! _check_setup_dependencies; then
        return 1
    fi
    
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "    GitHub SSH Key Setup Wizard"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    _print_info "This wizard will help you set up SSH authentication for GitHub"
    printf "We'll guide you through each step with explanations.\n\n"
    
    # Step 1: Gather user information
    if ! _gather_github_info; then
        return 1
    fi
    
    # Step 2: Check existing SSH setup
    if ! _check_existing_ssh_setup "github"; then
        return 1
    fi
    
    # Step 3: Generate SSH key if needed
    if [ "$GENERATE_NEW_KEY" = "true" ]; then
        if ! _generate_ssh_key "github"; then
            return 1
        fi
    fi
    
    # Step 4: Configure SSH
    if ! _setup_ssh_config "github"; then
        return 1
    fi
    
    # Step 5: Add to SSH agent
    if ! _add_to_ssh_agent "github"; then
        return 1
    fi
    
    # Step 6: Display public key and guide user
    if ! _guide_github_key_addition; then
        return 1
    fi
    
    # Step 7: Test connection
    if ! _test_github_connection; then
        return 1
    fi
    
    # Step 8: Integration with Git-SSH Session Manager
    _integrate_with_session_manager "github"
    
    _print_success "GitHub SSH setup completed successfully!"
    printf "\n"
    _print_info "You can now use the Git-SSH Session Manager:"
    printf "  • Run 'git_user' to configure your identity for repositories\n"
    printf "  • Use 'git_clone', 'git_push', etc. for enhanced Git operations\n"
    printf "  • Run 'ssh_remote' to convert HTTPS repositories to SSH\n"
    printf "\n"
}

# Setup GitLab SSH key
setup_gitlab() {
    if ! _check_setup_dependencies; then
        return 1
    fi
    
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "    GitLab SSH Key Setup Wizard"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    _print_info "This wizard will help you set up SSH authentication for GitLab"
    printf "We'll guide you through each step with explanations.\n\n"
    
    # Step 1: Gather user information
    if ! _gather_gitlab_info; then
        return 1
    fi
    
    # Step 2: Check existing SSH setup
    if ! _check_existing_ssh_setup "gitlab"; then
        return 1
    fi
    
    # Step 3: Generate SSH key if needed
    if [ "$GENERATE_NEW_KEY" = "true" ]; then
        if ! _generate_ssh_key "gitlab"; then
            return 1
        fi
    fi
    
    # Step 4: Configure SSH
    if ! _setup_ssh_config "gitlab"; then
        return 1
    fi
    
    # Step 5: Add to SSH agent
    if ! _add_to_ssh_agent "gitlab"; then
        return 1
    fi
    
    # Step 6: Display public key and guide user
    if ! _guide_gitlab_key_addition; then
        return 1
    fi
    
    # Step 7: Test connection
    if ! _test_gitlab_connection; then
        return 1
    fi
    
    # Step 8: Integration with Git-SSH Session Manager
    _integrate_with_session_manager "gitlab"
    
    _print_success "GitLab SSH setup completed successfully!"
    printf "\n"
    _print_info "You can now use the Git-SSH Session Manager:"
    printf "  • Run 'git_user' to configure your identity for repositories\n"
    printf "  • Use 'git_clone', 'git_push', etc. for enhanced Git operations\n"
    printf "  • Run 'ssh_remote' to convert HTTPS repositories to SSH\n"
    printf "\n"
}

# Show SSH setup status
ssh_status() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "    SSH Setup Status"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    # Check SSH directory
    printf "SSH Directory Status:\n"
    if [ -d "$SSH_DIR" ]; then
        _print_success "SSH directory exists: $SSH_DIR"
        printf "  Permissions: %s\n" "$(ls -ld "$SSH_DIR" | awk '{print $1}')"
    else
        _print_warning "SSH directory not found: $SSH_DIR"
    fi
    printf "\n"
    
    # Check SSH keys
    printf "SSH Keys:\n"
    key_count=0
    for key_type in ed25519 rsa ecdsa dsa; do
        if [ -f "$SSH_DIR/id_$key_type" ]; then
            _print_success "Found $key_type key: id_$key_type"
            key_count=$((key_count + 1))
        fi
    done
    
    # Check for custom GitHub/GitLab keys
    for service in github gitlab; do
        for key_type in ed25519 rsa; do
            if [ -f "$SSH_DIR/${service}_$key_type" ]; then
                _print_success "Found $service $key_type key: ${service}_$key_type"
                key_count=$((key_count + 1))
            fi
        done
    done
    
    if [ "$key_count" -eq 0 ]; then
        _print_warning "No SSH keys found"
        printf "  Run 'setup_github' or 'setup_gitlab' to create keys\n"
    fi
    printf "\n"
    
    # Check SSH agent
    printf "SSH Agent Status:\n"
    if _is_ssh_agent_running; then
        _print_success "SSH Agent is running"
        printf "Loaded keys:\n"
        _get_loaded_ssh_keys | sed 's/^/  /'
    else
        _print_warning "SSH Agent not running"
        printf "  Start with: eval \$(ssh-agent -s)\n"
    fi
    printf "\n"
    
    # Check SSH config
    printf "SSH Configuration:\n"
    if [ -f "$SSH_CONFIG_FILE" ]; then
        _print_success "SSH config exists: $SSH_CONFIG_FILE"
        
        # Check for GitHub/GitLab hosts
        github_hosts=$(grep '^Host github-' "$SSH_CONFIG_FILE" 2>/dev/null | wc -l)
        gitlab_hosts=$(grep '^Host gitlab-' "$SSH_CONFIG_FILE" 2>/dev/null | wc -l)
        
        printf "  GitHub hosts configured: %s\n" "$github_hosts"
        printf "  GitLab hosts configured: %s\n" "$gitlab_hosts"
    else
        _print_warning "SSH config not found"
        printf "  Will be created during setup\n"
    fi
    printf "\n"
    
    # Test connections
    printf "Connection Tests:\n"
    _test_service_connections
    
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
}
# Test SSH
ssh_test() {
    if [ $# -eq 0 ]; then
        printf "Usage: gitssh ssh test <hostname> [timeout]\n"
        printf "Example: gitssh ssh test github-work 10\n"
        return 1
    fi
    
    hostname="$1"
    timeout="${2:-5}"
    
    printf "Testing SSH connection to %s...\n" "$hostname"
    
    if _test_ssh_connection "$hostname" "$timeout"; then
        _print_success "SSH connection to $hostname successful!"
        
        # Try to get more details
        test_output=$(ssh -o ConnectTimeout="$timeout" -T "git@$hostname" 2>&1)
        if printf "%s" "$test_output" | grep -q "successfully authenticated\|Welcome to GitLab"; then
            printf "Authentication details:\n"
            printf "%s\n" "$test_output" | head -3
        fi
    else
        _print_error "SSH connection to $hostname failed"
        printf "Troubleshooting:\n"
        printf "  1. Check if SSH host exists: grep 'Host %s' ~/.ssh/config\n" "$hostname"
        printf "  2. Test SSH agent: ssh-add -l\n"
        printf "  3. Run diagnostics: gitssh ssh doctor\n"
        return 1
    fi
}
#================================================================#
# INFORMATION GATHERING
#================================================================#

# Gather GitHub user information
_gather_github_info() {
    printf "Step 1: GitHub Account Information\n"
    printf "===================================\n"
    
    printf "GitHub username: "
    read -r GITHUB_USERNAME
    if _is_empty "$GITHUB_USERNAME"; then
        _print_error "GitHub username cannot be empty"
        return 1
    fi
    
    if ! _validate_username "$GITHUB_USERNAME"; then
        _print_error "Invalid GitHub username format"
        return 1
    fi
    
    printf "Email address (for Git commits): "
    read -r USER_EMAIL
    if _is_empty "$USER_EMAIL"; then
        _print_error "Email address cannot be empty"
        return 1
    fi
    
    if ! _validate_email "$USER_EMAIL"; then
        _print_error "Invalid email format"
        return 1
    fi
    
    printf "Display name [%s]: " "$GITHUB_USERNAME"
    read -r USER_NAME
    USER_NAME=${USER_NAME:-$GITHUB_USERNAME}
    USER_NAME=$(_trim "$USER_NAME")
    
    # Set SSH host name
    SSH_HOST="github-$GITHUB_USERNAME"
    KEY_COMMENT="$USER_EMAIL"
    
    printf "\n"
    _print_success "Account information collected:"
    printf "  Username: %s\n" "$GITHUB_USERNAME"
    printf "  Name: %s\n" "$USER_NAME"
    printf "  Email: %s\n" "$USER_EMAIL"
    printf "  SSH Host: %s\n" "$SSH_HOST"
    printf "\n"
    
    return 0
}

# Gather GitLab user information
_gather_gitlab_info() {
    printf "Step 1: GitLab Account Information\n"
    printf "===================================\n"
    
    printf "GitLab instance URL [gitlab.com]: "
    read -r GITLAB_URL
    GITLAB_URL=${GITLAB_URL:-gitlab.com}
    GITLAB_URL=$(_trim "$GITLAB_URL")
    
    # Remove protocol if provided
    GITLAB_URL=$(printf "%s" "$GITLAB_URL" | sed 's|^https\?://||')
    
    printf "GitLab username: "
    read -r GITLAB_USERNAME
    if _is_empty "$GITLAB_USERNAME"; then
        _print_error "GitLab username cannot be empty"
        return 1
    fi
    
    if ! _validate_username "$GITLAB_USERNAME"; then
        _print_error "Invalid GitLab username format"
        return 1
    fi
    
    printf "Email address (for Git commits): "
    read -r USER_EMAIL
    if _is_empty "$USER_EMAIL"; then
        _print_error "Email address cannot be empty"
        return 1
    fi
    
    if ! _validate_email "$USER_EMAIL"; then
        _print_error "Invalid email format"
        return 1
    fi
    
    printf "Display name [%s]: " "$GITLAB_USERNAME"
    read -r USER_NAME
    USER_NAME=${USER_NAME:-$GITLAB_USERNAME}
    USER_NAME=$(_trim "$USER_NAME")
    
    # Set SSH host name
    if [ "$GITLAB_URL" = "gitlab.com" ]; then
        SSH_HOST="gitlab-$GITLAB_USERNAME"
    else
        # For custom GitLab instances, include domain
        sanitized_domain=$(printf "%s" "$GITLAB_URL" | sed 's/[^a-zA-Z0-9]/-/g')
        SSH_HOST="gitlab-$sanitized_domain-$GITLAB_USERNAME"
    fi
    
    KEY_COMMENT="$USER_EMAIL"
    
    printf "\n"
    _print_success "Account information collected:"
    printf "  GitLab URL: %s\n" "$GITLAB_URL"
    printf "  Username: %s\n" "$GITLAB_USERNAME"
    printf "  Name: %s\n" "$USER_NAME"
    printf "  Email: %s\n" "$USER_EMAIL"
    printf "  SSH Host: %s\n" "$SSH_HOST"
    printf "\n"
    
    return 0
}

#================================================================#
# SSH KEY MANAGEMENT
#================================================================#

# Check existing SSH setup
_check_existing_ssh_setup() {
    service="$1"  # github or gitlab
    
    printf "Step 2: Checking Existing SSH Setup\n"
    printf "====================================\n"
    
    # Check SSH directory
    if [ ! -d "$SSH_DIR" ]; then
        printf "Creating SSH directory...\n"
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        _print_success "Created $SSH_DIR with proper permissions"
    else
        _print_success "SSH directory exists: $SSH_DIR"
    fi
    
    # Check for existing keys
    existing_keys=""
    key_files=""
    
    # Check for service-specific keys first
    for key_type in ed25519 rsa; do
        key_name="${service}_${key_type}"
        if [ -f "$SSH_DIR/$key_name" ] && [ -f "$SSH_DIR/$key_name.pub" ]; then
            existing_keys="$existing_keys $key_name"
            key_files="$key_files $SSH_DIR/$key_name"
        fi
    done
    
    # Check for default keys
    for key_type in ed25519 rsa ecdsa dsa; do
        key_name="id_$key_type"
        if [ -f "$SSH_DIR/$key_name" ] && [ -f "$SSH_DIR/$key_name.pub" ]; then
            existing_keys="$existing_keys $key_name"
            key_files="$key_files $SSH_DIR/$key_name"
        fi
    done
    
    if [ -n "$existing_keys" ]; then
        _print_info "Found existing SSH keys:"
        for key in $existing_keys; do
            printf "  • %s\n" "$key"
        done
        printf "\n"
        
        printf "Options:\n"
        printf "  1. Use existing key\n"
        printf "  2. Generate new key\n"
        printf "  3. Exit setup\n"
        printf "\n"
        
        while true; do
            printf "Choose option (1-3): "
            read -r choice
            case "$choice" in
                1)
                    GENERATE_NEW_KEY="false"
                    if ! _select_existing_key; then
                        return 1
                    fi
                    break
                    ;;
                2)
                    GENERATE_NEW_KEY="true"
                    _generate_key_name "$service"
                    break
                    ;;
                3)
                    printf "Setup cancelled\n"
                    return 1
                    ;;
                *)
                    _print_warning "Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    else
        _print_info "No existing SSH keys found"
        GENERATE_NEW_KEY="true"
        _generate_key_name "$service"
    fi
    
    printf "\n"
    return 0
}

# Select existing SSH key
_select_existing_key() {
    printf "\nSelect SSH key to use:\n"
    
    i=1
    key_list=""
    for key_type in ed25519 rsa ecdsa dsa; do
        for prefix in "${service}_" "id_"; do
            key_name="${prefix}${key_type}"
            if [ -f "$SSH_DIR/$key_name" ] && [ -f "$SSH_DIR/$key_name.pub" ]; then
                printf "  %d. %s\n" "$i" "$key_name"
                key_list="$key_list $key_name"
                i=$((i + 1))
            fi
        done
    done
    
    if [ "$i" -eq 1 ]; then
        _print_error "No valid key pairs found"
        return 1
    fi
    
    while true; do
        printf "\nSelect key (1-%d): " "$((i-1))"
        read -r choice
        if [ "$choice" -ge 1 ] && [ "$choice" -le "$((i-1))" ] 2>/dev/null; then
            SELECTED_KEY=$(printf "%s" "$key_list" | awk "{print \$$choice}")
            KEY_PATH="$SSH_DIR/$SELECTED_KEY"
            _print_success "Selected: $SELECTED_KEY"
            break
        else
            _print_warning "Invalid choice"
        fi
    done
    
    return 0
}

# Generate key name for new key
_generate_key_name() {
    service="$1"
    
    # Use ed25519 as default for new keys (best practice)
    case "$service" in
        github)
            KEY_NAME="github_${GITHUB_USERNAME}_ed25519"
            ;;
        gitlab)
            if [ "$GITLAB_URL" = "gitlab.com" ]; then
                KEY_NAME="gitlab_${GITLAB_USERNAME}_ed25519"
            else
                sanitized_domain=$(printf "%s" "$GITLAB_URL" | sed 's/[^a-zA-Z0-9]/-/g')
                KEY_NAME="gitlab-${sanitized_domain}_ed25519"
            fi
            ;;
    esac
    
    KEY_PATH="$SSH_DIR/$KEY_NAME"
    
    _print_info "Will generate new key: $KEY_NAME"
}

# Generate SSH key with user guidance
_generate_ssh_key() {
    service="$1"
    
    printf "Step 3: Generating SSH Key\n"
    printf "==========================\n"
    
    _print_info "About SSH Keys:"
    printf "SSH keys provide secure, passwordless authentication to Git services.\n"
    printf "We'll use Ed25519 encryption (recommended for 2025).\n\n"
    
    # Check if key already exists
    if [ -f "$KEY_PATH" ]; then
        _print_warning "Key file already exists: $KEY_PATH"
        printf "Overwrite existing key? (y/N): "
        read -r overwrite
        case "$overwrite" in
            [Yy]*) ;;
            *) 
                _print_info "Using existing key"
                return 0
                ;;
        esac
    fi
    
    printf "Generating SSH key...\n"
    printf "Key type: Ed25519 (most secure)\n"
    printf "Key file: %s\n" "$KEY_PATH"
    printf "Comment: %s\n\n" "$KEY_COMMENT"
    
    _print_info "About Passphrases:"
    printf "A passphrase adds extra security to your SSH key.\n"
    printf "Recommended: Use a strong passphrase\n"
    printf "Note: You can use ssh-agent to avoid entering it repeatedly\n\n"
    
    # Generate the key
    if ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$KEY_COMMENT"; then
        _print_success "SSH key generated successfully!"
        
        # Set proper permissions
        chmod 600 "$KEY_PATH"
        chmod 644 "$KEY_PATH.pub"
        
        printf "\nKey details:\n"
        printf "  Private key: %s (keep this secret!)\n" "$KEY_PATH"
        printf "  Public key: %s (this will be added to $service)\n" "$KEY_PATH.pub"
        printf "  Fingerprint: "
        ssh-keygen -lf "$KEY_PATH.pub" 2>/dev/null | awk '{print $2}'
    else
        _print_error "Failed to generate SSH key"
        return 1
    fi
    
    printf "\n"
    return 0
}

# Setup SSH configuration
_setup_ssh_config() {
    service="$1"
    
    printf "Step 4: Configuring SSH\n"
    printf "=======================\n"
    
    _print_info "About SSH Config:"
    printf "The SSH config file (~/.ssh/config) tells SSH how to connect to different hosts.\n"
    printf "This allows you to use custom hostnames like 'github-username'.\n\n"
    
    # Determine hostname and host entry
    case "$service" in
        github)
            REAL_HOSTNAME="github.com"
            HOST_ENTRY="Host $SSH_HOST
    HostName github.com
    User git
    IdentityFile $KEY_PATH
    IdentitiesOnly yes"
            ;;
        gitlab)
            REAL_HOSTNAME="$GITLAB_URL"
            HOST_ENTRY="Host $SSH_HOST
    HostName $GITLAB_URL
    User git
    IdentityFile $KEY_PATH
    IdentitiesOnly yes"
            ;;
    esac
    
    # Create SSH config if it doesn't exist
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        printf "Creating SSH config file...\n"
        touch "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
        _print_success "Created $SSH_CONFIG_FILE"
    fi
    
    # Check if host entry already exists
    if grep -q "^Host $SSH_HOST$" "$SSH_CONFIG_FILE"; then
        _print_warning "SSH host '$SSH_HOST' already exists in config"
        printf "Update the existing entry? (Y/n): "
        read -r update_config
        case "$update_config" in
            [Nn]*) 
                _print_info "Keeping existing SSH config"
                return 0
                ;;
        esac
        
        # Remove existing entry
        _remove_ssh_host_entry "$SSH_HOST"
    fi
    
    # Add new host entry
    printf "Adding SSH host configuration...\n"
    printf "\n# %s SSH configuration\n%s\n\n" "$service" "$HOST_ENTRY" >> "$SSH_CONFIG_FILE"
    
    _print_success "Added SSH configuration for $SSH_HOST"
    printf "  You can now use: git@%s:username/repository.git\n" "$SSH_HOST"
    printf "\n"
    
    return 0
}

# Add key to SSH agent
_add_to_ssh_agent() {
    service="$1"
    
    printf "Step 5: Adding Key to SSH Agent\n"
    printf "================================\n"
    
    _print_info "About SSH Agent:"
    printf "SSH Agent manages your SSH keys and handles authentication.\n"
    printf "This allows you to enter your passphrase once per session.\n\n"
    
    # Check if SSH agent is running
    if ! _is_ssh_agent_running; then
        printf "Starting SSH agent...\n"
        eval "$(ssh-agent -s)" >/dev/null
        if _is_ssh_agent_running; then
            _print_success "SSH agent started"
        else
            _print_error "Failed to start SSH agent"
            return 1
        fi
    else
        _print_success "SSH agent is already running"
    fi
    
    # Add key to agent
    printf "Adding SSH key to agent...\n"
    if ssh-add "$KEY_PATH"; then
        _print_success "SSH key added to agent successfully!"
        
        # Show loaded keys
        printf "\nCurrently loaded keys:\n"
        _get_loaded_ssh_keys | sed 's/^/  /'
    else
        _print_error "Failed to add SSH key to agent"
        return 1
    fi
    
    printf "\n"
    return 0
}

#================================================================#
# SERVICE-SPECIFIC GUIDES
#================================================================#

# Guide user through GitHub key addition
_guide_github_key_addition() {
    printf "Step 6: Adding Key to GitHub\n"
    printf "============================\n"
    
    _print_info "Now you need to add your public key to GitHub:"
    printf "\n"
    
    # Display the public key
    printf "Your public key (copy this entire text):\n"
    printf "%s\n" "$(cat "$KEY_PATH.pub")"
    printf "%s\n" "$(printf '=%.0s' {1..60})"
    printf "\n"
    
    _print_info "GitHub Setup Steps:"
    printf "1. Go to https://github.com/settings/keys\n"
    printf "2. Click 'New SSH key'\n"
    printf "3. Give it a title (e.g., 'My Laptop - %s')\n" "$(date '+%Y-%m-%d')"
    printf "4. Paste the public key above into the 'Key' field\n"
    printf "5. Click 'Add SSH key'\n\n"
    
    # Auto-copy to clipboard if possible
    if command -v xclip >/dev/null 2>&1; then
        cat "$KEY_PATH.pub" | xclip -selection clipboard
        _print_success "Public key copied to clipboard!"
    elif command -v pbcopy >/dev/null 2>&1; then
        cat "$KEY_PATH.pub" | pbcopy
        _print_success "Public key copied to clipboard!"
    elif command -v wl-copy >/dev/null 2>&1; then
        cat "$KEY_PATH.pub" | wl-copy
        _print_success "Public key copied to clipboard!"
    else
        _print_info "Tip: Select and copy the public key above"
    fi
    
    printf "Press Enter after adding the key to GitHub..."
    read -r _
    
    return 0
}

# Guide user through GitLab key addition
_guide_gitlab_key_addition() {
    printf "Step 6: Adding Key to GitLab\n"
    printf "============================\n"
    
    _print_info "Now you need to add your public key to GitLab:"
    printf "\n"
    
    # Display the public key
    printf "Your public key (copy this entire text):\n"
    printf "%s\n" "$(cat "$KEY_PATH.pub")"
    printf "%s\n" "$(printf '=%.0s' {1..60})"
    printf "\n"
    
    _print_info "GitLab Setup Steps:"
    if [ "$GITLAB_URL" = "gitlab.com" ]; then
        printf "1. Go to https://gitlab.com/-/user_settings/ssh_keys\n"
    else
        printf "1. Go to https://%s/-/user_settings/ssh_keys\n" "$GITLAB_URL"
    fi
    printf "2. Paste the public key above into the 'Key' field\n"
    printf "3. Give it a title (e.g., 'My Laptop - %s')\n" "$(date '+%Y-%m-%d')"
    printf "4. Set an expiration date (optional but recommended)\n"
    printf "5. Click 'Add key'\n\n"
    
    # Auto-copy to clipboard if possible
    if command -v xclip >/dev/null 2>&1; then
        cat "$KEY_PATH.pub" | xclip -selection clipboard
        _print_success "Public key copied to clipboard!"
    elif command -v pbcopy >/dev/null 2>&1; then
        cat "$KEY_PATH.pub" | pbcopy
        _print_success "Public key copied to clipboard!"
    elif command -v wl-copy >/dev/null 2>&1; then
        cat "$KEY_PATH.pub" | wl-copy
        _print_success "Public key copied to clipboard!"
    else
        _print_info "Tip: Select and copy the public key above"
    fi
    
    printf "Press Enter after adding the key to GitLab..."
    read -r _
    
    return 0
}

#================================================================#
# CONNECTION TESTING
#================================================================#

# Test GitHub connection
_test_github_connection() {
    printf "Step 7: Testing GitHub Connection\n"
    printf "==================================\n"
    
    _print_info "Testing SSH connection to GitHub..."
    printf "This verifies that your key was added correctly.\n\n"
    
    printf "Testing connection to %s...\n" "$SSH_HOST"
    
    # Test with timeout and capture output
    test_output=$(ssh -o ConnectTimeout=10 -T "git@$SSH_HOST" 2>&1)
    test_result=$?
    
    if printf "%s" "$test_output" | grep -q "successfully authenticated"; then
        _print_success "SSH connection successful!"
        
        # Extract username from GitHub response
        github_user=$(printf "%s" "$test_output" | sed -n 's/.*Hi \([^!]*\)!.*/\1/p')
        if [ -n "$github_user" ]; then
            printf "Authenticated as GitHub user: %s\n" "$github_user"
            
            if [ "$github_user" != "$GITHUB_USERNAME" ]; then
                _print_warning "Username mismatch!"
                printf "  Expected: %s\n" "$GITHUB_USERNAME"
                printf "  Actual: %s\n" "$github_user"
                printf "This might indicate a key conflict or wrong account.\n"
            fi
        fi
    else
        _print_error "SSH connection failed"
        printf "Error output:\n%s\n\n" "$test_output"
        
        _print_info "Troubleshooting tips:"
        printf "1. Make sure you added the public key to the correct GitHub account\n"
        printf "2. Check that the key was pasted completely without extra spaces\n"
        printf "3. Verify your SSH agent is running: ssh-add -l\n"
        printf "4. Try adding the key to SSH agent again: ssh-add %s\n" "$KEY_PATH"
        printf "\nWould you like to try again? (y/N): "
        read -r retry
        case "$retry" in
            [Yy]*) return _test_github_connection ;;
            *) return 1 ;;
        esac
    fi
    
    printf "\n"
    return 0
}

# Test GitLab connection
_test_gitlab_connection() {
    printf "Step 7: Testing GitLab Connection\n"
    printf "==================================\n"
    
    _print_info "Testing SSH connection to GitLab..."
    printf "This verifies that your key was added correctly.\n\n"
    
    printf "Testing connection to %s...\n" "$SSH_HOST"
    
    # Test with timeout and capture output
    test_output=$(ssh -o ConnectTimeout=10 -T "git@$SSH_HOST" 2>&1)
    test_result=$?
    
    if printf "%s" "$test_output" | grep -q "Welcome to GitLab"; then
        _print_success "SSH connection successful!"
        
        # Extract username from GitLab response if available
        gitlab_user=$(printf "%s" "$test_output" | sed -n 's/.*Welcome to GitLab, @\([^!]*\)!.*/\1/p')
        if [ -n "$gitlab_user" ]; then
            printf "Authenticated as GitLab user: %s\n" "$gitlab_user"
            
            if [ "$gitlab_user" != "$GITLAB_USERNAME" ]; then
                _print_warning "Username mismatch!"
                printf "  Expected: %s\n" "$GITLAB_USERNAME"
                printf "  Actual: %s\n" "$gitlab_user"
                printf "This might indicate a key conflict or wrong account.\n"
            fi
        fi
    else
        _print_error "SSH connection failed"
        printf "Error output:\n%s\n\n" "$test_output"
        
        _print_info "Troubleshooting tips:"
        printf "1. Make sure you added the public key to the correct GitLab account\n"
        printf "2. Check that the key was pasted completely without extra spaces\n"
        printf "3. Verify your SSH agent is running: ssh-add -l\n"
        printf "4. Try adding the key to SSH agent again: ssh-add %s\n" "$KEY_PATH"
        printf "\nWould you like to try again? (y/N): "
        read -r retry
        case "$retry" in
            [Yy]*) return _test_gitlab_connection ;;
            *) return 1 ;;
        esac
    fi
    
    printf "\n"
    return 0
}

#================================================================#
# INTEGRATION FUNCTIONS
#================================================================#

# Integrate with Git-SSH Session Manager
_integrate_with_session_manager() {
    service="$1"
    
    printf "Step 8: Integration with Git-SSH Session Manager\n"
    printf "================================================\n"
    
    _print_info "About Git-SSH Session Manager:"
    printf "This tool helps you manage multiple Git identities and SSH keys.\n"
    printf "It automatically configures the right user for each repository.\n\n"
    
    # Check if Git-SSH Session Manager is available
    if ! _check_dependencies 2>/dev/null; then
        _print_warning "Git-SSH Session Manager not fully configured"
        printf "Run 'git_ssh_init' to complete the setup\n\n"
        return 0
    fi
    
    # Add user to session manager if not exists
    case "$service" in
        github)
            username="$GITHUB_USERNAME"
            ;;
        gitlab)
            username="$GITLAB_USERNAME"
            ;;
    esac
    
    if ! _user_exists "$username" 2>/dev/null; then
        printf "Adding user to Git-SSH Session Manager...\n"
        
        # Add user to config
        if _add_user_to_config "$username" "$USER_NAME" "$USER_EMAIL" "$SSH_HOST"; then
            _print_success "Added '$username' to session manager"
        else
            _print_warning "Failed to add user to session manager"
            printf "You can add manually later with 'git_add_user'\n"
        fi
    else
        _print_success "User '$username' already exists in session manager"
    fi
    
    printf "\n"
    return 0
}

#================================================================#
# UTILITY FUNCTIONS
#================================================================#

# Check setup dependencies
_check_setup_dependencies() {
    missing_deps=""
    
    # Check for required commands
    for cmd in ssh-keygen ssh-add ssh git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        _print_error "Missing required dependencies:$missing_deps"
        printf "Please install them first:\n"
        
        os=$(_detect_os)
        case "$os" in
            linux)
                printf "  Ubuntu/Debian: sudo apt install openssh-client git\n"
                printf "  RHEL/CentOS: sudo yum install openssh-clients git\n"
                printf "  Arch: sudo pacman -S openssh git\n"
                ;;
            macos)
                printf "  macOS: git and ssh should be pre-installed\n"
                printf "  If missing: xcode-select --install\n"
                ;;
        esac
        return 1
    fi
    
    return 0
}

# Remove existing SSH host entry
_remove_ssh_host_entry() {
    host_name="$1"
    temp_file=$(_create_temp_file)
    
    # Remove the host block (Host line and all following indented lines)
    awk -v host="$host_name" '
    BEGIN { skip = 0 }
    /^Host / { 
        if ($2 == host) { 
            skip = 1 
        } else { 
            skip = 0 
        } 
    }
    /^[[:space:]]/ && skip { next }
    /^[^[:space:]#]/ && !/^Host / { skip = 0 }
    !skip { print }
    ' "$SSH_CONFIG_FILE" > "$temp_file"
    
    _safe_file_replace "$temp_file" "$SSH_CONFIG_FILE"
}

# Test connections to all configured services
_test_service_connections() {
    if [ -f "$SSH_CONFIG_FILE" ]; then
        # Test GitHub connections
        github_hosts=$(grep '^Host github-' "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        if [ -n "$github_hosts" ]; then
            for host in $github_hosts; do
                printf "  %s: " "$host"
                if _test_ssh_connection "$host" 3; then
                    _print_color green "Connected"
                    printf "\n"
                else
                    _print_color red "Failed"
                    printf "\n"
                fi
            done
        fi
        
        # Test GitLab connections
        gitlab_hosts=$(grep '^Host gitlab-' "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        if [ -n "$gitlab_hosts" ]; then
            for host in $gitlab_hosts; do
                printf "  %s: " "$host"
                if _test_ssh_connection "$host" 3; then
                    _print_color green "Connected"
                    printf "\n"
                else
                    _print_color red "Failed"
                    printf "\n"
                fi
            done
        fi
        
        if [ -z "$github_hosts" ] && [ -z "$gitlab_hosts" ]; then
            printf "  No GitHub or GitLab hosts configured\n"
        fi
    else
        printf "  No SSH config file found\n"
    fi
}

#================================================================#
# ADVANCED SETUP FUNCTIONS
#================================================================#

# Setup multiple accounts for the same service
setup_github_multi() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "  GitHub Multiple Accounts Setup"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    _print_info "This wizard helps you set up multiple GitHub accounts"
    printf "Each account will have its own SSH key and host configuration.\n\n"
    
    # Ask how many accounts
    printf "How many GitHub accounts do you want to set up? (1-5): "
    read -r account_count
    
    # Fix: Proper regex pattern matching
    if ! printf "%s" "$account_count" | grep -q '^[1-5]$'; then
        _print_error "Please enter a number between 1 and 5"
        return 1
    fi
    
    # Setup each account
    i=1
    while [ "$i" -le "$account_count" ]; do
        printf "\n"
        _print_color yellow "Setting up GitHub account %d of %d" "$i" "$account_count"
        printf "\n"
        printf "%s\n" "$(printf '=%.0s' $(seq 1 40))"  # Fix: Use seq instead of {1..40}
        
        # Override the github username for this iteration
        GITHUB_USERNAME=""
        
        if ! _gather_github_info; then
            printf "Skipping account %d\n" "$i"
        else
            _check_existing_ssh_setup "github"
            
            if [ "$GENERATE_NEW_KEY" = "true" ]; then
                # Generate unique key name for multiple accounts
                KEY_NAME="github_${GITHUB_USERNAME}_ed25519"
                KEY_PATH="$SSH_DIR/$KEY_NAME"
                _generate_ssh_key "github"
            fi
            
            _setup_ssh_config "github"
            _add_to_ssh_agent "github"
            _guide_github_key_addition
            _test_github_connection
            _integrate_with_session_manager "github"
            
            _print_success "Account %d (%s) setup completed!" "$i" "$GITHUB_USERNAME"
        fi
        
        i=$((i + 1))
    done
    
    printf "\n"
    _print_success "Multiple GitHub accounts setup completed!"
    _print_info "Use 'ssh_status' to see all configured connections"
}

# Quick SSH key generation (minimal prompts)
quick_ssh_key() {
    if ! _check_setup_dependencies; then
        return 1
    fi
    
    printf "Quick SSH Key Generator\n"
    printf "=======================\n"
    
    printf "Service (github/gitlab/custom): "
    read -r service
    service=$(_to_lower "$service")
    
    case "$service" in
        github|gitlab)
            printf "Username: "
            read -r username
            if _is_empty "$username"; then
                _print_error "Username cannot be empty"
                return 1
            fi
            
            KEY_NAME="${service}_${username}_ed25519"
            ;;
        custom)
            printf "Key name: "
            read -r KEY_NAME
            if _is_empty "$KEY_NAME"; then
                _print_error "Key name cannot be empty"
                return 1
            fi
            ;;
        *)
            _print_error "Invalid service. Use: github, gitlab, or custom"
            return 1
            ;;
    esac
    
    printf "Email (for key comment): "
    read -r email
    if _is_empty "$email"; then
        email="$(whoami)@$(hostname)"
        printf "Using default: %s\n" "$email"
    fi
    
    KEY_PATH="$SSH_DIR/$KEY_NAME"
    
    # Generate key
    printf "\nGenerating SSH key...\n"
    if ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$email"; then
        _print_success "SSH key generated: $KEY_NAME"
        
        # Set permissions
        chmod 600 "$KEY_PATH"
        chmod 644 "$KEY_PATH.pub"
        
        # Add to agent
        if _is_ssh_agent_running; then
            ssh-add "$KEY_PATH"
            _print_success "Added to SSH agent"
        else
            _print_info "Add to SSH agent with: ssh-add $KEY_PATH"
        fi
        
        # Show public key
        printf "\nYour public key:\n"
        printf "%s\n" "$(cat "$KEY_PATH.pub")"
        
        # Auto-copy if possible
        if command -v xclip >/dev/null 2>&1; then
            cat "$KEY_PATH.pub" | xclip -selection clipboard
            _print_success "Copied to clipboard!"
        elif command -v pbcopy >/dev/null 2>&1; then
            cat "$KEY_PATH.pub" | pbcopy
            _print_success "Copied to clipboard!"
        fi
        
    else
        _print_error "Failed to generate SSH key"
        return 1
    fi
}

#================================================================#
# DIAGNOSTIC AND REPAIR FUNCTIONS
#================================================================#

# Diagnose SSH issues
ssh_doctor() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "        SSH Connection Doctor"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    issues_found=0
    
    # Check SSH directory and permissions
    printf "1. Checking SSH Directory:\n"
    if [ -d "$SSH_DIR" ]; then
        _print_success "SSH directory exists: $SSH_DIR"
        
        # Check permissions
        permissions=$(ls -ld "$SSH_DIR" | awk '{print $1}')
        if [ "$permissions" = "drwx------" ] || [ "$permissions" = "drwx------." ]; then
            _print_success "Directory permissions are correct (700)"
        else
            _print_warning "Directory permissions should be 700"
            printf "  Current: %s\n" "$permissions"
            printf "  Fix with: chmod 700 %s\n" "$SSH_DIR"
            issues_found=$((issues_found + 1))
        fi
    else
        _print_error "SSH directory missing: $SSH_DIR"
        printf "  Fix with: mkdir -p %s && chmod 700 %s\n" "$SSH_DIR" "$SSH_DIR"
        issues_found=$((issues_found + 1))
    fi
    printf "\n"
    
    # Check SSH keys
    printf "2. Checking SSH Keys:\n"
    key_count=0
    for key_file in "$SSH_DIR"/*; do
        [ ! -f "$key_file" ] && continue
        case "$(basename "$key_file")" in
            *.pub)
                continue  # Skip public keys, we'll check them with private keys
                ;;
            *_ed25519|*_rsa|id_ed25519|id_rsa|id_ecdsa|id_dsa)
                key_name=$(basename "$key_file")
                public_key="${key_file}.pub"
                
                if [ -f "$public_key" ]; then
                    _print_success "Valid key pair: $key_name"
                    
                    # Check permissions
                    private_perms=$(ls -l "$key_file" | awk '{print $1}')
                    public_perms=$(ls -l "$public_key" | awk '{print $1}')
                    
                    if [ "$private_perms" != "-rw-------" ] && [ "$private_perms" != "-rw-------." ]; then
                        _print_warning "  Private key permissions should be 600"
                        printf "    Fix with: chmod 600 %s\n" "$key_file"
                        issues_found=$((issues_found + 1))
                    fi
                    
                    key_count=$((key_count + 1))
                else
                    _print_warning "Missing public key for: $key_name"
                    printf "  Expected: %s\n" "$public_key"
                    issues_found=$((issues_found + 1))
                fi
                ;;
        esac
    done
    
    if [ "$key_count" -eq 0 ]; then
        _print_warning "No SSH keys found"
        printf "  Generate with: setup_github or setup_gitlab\n"
        issues_found=$((issues_found + 1))
    fi
    printf "\n"
    
    # Check SSH agent
    printf "3. Checking SSH Agent:\n"
    if _is_ssh_agent_running; then
        _print_success "SSH Agent is running"
        
        loaded_keys=$(_get_loaded_ssh_keys)
        if [ -n "$loaded_keys" ]; then
            printf "Loaded keys:\n"
            printf "%s\n" "$loaded_keys" | sed 's/^/  /'
        else
            _print_warning "No keys loaded in SSH agent"
            printf "  Load keys with: ssh-add ~/.ssh/your_key\n"
            issues_found=$((issues_found + 1))
        fi
    else
        _print_warning "SSH Agent not running"
        printf "  Start with: eval \$(ssh-agent -s)\n"
        printf "  Then load keys with: ssh-add ~/.ssh/your_key\n"
        issues_found=$((issues_found + 1))
    fi
    printf "\n"
    
    # Check SSH config
    printf "4. Checking SSH Configuration:\n"
    if [ -f "$SSH_CONFIG_FILE" ]; then
        _print_success "SSH config exists: $SSH_CONFIG_FILE"
        
        # Check for GitHub/GitLab entries
        github_entries=$(grep '^Host github-' "$SSH_CONFIG_FILE" 2>/dev/null | wc -l)
        gitlab_entries=$(grep '^Host gitlab-' "$SSH_CONFIG_FILE" 2>/dev/null | wc -l)
        
        printf "  GitHub configurations: %s\n" "$github_entries"
        printf "  GitLab configurations: %s\n" "$gitlab_entries"
        
        if [ "$github_entries" -eq 0 ] && [ "$gitlab_entries" -eq 0 ]; then
            _print_warning "No GitHub or GitLab SSH hosts configured"
            printf "  Setup with: setup_github or setup_gitlab\n"
            issues_found=$((issues_found + 1))
        fi
    else
        _print_warning "SSH config not found: $SSH_CONFIG_FILE"
        printf "  Will be created during setup\n"
        issues_found=$((issues_found + 1))
    fi
    printf "\n"
    
    # Test connections
    printf "5. Testing Connections:\n"
    connection_failures=0
    if [ -f "$SSH_CONFIG_FILE" ]; then
        # Test GitHub hosts
        github_hosts=$(grep '^Host github-' "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        for host in $github_hosts; do
            printf "  Testing %s: " "$host"
            if _test_ssh_connection "$host" 5; then
                _print_color green "Success"
                printf "\n"
            else
                _print_color red "Failed"
                printf "\n"
                connection_failures=$((connection_failures + 1))
            fi
        done
        
        # Test GitLab hosts
        gitlab_hosts=$(grep '^Host gitlab-' "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        for host in $gitlab_hosts; do
            printf "  Testing %s: " "$host"
            if _test_ssh_connection "$host" 5; then
                _print_color green "Success"
                printf "\n"
            else
                _print_color red "Failed"
                printf "\n"
                connection_failures=$((connection_failures + 1))
            fi
        done
        
        if [ "$connection_failures" -gt 0 ]; then
            issues_found=$((issues_found + connection_failures))
        fi
    fi
    printf "\n"
    
    # Summary
    printf "Diagnosis Summary:\n"
    printf "==================\n"
    if [ "$issues_found" -eq 0 ]; then
        _print_success "No issues found - SSH setup is working correctly!"
    else
        _print_warning "Found $issues_found issue(s) that need attention"
        printf "\nSuggested fixes:\n"
        printf "  • For missing keys: run 'setup_github' or 'setup_gitlab'\n"
        printf "  • For permission issues: chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*\n"
        printf "  • For agent issues: eval \$(ssh-agent -s) && ssh-add ~/.ssh/your_key\n"
        printf "  • For connection failures: check if keys are added to your account\n"
    fi
    printf "\n"
    
    return "$issues_found"
}

# Repair common SSH issues
ssh_repair() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "        SSH Repair Wizard"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    _print_info "This will attempt to fix common SSH configuration issues"
    printf "\n"
    
    repairs_made=0
    
    # Fix SSH directory permissions
    printf "1. Fixing SSH directory permissions...\n"
    if [ -d "$SSH_DIR" ]; then
        chmod 700 "$SSH_DIR"
        _print_success "Set SSH directory permissions to 700"
        repairs_made=$((repairs_made + 1))
    else
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        _print_success "Created SSH directory with correct permissions"
        repairs_made=$((repairs_made + 1))
    fi
    
    # Fix SSH key permissions
    printf "\n2. Fixing SSH key permissions...\n"
    key_files_fixed=0
    for key_file in "$SSH_DIR"/*; do
        [ ! -f "$key_file" ] && continue
        case "$(basename "$key_file")" in
            *.pub)
                chmod 644 "$key_file" 2>/dev/null && key_files_fixed=$((key_files_fixed + 1))
                ;;
            *_ed25519|*_rsa|id_ed25519|id_rsa|id_ecdsa|id_dsa)
                chmod 600 "$key_file" 2>/dev/null && key_files_fixed=$((key_files_fixed + 1))
                ;;
        esac
    done
    
    if [ "$key_files_fixed" -gt 0 ]; then
        _print_success "Fixed permissions for $key_files_fixed key files"
        repairs_made=$((repairs_made + 1))
    else
        _print_info "No key files found or permissions already correct"
    fi
    
    # Fix SSH config permissions
    printf "\n3. Fixing SSH config permissions...\n"
    if [ -f "$SSH_CONFIG_FILE" ]; then
        chmod 600 "$SSH_CONFIG_FILE"
        _print_success "Set SSH config permissions to 600"
        repairs_made=$((repairs_made + 1))
    else
        _print_info "SSH config doesn't exist yet"
    fi
    
    # Start SSH agent if not running
    printf "\n4. Checking SSH agent...\n"
    if ! _is_ssh_agent_running; then
        printf "Starting SSH agent...\n"
        eval "$(ssh-agent -s)" >/dev/null
        if _is_ssh_agent_running; then
            _print_success "Started SSH agent"
            repairs_made=$((repairs_made + 1))
            
            # Load existing keys
            printf "Loading SSH keys...\n"
            keys_loaded=0
            for key_file in "$SSH_DIR"/*; do
                [ ! -f "$key_file" ] && continue
                case "$(basename "$key_file")" in
                    *_ed25519|*_rsa|id_ed25519|id_rsa|id_ecdsa|id_dsa)
                        if ssh-add "$key_file" 2>/dev/null; then
                            keys_loaded=$((keys_loaded + 1))
                        fi
                        ;;
                esac
            done
            
            if [ "$keys_loaded" -gt 0 ]; then
                _print_success "Loaded $keys_loaded SSH keys"
                repairs_made=$((repairs_made + 1))
            fi
        else
            _print_warning "Failed to start SSH agent"
        fi
    else
        _print_success "SSH agent is already running"
    fi
    
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    
    if [ "$repairs_made" -gt 0 ]; then
        _print_success "Completed $repairs_made repairs"
        printf "Run 'ssh_status' to verify the fixes\n"
    else
        _print_info "No repairs needed - SSH setup appears correct"
    fi
    
    printf "\n"
    return 0
}

#================================================================#
# UNINSTALL AND CLEANUP
#================================================================#

# Remove SSH setup for a service
remove_ssh_setup() {
    if [ $# -eq 0 ]; then
        printf "Usage: remove_ssh_setup <service>\n"
        printf "Services: github, gitlab, or specific hostname\n"
        return 1
    fi
    
    service="$1"
    
    printf "\n"
    _print_color yellow "=========================================="
    printf "\n"
    _print_color yellow "    Remove SSH Setup for %s" "$service"
    printf "\n"
    _print_color yellow "=========================================="
    printf "\n\n"
    
    _print_warning "This will remove SSH keys and configuration for $service"
    printf "This action cannot be easily undone.\n\n"
    
    printf "Are you sure you want to continue? (y/N): "
    read -r confirm
    case "$confirm" in
        [Yy]*) ;;
        *) 
            printf "Cancelled\n"
            return 0
            ;;
    esac
    
    items_removed=0
    
    # Remove SSH keys
    printf "\nRemoving SSH keys...\n"
    for key_pattern in "${service}_*" "id_${service}*"; do
        for key_file in "$SSH_DIR"/$key_pattern; do
            [ ! -f "$key_file" ] && continue
            
            key_name=$(basename "$key_file")
            printf "Remove %s? (y/N): " "$key_name"
            read -r remove_key
            case "$remove_key" in
                [Yy]*)
                    rm -f "$key_file" "${key_file}.pub"
                    _print_success "Removed $key_name"
                    items_removed=$((items_removed + 1))
                    ;;
            esac
        done
    done
    
    # Remove SSH config entries
    printf "\nRemoving SSH config entries...\n"
    if [ -f "$SSH_CONFIG_FILE" ]; then
        case "$service" in
            github)
                hosts_to_remove=$(grep '^Host github-' "$SSH_CONFIG_FILE" | awk '{print $2}')
                ;;
            gitlab)
                hosts_to_remove=$(grep '^Host gitlab-' "$SSH_CONFIG_FILE" | awk '{print $2}')
                ;;
            *)
                hosts_to_remove="$service"
                ;;
        esac
        
        for host in $hosts_to_remove; do
            if grep -q "^Host $host$" "$SSH_CONFIG_FILE"; then
                printf "Remove SSH config for %s? (y/N): " "$host"
                read -r remove_config
                case "$remove_config" in
                    [Yy]*)
                        _remove_ssh_host_entry "$host"
                        _print_success "Removed SSH config for $host"
                        items_removed=$((items_removed + 1))
                        ;;
                esac
            fi
        done
    fi
    
    printf "\n"
    if [ "$items_removed" -gt 0 ]; then
        _print_success "Removed $items_removed items"
        _print_info "You may want to restart your SSH agent to clear cached keys"
    else
        _print_info "No items were removed"
    fi
    
    printf "\n"
    return 0
}

#================================================================#
# INTEGRATION WITH SESSION MANAGER
#================================================================#

# Integration helper - uses existing session manager functions if available
_add_user_to_config() {
    username="$1"
    name="$2"
    email="$3"
    ssh_host="$4"
    
    # Check if session manager is available
    if command -v git_add_user >/dev/null 2>&1 && _check_dependencies 2>/dev/null; then
        # Use existing session manager function
        printf "Integrating with Git-SSH Session Manager...\n"
        
        # Create temporary script to automate git_add_user
        temp_script=$(_create_temp_file)
        cat > "$temp_script" << EOF
#!/bin/sh
printf "%s\n%s\n%s\n%s\ny\n" "$username" "$name" "$email" "$ssh_host"
EOF
        chmod +x "$temp_script"
        
        # Run git_add_user with automated input
        if "$temp_script" | git_add_user >/dev/null 2>&1; then
            rm -f "$temp_script"
            return 0
        else
            rm -f "$temp_script"
            return 1
        fi
    else
        # Session manager not available - just inform user
        printf "Git-SSH Session Manager not available\n"
        printf "Run 'git_ssh_init' first to enable full integration\n"
        return 1
    fi
}

# Check if user exists in session manager
_user_exists() {
    username="$1"
    
    if _check_dependencies 2>/dev/null && [ -f "$GIT_SSH_USERS_FILE" ]; then
        user_details=$(jq -r --arg user "$username" '.users[$user] // empty' "$GIT_SSH_USERS_FILE" 2>/dev/null)
        [ -n "$user_details" ] && [ "$user_details" != "null" ] && [ "$user_details" != "empty" ]
    else
        return 1
    fi
}

#================================================================#
# EDUCATIONAL HELP FUNCTIONS
#================================================================#

# Show SSH learning guide
ssh_learn() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "        SSH & Git Learning Guide"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    printf "What is SSH?\n"
    printf "============\n"
    printf "SSH (Secure Shell) is a protocol for secure communication over networks.\n"
    printf "For Git, SSH provides passwordless authentication using key pairs.\n\n"
    
    printf "How SSH Keys Work:\n"
    printf "==================\n"
    printf "1. You generate a key pair (public + private key)\n"
    printf "2. Keep the private key secret on your computer\n"
    printf "3. Add the public key to your GitHub/GitLab account\n"
    printf "4. SSH uses these keys to authenticate you automatically\n\n"
    
    printf "Why Use SSH Instead of HTTPS?\n"
    printf "==============================\n"
    printf "• No password prompts for git push/pull\n"
    printf "• More secure than password authentication\n"
    printf "• Required for many advanced Git workflows\n"
    printf "• Better performance for frequent operations\n\n"
    
    printf "Key Types (2025 Recommendations):\n"
    printf "==================================\n"
    printf "• Ed25519: Recommended - fast, secure, small keys\n"
    printf "• RSA 4096: Good alternative - widely supported\n"
    printf "• ECDSA: Secure but Ed25519 preferred\n"
    printf "• RSA 2048: Minimum, but Ed25519 better\n\n"
    
    printf "SSH Agent:\n"
    printf "===========\n"
    printf "Manages your SSH keys and remembers passphrases during your session.\n"
    printf "Start with: eval \$(ssh-agent -s)\n"
    printf "Add keys with: ssh-add ~/.ssh/your_key\n\n"
    
    printf "SSH Config File:\n"
    printf "================\n"
    printf "Location: ~/.ssh/config\n"
    printf "Purpose: Define custom hostnames and key mappings\n"
    printf "Allows using: git@github-username:repo/name.git\n\n"
    
    printf "Getting Started:\n"
    printf "================\n"
    printf "1. Run 'setup_github' or 'setup_gitlab' for guided setup\n"
    printf "2. Use 'ssh_status' to check your configuration\n"
    printf "3. Use 'ssh_doctor' if you have connection issues\n"
    printf "4. Use 'git_user' to manage identities per repository\n\n"
    
    printf "Common Commands:\n"
    printf "================\n"
    printf "• ssh_status        - Check SSH setup status\n"
    printf "• ssh_doctor        - Diagnose SSH issues\n"
    printf "• ssh_repair        - Fix common problems\n"
    printf "• setup_github      - Setup GitHub SSH\n"
    printf "• setup_gitlab      - Setup GitLab SSH\n"
    printf "• quick_ssh_key     - Generate key quickly\n"
    printf "• remove_ssh_setup  - Clean removal\n\n"
}

# Show troubleshooting guide
ssh_troubleshoot() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "      SSH Troubleshooting Guide"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    printf "Common Issues and Solutions:\n"
    printf "============================\n\n"
    
    printf "1. 'Permission denied (publickey)'\n"
    printf "   Causes:\n"
    printf "   • SSH key not added to your account\n"
    printf "   • Wrong key being used\n"
    printf "   • SSH agent not running\n"
    printf "   Solutions:\n"
    printf "   • Verify key is added: ssh_status\n"
    printf "   • Check SSH agent: ssh-add -l\n"
    printf "   • Test connection: ssh -T git@github.com\n\n"
    
    printf "2. 'Could not open a connection to your authentication agent'\n"
    printf "   Solution:\n"
    printf "   • Start SSH agent: eval \$(ssh-agent -s)\n"
    printf "   • Add your key: ssh-add ~/.ssh/your_key\n\n"
    
    printf "3. 'Bad permissions' errors\n"
    printf "   Solution:\n"
    printf "   • Fix with ssh_repair\n"
    printf "   • Or manually: chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*\n\n"
    
    printf "4. Wrong user being detected\n"
    printf "   Causes:\n"
    printf "   • Multiple keys for same service\n"
    printf "   • Wrong key loaded in agent\n"
    printf "   Solutions:\n"
    printf "   • Use IdentitiesOnly in SSH config\n"
    printf "   • Clear agent: ssh-add -D, then add specific key\n\n"
    
    printf "5. 'Host key verification failed'\n"
    printf "   Solution:\n"
    printf "   • Remove old host key: ssh-keygen -R hostname\n"
    printf "   • Accept new key when prompted\n\n"
    
    printf "6. Connection timeouts\n"
    printf "   Causes:\n"
    printf "   • Network issues\n"
    printf "   • Firewall blocking SSH (port 22)\n"
    printf "   Solutions:\n"
    printf "   • Try HTTPS instead temporarily\n"
    printf "   • Check firewall settings\n"
    printf "   • Use SSH over HTTPS (port 443)\n\n"
    
    printf "Debugging Commands:\n"
    printf "===================\n"
    printf "• ssh -T git@github.com          - Test GitHub connection\n"
    printf "• ssh -T git@gitlab.com          - Test GitLab connection\n"
    printf "• ssh -v git@github.com          - Verbose connection test\n"
    printf "• ssh-add -l                     - List loaded keys\n"
    printf "• ssh-add -D                     - Remove all keys from agent\n"
    printf "• ssh-keygen -lf ~/.ssh/key.pub  - Show key fingerprint\n\n"
    
    printf "Prevention Tips:\n"
    printf "================\n"
    printf "• Use different key files for different accounts\n"
    printf "• Keep backups of your SSH keys\n"
    printf "• Use descriptive key comments\n"
    printf "• Set up SSH config properly\n"
    printf "• Test connections after setup\n\n"
}

#================================================================#
# BACKUP AND RECOVERY
#================================================================#

# Backup SSH configuration
ssh_backup() {
    if [ ! -d "$SSH_DIR" ]; then
        _print_error "SSH directory not found: $SSH_DIR"
        return 1
    fi
    
    backup_dir="$HOME/ssh-backup-$(date +%Y%m%d-%H%M%S)"
    
    printf "Creating SSH backup...\n"
    printf "Backup location: %s\n" "$backup_dir"
    
    if mkdir -p "$backup_dir"; then
        # Copy SSH directory contents
        if cp -r "$SSH_DIR"/* "$backup_dir/" 2>/dev/null; then
            _print_success "SSH configuration backed up successfully"
            
            # Create backup info file
            cat > "$backup_dir/backup-info.txt" << EOF
SSH Backup Created: $(date)
Original location: $SSH_DIR
Hostname: $(hostname)
User: $(whoami)

Contents:
$(ls -la "$backup_dir/")

To restore:
1. Stop SSH agent: ssh-agent -k
2. Backup current: mv ~/.ssh ~/.ssh.old
3. Restore: cp -r $backup_dir ~/.ssh
4. Fix permissions: chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/*_ed25519 ~/.ssh/*_rsa
5. Start agent: eval \$(ssh-agent -s)
6. Load keys: ssh-add ~/.ssh/your_key
EOF
            
            printf "Backup includes:\n"
            ls -la "$backup_dir/" | sed 's/^/  /'
            printf "\nBackup info saved to: %s/backup-info.txt\n" "$backup_dir"
        else
            _print_error "Failed to copy SSH files"
            rmdir "$backup_dir" 2>/dev/null
            return 1
        fi
    else
        _print_error "Failed to create backup directory"
        return 1
    fi
}

# Restore SSH configuration from backup
ssh_restore() {
    if [ $# -eq 0 ]; then
        printf "Usage: ssh_restore <backup-directory>\n"
        printf "Available backups in %s:\n" "$HOME"
        ls -d "$HOME"/ssh-backup-* 2>/dev/null | sed 's|.*/||' | sed 's/^/  /' || printf "  (no backups found)\n"
        return 1
    fi
    
    backup_dir="$1"
    
    # Handle relative paths
    case "$backup_dir" in
        /*) ;;  # Absolute path
        *) backup_dir="$HOME/$backup_dir" ;;  # Relative to home
    esac
    
    if [ ! -d "$backup_dir" ]; then
        _print_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    printf "Restoring SSH configuration from backup...\n"
    printf "Backup: %s\n" "$backup_dir"
    printf "Target: %s\n" "$SSH_DIR"
    
    _print_warning "This will replace your current SSH configuration!"
    printf "Continue? (y/N): "
    read -r confirm
    case "$confirm" in
        [Yy]*) ;;
        *) 
            printf "Cancelled\n"
            return 0
            ;;
    esac
    
    # Backup current SSH config
    if [ -d "$SSH_DIR" ]; then
        current_backup="$HOME/ssh-current-backup-$(date +%Y%m%d-%H%M%S)"
        printf "Backing up current SSH config to: %s\n" "$current_backup"
        cp -r "$SSH_DIR" "$current_backup"
    fi
    
    # Restore from backup
    if cp -r "$backup_dir"/* "$SSH_DIR/" 2>/dev/null; then
        # Fix permissions
        chmod 700 "$SSH_DIR"
        chmod 600 "$SSH_DIR"/* 2>/dev/null
        chmod 644 "$SSH_DIR"/*.pub 2>/dev/null
        
        _print_success "SSH configuration restored successfully"
        
        # Restart SSH agent and load keys
        printf "Restarting SSH agent and loading keys...\n"
        ssh-agent -k 2>/dev/null
        eval "$(ssh-agent -s)" >/dev/null
        
        keys_loaded=0
        for key_file in "$SSH_DIR"/*; do
            [ ! -f "$key_file" ] && continue
            case "$(basename "$key_file")" in
                *_ed25519|*_rsa|id_ed25519|id_rsa|id_ecdsa|id_dsa)
                    if ssh-add "$key_file" 2>/dev/null; then
                        keys_loaded=$((keys_loaded + 1))
                    fi
                    ;;
            esac
        done
        
        if [ "$keys_loaded" -gt 0 ]; then
            _print_success "Loaded $keys_loaded SSH keys"
        fi
        
        printf "Run 'ssh_status' to verify the restoration\n"
    else
        _print_error "Failed to restore SSH configuration"
        return 1
    fi
}

#================================================================#
# HELPER FUNCTIONS (using existing utility functions)
#================================================================#

# These functions should be available from gitssh-utils.sh
# If not available, provide basic implementations

# Basic implementation if utility functions not available
_basic_print_color() {
    color="$1"
    text="$2"
    
    if [ -t 1 ]; then  # Check if stdout is a terminal
        case "$color" in
            red)    printf "\033[31m%s\033[0m" "$text" ;;
            green)  printf "\033[32m%s\033[0m" "$text" ;;
            yellow) printf "\033[33m%s\033[0m" "$text" ;;
            blue)   printf "\033[34m%s\033[0m" "$text" ;;
            *)      printf "%s" "$text" ;;
        esac
    else
        printf "%s" "$text"
    fi
}

_basic_print_error() {
    _basic_print_color red "Error: $1"
    printf "\n"
}

_basic_print_success() {
    _basic_print_color green "$1"
    printf "\n"
}

_basic_print_warning() {
    _basic_print_color yellow "Warning: $1"
    printf "\n"
}

_basic_print_info() {
    _basic_print_color blue "$1"
    printf "\n"
}

# Fallback function definitions if main utilities not loaded
if ! command -v _print_color >/dev/null 2>&1; then
    _print_color() { _basic_print_color "$@"; }
    _print_error() { _basic_print_error "$@"; }
    _print_success() { _basic_print_success "$@"; }
    _print_warning() { _basic_print_warning "$@"; }
    _print_info() { _basic_print_info "$@"; }
    
    _is_empty() {
        text="$1"
        trimmed=$(printf "%s" "$text" | sed 's/[[:space:]]//g')
        [ -z "$trimmed" ]
    }
    
    _trim() {
        printf "%s" "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }
    
    _to_lower() {
        printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
    }
    
    _validate_email() {
        case "$1" in
            *@*.*) return 0 ;;
            *) return 1 ;;
        esac
    }
    
    _validate_username() {
        case "$1" in
            *[!a-zA-Z0-9_-]*) return 1 ;;
            "") return 1 ;;
            *) return 0 ;;
        esac
    }
    
    _detect_os() {
        case "$(uname -s)" in
            Linux*) printf "linux" ;;
            Darwin*) printf "macos" ;;
            CYGWIN*) printf "windows" ;;
            MINGW*) printf "windows" ;;
            *) printf "unknown" ;;
        esac
    }
    
    _is_ssh_agent_running() {
        ssh-add -l >/dev/null 2>&1
    }
    
    _get_loaded_ssh_keys() {
        if _is_ssh_agent_running; then
            ssh-add -l 2>/dev/null
        fi
    }
    
    _test_ssh_connection() {
        ssh_host="$1"
        timeout="${2:-3}"
        ssh -o ConnectTimeout="$timeout" -T "git@$ssh_host" 2>&1 | grep -q "successfully authenticated\|Welcome to GitLab"
    }
    
    _create_temp_file() {
        mktemp 2>/dev/null || printf "/tmp/ssh-setup-$"
    }
    
    _safe_file_replace() {
        if [ -f "$1" ]; then
            mv "$1" "$2"
            return $?
        fi
        return 1
    }
    
    # Check for jq availability for session manager integration
    _check_dependencies() {
        command -v jq >/dev/null 2>&1
    }
fi

#================================================================#
# INITIALIZATION AND HELP
#================================================================#

# Show setup module help
ssh_setup_help() {
    printf "\n"
    _print_color blue "=========================================="
    printf "\n"
    _print_color blue "    Git-SSH Setup Module Help"
    printf "\n"
    _print_color blue "=========================================="
    printf "\n\n"
    
    printf "SETUP COMMANDS:\n"
    printf "===============\n"
    printf "setup_github        - Interactive GitHub SSH setup wizard\n"
    printf "setup_gitlab        - Interactive GitLab SSH setup wizard\n"
    printf "setup_github_multi  - Setup multiple GitHub accounts\n"
    printf "quick_ssh_key       - Quick key generation\n\n"
    
    printf "STATUS & DIAGNOSTICS:\n"
    printf "=====================\n"
    printf "ssh_status          - Show complete SSH setup status\n"
    printf "ssh_doctor          - Diagnose SSH connection issues\n"
    printf "ssh_repair          - Automatically fix common problems\n\n"
    
    printf "MANAGEMENT:\n"
    printf "===========\n"
    printf "ssh_backup          - Create backup of SSH configuration\n"
    printf "ssh_restore <dir>   - Restore from backup\n"
    printf "remove_ssh_setup    - Remove SSH setup for service\n\n"
    
    printf "LEARNING:\n"
    printf "=========\n"
    printf "ssh_learn           - Learn about SSH and Git\n"
    printf "ssh_troubleshoot    - Troubleshooting guide\n"
    printf "ssh_setup_help      - This help message\n\n"
    
    printf "GETTING STARTED:\n"
    printf "================\n"
    printf "1. Run 'setup_github' for GitHub setup\n"
    printf "2. Or 'setup_gitlab' for GitLab setup\n"
    printf "3. Use 'ssh_status' to verify setup\n"
    printf "4. Run 'git_user' to configure repository identity\n\n"
    
    printf "INTEGRATION:\n"
    printf "============\n"
    printf "This module integrates with the Git-SSH Session Manager.\n"
    printf "After SSH setup, use these commands:\n"
    printf "• git_user      - Configure user identity per repository\n"
    printf "• git_commit    - Enhanced commit with user verification\n"
    printf "• git_push      - Enhanced push with connection testing\n"
    printf "• ssh_remote    - Convert HTTPS repositories to SSH\n\n"
    
    printf "For more help: ssh_learn\n"
    printf "\n"
}

# Show all available functions
ssh_commands() {
    printf "\n"
    _print_color blue "Available SSH Setup Commands:"
    printf "\n"
    printf "========================================\n"
    
    # Core setup
    printf "\nSETUP:\n"
    printf "  setup_github       - GitHub SSH setup wizard\n"
    printf "  setup_gitlab       - GitLab SSH setup wizard\n"
    printf "  setup_github_multi - Multiple GitHub accounts\n"
    printf "  quick_ssh_key      - Quick key generation\n"
    
    # Status and diagnostics
    printf "\nSTATUS:\n"
    printf "  ssh_status         - Complete SSH status\n"
    printf "  ssh_doctor         - Diagnose issues\n"
    printf "  ssh_repair         - Fix common problems\n"
    
    # Management
    printf "\nMANAGEMENT:\n"
    printf "  ssh_backup         - Backup configuration\n"
    printf "  ssh_restore        - Restore from backup\n"
    printf "  remove_ssh_setup   - Remove service setup\n"
    
    # Help and learning
    printf "\nHELP:\n"
    printf "  ssh_learn          - Learning guide\n"
    printf "  ssh_troubleshoot   - Troubleshooting\n"
    printf "  ssh_setup_help     - Detailed help\n"
    printf "  ssh_commands       - This command list\n"
    
    printf "\n"
    _print_info "Start with: setup_github or setup_gitlab"
    printf "\n"
}