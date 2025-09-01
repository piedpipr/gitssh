#!/bin/sh

#================================================================#
# GIT-SSH INITIALIZATION MODULE
# Functions for setting up and validating the Git-SSH system
#================================================================#

#================================================================#
# DEPENDENCY INSTALLATION HELPERS
#================================================================#

# Show installation instructions for jq
_show_jq_installation() {
    printf "jq is required but not installed\n"
    printf "Install with:\n"
    
    os=$(_detect_os)
    case "$os" in
        linux)
            if command -v apt >/dev/null 2>&1; then
                printf "   Ubuntu/Debian: sudo apt install jq\n"
            fi
            if command -v yum >/dev/null 2>&1; then
                printf "   CentOS/RHEL: sudo yum install jq\n"
            fi
            if command -v dnf >/dev/null 2>&1; then
                printf "   Fedora: sudo dnf install jq\n"
            fi
            if command -v pacman >/dev/null 2>&1; then
                printf "   Arch: sudo pacman -S jq\n"
            fi
            ;;
        macos)
            if command -v brew >/dev/null 2>&1; then
                printf "   macOS (Homebrew): brew install jq\n"
            else
                printf "   macOS: Install Homebrew first, then 'brew install jq'\n"
            fi
            ;;
        *)
            manager_hint=$(_get_package_manager_hint)
            printf "   %s jq\n" "$manager_hint"
            ;;
    esac
}

# Check and install dependencies
_check_and_setup_dependencies() {
    missing_deps=""
    
    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps="jq"
    fi
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps="$missing_deps git"
    fi
    
    # Check for ssh
    if ! command -v ssh >/dev/null 2>&1; then
        missing_deps="$missing_deps openssh-client"
    fi
    
    if [ -n "$missing_deps" ]; then
        _print_error "Missing required dependencies: $missing_deps"
        
        for dep in $missing_deps; do
            case "$dep" in
                jq) _show_jq_installation ;;
                git) printf "Install Git from: https://git-scm.com/downloads\n" ;;
                openssh-client) printf "Install OpenSSH client via your package manager\n" ;;
            esac
        done
        
        return 1
    fi
    
    return 0
}

#================================================================#
# CONFIGURATION FILE INITIALIZATION
#================================================================#

# Initialize sessions configuration file
_init_sessions_config() {
    if [ ! -f "$GIT_SSH_CONFIG_FILE" ]; then
        printf '{}' > "$GIT_SSH_CONFIG_FILE"
        _print_success "Created sessions config: $GIT_SSH_CONFIG_FILE"
        return 0
    else
        # Validate existing file
        if _validate_json_file "$GIT_SSH_CONFIG_FILE"; then
            printf "Sessions config exists: %s\n" "$GIT_SSH_CONFIG_FILE"
            return 0
        else
            _print_warning "Invalid sessions config detected, recreating..."
            _backup_file "$GIT_SSH_CONFIG_FILE" "invalid-backup"
            printf '{}' > "$GIT_SSH_CONFIG_FILE"
            _print_success "Recreated sessions config"
            return 0
        fi
    fi
}

# Initialize users configuration file
_init_users_config() {
    create_users_config=false
    
    if [ ! -f "$GIT_SSH_USERS_FILE" ]; then
        create_users_config=true
        printf "Creating new users config...\n"
    elif ! _validate_json_file "$GIT_SSH_USERS_FILE" ".users"; then
        create_users_config=true
        printf "Repairing invalid users config...\n"
        _backup_file "$GIT_SSH_USERS_FILE" "backup"
        printf "Backed up existing config to %s.backup\n" "$GIT_SSH_USERS_FILE"
    fi
    
    if [ "$create_users_config" = "true" ]; then
        _create_default_users_config
    else
        printf "Users config exists: %s\n" "$GIT_SSH_USERS_FILE"
    fi
}

# Create default users configuration
_create_default_users_config() {
    # Try to detect existing SSH hosts
    printf "Detecting SSH hosts from ~/.ssh/config...\n"
    detected_users=""
    if [ -f "$HOME/.ssh/config" ]; then
        while IFS= read -r line; do
            case "$line" in
                Host\ github-*)
                    user=$(printf "%s" "$line" | sed 's/Host github-//' | awk '{print $1}')
                    if [ -n "$user" ] && _validate_username "$user"; then
                        detected_users="$detected_users $user"
                    fi
                    ;;
            esac
        done < "$HOME/.ssh/config"
    fi
    
    # Create config file
    temp_file=$(_create_temp_file)
    {
        printf '{\n'
        printf '  "users": {\n'
        
        if [ -n "$detected_users" ]; then
            printf "Found SSH hosts for: %s\n" "$detected_users" >&2
            
            first=true
            for user in $detected_users; do
                if [ "$first" = "false" ]; then
                    printf ',\n'
                fi
                printf '    "%s": {"name": "%s", "email": "%s@example.com", "ssh_host": "github-%s"}' \
                    "$user" "$user" "$user" "$user"
                first=false
            done
            printf '\n'
        else
            printf "Creating template with example users...\n" >&2
            printf '    "user1": {"name": "user1", "email": "user1@example.com", "ssh_host": "github-user1"},\n'
            printf '    "user2": {"name": "user2", "email": "user2@example.com", "ssh_host": "github-user2"}\n'
        fi
        
        printf '  }\n'
        printf '}\n'
    } > "$temp_file"

    if _safe_file_replace "$temp_file" "$GIT_SSH_USERS_FILE"; then
        _print_success "Created users config: $GIT_SSH_USERS_FILE"
        printf "Please edit the file to set correct email addresses:\n"
        printf "    nano %s\n" "$GIT_SSH_USERS_FILE"
        return 0
    else
        _print_error "Failed to create users config"
        rm -f "$temp_file"
        return 1
    fi
}

#================================================================#
# CONFIGURATION VALIDATION
#================================================================#

# Validate configuration files
_validate_config() {
    need_init=false
    validation_errors=""
    
    # Check if config files exist
    if [ ! -f "$GIT_SSH_CONFIG_FILE" ]; then
        validation_errors="$validation_errors missing_sessions_config"
        need_init=true
    elif ! _validate_json_file "$GIT_SSH_CONFIG_FILE"; then
        validation_errors="$validation_errors invalid_sessions_config"
        need_init=true
    fi
    
    if [ ! -f "$GIT_SSH_USERS_FILE" ]; then
        validation_errors="$validation_errors missing_users_config"
        need_init=true
    elif ! _validate_json_file "$GIT_SSH_USERS_FILE" ".users"; then
        validation_errors="$validation_errors invalid_users_config"
        need_init=true
    fi
    
    # Check dependencies
    if ! _check_dependencies 2>/dev/null; then
        validation_errors="$validation_errors missing_dependencies"
        need_init=true
    fi
    
    if [ "$need_init" = "true" ]; then
        if [ -n "$validation_errors" ]; then
            printf "Configuration issues detected: %s\n" "$(printf "%s" "$validation_errors" | tr '_' ' ')"
        fi
        printf "Running initialization...\n"
        git_ssh_init
    fi
}

# Validate and repair configuration
git_ssh_validate() {
    printf "Validating Git-SSH Configuration\n"
    printf "================================\n"
    
    issues_found=0
    
    # Check dependencies
    printf "Dependencies:\n"
    if command -v jq >/dev/null 2>&1; then
        _print_success "  jq: Available"
    else
        _print_error "  jq: Missing"
        _show_jq_installation
        issues_found=$((issues_found + 1))
    fi
    
    if command -v git >/dev/null 2>&1; then
        _print_success "  git: Available"
    else
        _print_error "  git: Missing"
        issues_found=$((issues_found + 1))
    fi
    
    if command -v ssh >/dev/null 2>&1; then
        _print_success "  ssh: Available"
    else
        _print_error "  ssh: Missing"
        issues_found=$((issues_found + 1))
    fi
    
    # Check configuration files
    printf "\nConfiguration Files:\n"
    
    if [ -f "$GIT_SSH_CONFIG_FILE" ]; then
        if _validate_json_file "$GIT_SSH_CONFIG_FILE"; then
            _print_success "  Sessions config: Valid"
        else
            _print_error "  Sessions config: Invalid JSON"
            issues_found=$((issues_found + 1))
        fi
    else
        _print_warning "  Sessions config: Missing"
        issues_found=$((issues_found + 1))
    fi
    
    if [ -f "$GIT_SSH_USERS_FILE" ]; then
        if _validate_json_file "$GIT_SSH_USERS_FILE" ".users"; then
            _print_success "  Users config: Valid"
            
            # Show user count
            if _check_dependencies 2>/dev/null; then
                user_count=$(jq '.users | length' "$GIT_SSH_USERS_FILE" 2>/dev/null)
                printf "    Users configured: %s\n" "${user_count:-0}"
            fi
        else
            _print_error "  Users config: Invalid structure"
            issues_found=$((issues_found + 1))
        fi
    else
        _print_warning "  Users config: Missing"
        issues_found=$((issues_found + 1))
    fi
    
    # Check SSH configuration
    printf "\nSSH Configuration:\n"
    ssh_hosts=$(_get_ssh_hosts)
    if [ -n "$ssh_hosts" ]; then
        host_count=$(printf "%s" "$ssh_hosts" | wc -w)
        _print_success "  SSH hosts found: $host_count"
        
        for host in $ssh_hosts; do
            if _test_ssh_connection "$host" 2; then
                _print_success "    $host: Connected"
            else
                _print_warning "    $host: Connection failed"
            fi
        done
    else
        _print_warning "  No GitHub SSH hosts found in ~/.ssh/config"
        printf "    Add SSH host configurations to use SSH features\n"
    fi
    
    # Summary
    printf "\nValidation Summary:\n"
    if [ "$issues_found" -eq 0 ]; then
        _print_success "Configuration is valid and ready to use"
    else
        _print_warning "Found $issues_found issue(s)"
        printf "Run 'git_ssh_init' to fix configuration issues\n"
    fi
    
    return "$issues_found"
}

#================================================================#
# MAIN INITIALIZATION FUNCTION
#================================================================#

# Initialize configuration files with default structure
git_ssh_init() {
    printf "Initializing Git-SSH User Session Manager...\n"
    printf "=============================================\n"
    
    # Check and setup dependencies
    if ! _check_and_setup_dependencies; then
        return 1
    fi
    
    # Initialize configuration files
    _init_sessions_config || return 1
    _init_users_config || return 1
    
    # Validate final configuration
    if _validate_final_config; then
        _print_success "Initialization complete!"
        printf "Use 'git_add_user' to add more users interactively\n"
        printf "Use 'git_ssh_help' for full command reference\n"
        return 0
    else
        _print_error "Initialization failed validation"
        return 1
    fi
}

# Final configuration validation after initialization
_validate_final_config() {
    printf "Validating configuration...\n"
    
    # Check sessions config
    if ! _validate_json_file "$GIT_SSH_CONFIG_FILE"; then
        _print_error "Sessions configuration is invalid"
        return 1
    fi
    
    # Check users config
    if ! _validate_json_file "$GIT_SSH_USERS_FILE" ".users"; then
        _print_error "Users configuration is invalid"
        return 1
    fi
    
    # Show configuration summary
    if _check_dependencies 2>/dev/null; then
        user_count=$(jq '.users | length' "$GIT_SSH_USERS_FILE" 2>/dev/null)
        printf "Configuration valid with %s user(s)\n" "${user_count:-0}"
        
        if [ "$user_count" -gt 0 ]; then
            printf "Configured users:\n"
            jq -r '.users | to_entries[] | "  * " + .key + ": " + .value.email' "$GIT_SSH_USERS_FILE" 2>/dev/null
        fi
    fi
    
    return 0
}

#================================================================#
# MIGRATION AND UPGRADE FUNCTIONS
#================================================================#

# Migrate from old configuration format (if needed)
git_ssh_migrate() {
    printf "Checking for migration needs...\n"
    
    migration_needed=false
    
    # Check for old format files (example)
    old_config_file="$HOME/.git-ssh-config"
    if [ -f "$old_config_file" ]; then
        printf "Found old configuration file: %s\n" "$old_config_file"
        migration_needed=true
    fi
    
    if [ "$migration_needed" = "false" ]; then
        _print_info "No migration needed"
        return 0
    fi
    
    printf "Migration required. Proceed? (Y/n): "
    read -r proceed
    case "$proceed" in
        [Nn]*) printf "Migration cancelled\n"; return 0 ;;
    esac
    
    # Backup existing configurations
    if [ -f "$GIT_SSH_CONFIG_FILE" ]; then
        _backup_file "$GIT_SSH_CONFIG_FILE" "pre-migration"
    fi
    if [ -f "$GIT_SSH_USERS_FILE" ]; then
        _backup_file "$GIT_SSH_USERS_FILE" "pre-migration"
    fi
    
    # Perform migration
    _print_info "Migration completed"
    printf "Old configuration files backed up\n"
}

# Reset configuration to defaults
git_ssh_reset() {
    printf "Reset Git-SSH Configuration\n"
    printf "===========================\n"
    printf "This will remove all configuration and start fresh\n"
    printf "Are you sure? (y/N): "
    read -r confirm
    
    case "$confirm" in
        [Yy]*) ;;
        *) printf "Reset cancelled\n"; return 0 ;;
    esac
    
    # Backup existing configurations
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -f "$GIT_SSH_CONFIG_FILE" ]; then
        _backup_file "$GIT_SSH_CONFIG_FILE" "reset-$backup_timestamp"
        rm -f "$GIT_SSH_CONFIG_FILE"
        printf "Backed up and removed: %s\n" "$GIT_SSH_CONFIG_FILE"
    fi
    
    if [ -f "$GIT_SSH_USERS_FILE" ]; then
        _backup_file "$GIT_SSH_USERS_FILE" "reset-$backup_timestamp"
        rm -f "$GIT_SSH_USERS_FILE"
        printf "Backed up and removed: %s\n" "$GIT_SSH_USERS_FILE"
    fi
    
    # Clear session data
    rm -f "$GIT_SESSION_TEMP"
    printf "Cleared session data\n"
    
    # Reinitialize
    printf "\nReinitializing...\n"
    git_ssh_init
}

#================================================================#
# SYSTEM INFORMATION
#================================================================#

# Show system information relevant to Git-SSH
git_ssh_system_info() {
    printf "Git-SSH System Information\n"
    printf "==========================\n"
    
    # Operating System
    os=$(_detect_os)
    printf "Operating System: %s\n" "$os"
    
    # Shell information
    printf "Shell: %s\n" "${SHELL:-unknown}"
    
    # Git version
    if command -v git >/dev/null 2>&1; then
        git_version=$(git --version 2>/dev/null | head -1)
        printf "Git: %s\n" "$git_version"
    else
        printf "Git: Not installed\n"
    fi
    
    # SSH version
    if command -v ssh >/dev/null 2>&1; then
        ssh_version=$(ssh -V 2>&1 | head -1)
        printf "SSH: %s\n" "$ssh_version"
    else
        printf "SSH: Not installed\n"
    fi
    
    # jq version
    if command -v jq >/dev/null 2>&1; then
        jq_version=$(jq --version 2>/dev/null)
        printf "jq: %s\n" "$jq_version"
    else
        printf "jq: Not installed\n"
    fi
    
    # Configuration paths
    printf "\nConfiguration Files:\n"
    printf "  Sessions: %s\n" "$GIT_SSH_CONFIG_FILE"
    printf "  Users:    %s\n" "$GIT_SSH_USERS_FILE"
    printf "  SSH Config: %s\n" "$HOME/.ssh/config"
    
    # File status
    printf "\nFile Status:\n"
    for file in "$GIT_SSH_CONFIG_FILE" "$GIT_SSH_USERS_FILE" "$HOME/.ssh/config"; do
        if [ -f "$file" ]; then
            size=$(wc -c < "$file" 2>/dev/null)
            printf "  %s: exists (%s bytes)\n" "$(basename "$file")" "$size"
        else
            printf "  %s: missing\n" "$(basename "$file")"
        fi
    done
    
    # SSH Agent status
    printf "\nSSH Agent:\n"
    if _is_ssh_agent_running; then
        key_count=$(ssh-add -l 2>/dev/null | wc -l)
        printf "  Status: Running (%s keys loaded)\n" "$key_count"
    else
        printf "  Status: Not running or no keys loaded\n"
    fi
    
    # GitHub SSH hosts
    printf "\nGitHub SSH Hosts:\n"
    ssh_hosts=$(_get_ssh_hosts)
    if [ -n "$ssh_hosts" ]; then
        for host in $ssh_hosts; do
            printf "  %s\n" "$host"
        done
    else
        printf "  (none configured)\n"
    fi
}
#================================================================#
# gitssh-init.sh refactoring
#================================================================#

# Replace git_ssh_init() with:
system_init() {
    git_ssh_init "$@"  # Keep existing implementation
}

# Replace git_ssh_onboard() with:
system_onboard() {
    git_ssh_onboard "$@"  # Keep existing implementation
}

# Replace git_ssh_validate() with:
system_validate() {
    git_ssh_validate "$@"  # Keep existing implementation
}

# Add new functions:
system_check_configured() {
    # Quick check if system is already configured
    _check_dependencies 2>/dev/null && [ -f "$GIT_SSH_USERS_FILE" ] && \
    jq -e '.users | length > 0' "$GIT_SSH_USERS_FILE" >/dev/null 2>&1
}

config_show() {
    git_ssh_system_info "$@"  # Keep existing implementation
}

config_reset() {
    git_ssh_reset "$@"  # Keep existing implementation  
}

config_backup() {
    git_ssh_backup "$@"  # Keep existing implementation
}

config_restore() {
    git_ssh_restore "$@"  # Keep existing implementation
}

config_migrate() {
    git_ssh_migrate "$@"  # Keep existing implementation
}