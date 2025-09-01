#!/bin/sh

#================================================================#
# GIT-SSH REMOTE MANAGEMENT MODULE
# Functions for managing Git remotes and SSH conversion
#================================================================#

#================================================================#
# REMOTE DETECTION AND VALIDATION
#================================================================#

# Check if URL is a GitHub HTTPS URL
_is_github_https_url() {
    url="$1"
    case "$url" in
        https://github.com/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Check if URL is a GitHub SSH URL
_is_github_ssh_url() {
    url="$1"
    case "$url" in
        git@github.com:*) return 0 ;;
        git@github-*:*) return 0 ;;
        *) return 1 ;;
    esac
}

# Extract repository path from GitHub URL
_extract_repo_path() {
    url="$1"
    case "$url" in
        https://github.com/*)
            printf "%s" "$url" | sed 's|https://github\.com/||' | sed 's|\.git$||'
            ;;
        git@github.com:*)
            printf "%s" "$url" | sed 's|git@github\.com:||' | sed 's|\.git$||'
            ;;
        git@github-*:*)
            printf "%s" "$url" | sed 's|git@github-[^:]*:||' | sed 's|\.git$||'
            ;;
        *)
            printf ""
            ;;
    esac
}

# Get SSH host from SSH URL
_extract_ssh_host() {
    url="$1"
    case "$url" in
        git@*:*)
            printf "%s" "$url" | sed 's|git@\([^:]*\):.*|\1|'
            ;;
        *)
            printf ""
            ;;
    esac
}

#================================================================#
# REMOTE CONVERSION FUNCTIONS
#================================================================#

# Convert HTTPS remote to SSH
ssh_remote() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    printf "Current git remotes:\n"
    git remote -v | sed 's/^/  /'
    printf "\n"

    origin_url=$(_get_remote_url)
    if [ -z "$origin_url" ]; then
        _print_error "No 'origin' remote found"
        return 1
    fi

    # Check if already using SSH with custom host
    if _is_github_ssh_url "$origin_url"; then
        ssh_host=$(_extract_ssh_host "$origin_url")
        case "$ssh_host" in
            github-*)
                _print_info "Already using SSH with custom host: $origin_url"
                return 0
                ;;
            github.com)
                _print_info "Using default GitHub SSH, consider converting to custom host"
                ;;
        esac
    fi

    # Validate GitHub HTTPS URL
    if ! _is_github_https_url "$origin_url"; then
        _print_error "Only GitHub HTTPS URLs are supported"
        printf "Current URL: %s\n" "$origin_url"
        return 1
    fi

    # Extract repository info
    repo_path=$(_extract_repo_path "$origin_url")
    username=$(printf "%s" "$repo_path" | cut -d'/' -f1)
    repo_name=$(printf "%s" "$repo_path" | cut -d'/' -f2)

    printf "Detected GitHub repository: %s/%s\n" "$username" "$repo_name"

    # Get available SSH hosts
    ssh_hosts=$(_get_ssh_hosts)
    
    if [ -z "$ssh_hosts" ]; then
        _print_error "No GitHub SSH hosts found in ~/.ssh/config"
        printf "You need to set up SSH hosts first. Example ~/.ssh/config entry:\n"
        printf "\n"
        printf "Host github-%s\n" "$username"
        printf "    HostName github.com\n"
        printf "    User git\n"
        printf "    IdentityFile ~/.ssh/id_rsa_%s\n" "$username"
        printf "\n"
        return 1
    fi

    # Show SSH host options
    _show_ssh_host_options "$ssh_hosts" "$username" "$repo_path"
}

# Show available SSH hosts with recommendations
_show_ssh_host_options() {
    ssh_hosts="$1"
    repo_username="$2"
    repo_path="$3"
    
    printf "Available SSH hosts:\n"
    i=1
    recommended_choice=""
    
    for host in $ssh_hosts; do
        host_user=$(printf "%s" "$host" | sed 's/github-//')
        
        # Check if this host matches the repository owner
        if [ "$host_user" = "$repo_username" ]; then
            printf "  %d. %s (matches repository owner - RECOMMENDED)\n" "$i" "$host"
            recommended_choice="$i"
        else
            printf "  %d. %s\n" "$i" "$host"
        fi
        i=$((i + 1))
    done
    printf "\n"

    # Get user selection
    host_count=$(printf "%s" "$ssh_hosts" | wc -w)
    
    # Auto-select if there's a clear recommendation
    if [ -n "$recommended_choice" ]; then
        printf "Auto-select recommended host? (Y/n): "
        read -r auto_select
        case "$auto_select" in
            [Nn]*) choice="" ;;
            *) choice="$recommended_choice" ;;
        esac
    fi
    
    # Get manual selection if needed
    while [ -z "$choice" ]; do
        printf "Select SSH host (1-%d): " "$host_count"
        read -r choice
        if [ "$choice" -ge 1 ] && [ "$choice" -le "$host_count" ] 2>/dev/null; then
            break
        fi
        printf "Invalid choice. Please enter a number between 1 and %d\n" "$host_count"
        choice=""
    done

    selected_host=$(printf "%s" "$ssh_hosts" | sed -n "${choice}p")
    _convert_remote_to_ssh "$selected_host" "$repo_path"
}

# Convert remote URL to SSH format
_convert_remote_to_ssh() {
    ssh_host="$1"
    repo_path="$2"
    
    origin_url=$(_get_remote_url)
    new_url="git@${ssh_host}:${repo_path}.git"
    
    printf "Converting remote URL:\n"
    printf "  From: %s\n" "$origin_url"
    printf "  To:   %s\n" "$new_url"
    printf "\n"

    printf "Proceed with this change? (y/N): "
    read -r confirm
    case "$confirm" in
        [Yy]*) ;;
        *) printf "Cancelled\n"; return 0 ;;
    esac

    if _update_remote_url "origin" "$new_url"; then
        _print_success "Successfully updated remote URL"
        printf "Updated remotes:\n"
        git remote -v | sed 's/^/  /'
        
        printf "Testing SSH connection...\n"
        if _test_ssh_connection "$ssh_host" 5; then
            _print_success "SSH connection successful!"
            _print_info "You can now use 'git push' without entering a password"
        else
            _print_warning "SSH connection test failed. Please check your SSH setup."
        fi
    else
        _print_error "Failed to update remote URL"
        return 1
    fi
}

#================================================================#
# REMOTE MANAGEMENT UTILITIES
#================================================================#

# Update remote URL
_update_remote_url() {
    remote_name="$1"
    new_url="$2"
    
    git remote set-url "$remote_name" "$new_url"
}

# Get all remotes information
_get_all_remotes() {
    git remote -v 2>/dev/null
}

# Check if remote exists
_remote_exists() {
    remote_name="$1"
    git remote get-url "$remote_name" >/dev/null 2>&1
}

# Add new remote
_add_remote() {
    remote_name="$1"
    remote_url="$2"
    
    git remote add "$remote_name" "$remote_url"
}

# Remove remote
_remove_remote() {
    remote_name="$1"
    
    git remote remove "$remote_name"
}

#================================================================#
# ADVANCED REMOTE OPERATIONS
#================================================================#

# Convert all HTTPS remotes to SSH
ssh_remote_all() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    printf "Converting all HTTPS remotes to SSH...\n"
    printf "=====================================\n"

    # Get all remotes
    remotes_output=$(_get_all_remotes)
    if [ -z "$remotes_output" ]; then
        _print_info "No remotes configured"
        return 0
    fi

    # Find HTTPS GitHub remotes
    https_remotes=""
    while IFS= read -r line; do
        remote_name=$(printf "%s" "$line" | awk '{print $1}')
        remote_url=$(printf "%s" "$line" | awk '{print $2}')
        remote_type=$(printf "%s" "$line" | awk '{print $3}')
        
        # Only process fetch URLs and GitHub HTTPS
        if [ "$remote_type" = "(fetch)" ] && _is_github_https_url "$remote_url"; then
            https_remotes="$https_remotes $remote_name:$remote_url"
        fi
    done << EOF
$remotes_output
EOF

    if [ -z "$https_remotes" ]; then
        _print_info "No GitHub HTTPS remotes found"
        return 0
    fi

    # Process each HTTPS remote
    converted_count=0
    for remote_info in $https_remotes; do
        remote_name=$(printf "%s" "$remote_info" | cut -d':' -f1)
        remote_url=$(printf "%s" "$remote_info" | cut -d':' -f2-)
        
        printf "\nProcessing remote '%s':\n" "$remote_name"
        printf "  URL: %s\n" "$remote_url"
        
        repo_path=$(_extract_repo_path "$remote_url")
        username=$(printf "%s" "$repo_path" | cut -d'/' -f1)
        
        # Find matching SSH host
        ssh_host=$(_find_matching_ssh_host "$username")
        
        if [ -n "$ssh_host" ]; then
            new_url="git@${ssh_host}:${repo_path}.git"
            printf "  Converting to: %s\n" "$new_url"
            
            if _update_remote_url "$remote_name" "$new_url"; then
                _print_success "  Converted $remote_name"
                converted_count=$((converted_count + 1))
            else
                _print_error "  Failed to convert $remote_name"
            fi
        else
            _print_warning "  No matching SSH host found for user '$username'"
            printf "  Skipping remote '%s'\n" "$remote_name"
        fi
    done

    printf "\nConversion Summary:\n"
    printf "  Converted %d remote(s)\n" "$converted_count"
    
    if [ "$converted_count" -gt 0 ]; then
        printf "\nUpdated remotes:\n"
        git remote -v | sed 's/^/  /'
    fi
}

# Check remote URL format and suggest improvements
check_remote() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    printf "Remote Analysis:\n"
    printf "================\n"

    remotes_output=$(_get_all_remotes)
    if [ -z "$remotes_output" ]; then
        _print_info "No remotes configured"
        return 0
    fi

    # Analyze each remote
    while IFS= read -r line; do
        remote_name=$(printf "%s" "$line" | awk '{print $1}')
        remote_url=$(printf "%s" "$line" | awk '{print $2}')
        remote_type=$(printf "%s" "$line" | awk '{print $3}')
        
        # Only analyze fetch URLs
        [ "$remote_type" != "(fetch)" ] && continue
        
        printf "\nRemote: %s\n" "$remote_name"
        printf "  URL: %s\n" "$remote_url"
        
        if _is_github_https_url "$remote_url"; then
            printf "  Type: GitHub HTTPS\n"
            _print_warning "  Recommendation: Convert to SSH for passwordless access"
            printf "  Use: ssh_remote\n"
            
            # Check if user has matching SSH host
            repo_path=$(_extract_repo_path "$remote_url")
            username=$(printf "%s" "$repo_path" | cut -d'/' -f1)
            ssh_host=$(_find_matching_ssh_host "$username")
            
            if [ -n "$ssh_host" ]; then
                _print_success "  Matching SSH host available: $ssh_host"
            else
                _print_info "  No matching SSH host found for user '$username'"
            fi
            
        elif _is_github_ssh_url "$remote_url"; then
            printf "  Type: GitHub SSH\n"
            ssh_host=$(_extract_ssh_host "$remote_url")
            
            # Test connection
            if _test_ssh_connection "$ssh_host" 3; then
                _print_success "  Status: SSH connection working"
            else
                _print_warning "  Status: SSH connection failed"
            fi
            
        else
            printf "  Type: Other/Unknown\n"
            _print_info "  Status: Not a GitHub repository"
        fi
        
    done << EOF
$remotes_output
EOF
}

# Add SSH remote for different user
add_ssh_remote() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    # Get repository info
    origin_url=$(_get_remote_url)
    if [ -z "$origin_url" ]; then
        _print_error "No origin remote found"
        return 1
    fi

    repo_path=$(_extract_repo_path "$origin_url")
    if [ -z "$repo_path" ]; then
        _print_error "Cannot extract repository path from origin URL"
        return 1
    fi

    repo_name=$(printf "%s" "$repo_path" | cut -d'/' -f2)
    
    printf "Add SSH remote for different user\n"
    printf "=================================\n"
    printf "Repository: %s\n" "$repo_name"
    printf "Current origin: %s\n" "$origin_url"
    printf "\n"

    # Show available SSH hosts
    ssh_hosts=$(_get_ssh_hosts)
    if [ -z "$ssh_hosts" ]; then
        _print_error "No SSH hosts configured"
        return 1
    fi

    printf "Available SSH hosts:\n"
    i=1
    for host in $ssh_hosts; do
        host_user=$(printf "%s" "$host" | sed 's/github-//')
        printf "  %d. %s (user: %s)\n" "$i" "$host" "$host_user"
        i=$((i + 1))
    done
    printf "\n"

    # Get selection
    host_count=$(printf "%s" "$ssh_hosts" | wc -w)
    while true; do
        printf "Select SSH host (1-%d): " "$host_count"
        read -r choice
        if [ "$choice" -ge 1 ] && [ "$choice" -le "$host_count" ] 2>/dev/null; then
            break
        fi
        printf "Invalid choice\n"
    done

    selected_host=$(printf "%s" "$ssh_hosts" | sed -n "${choice}p")
    selected_user=$(printf "%s" "$selected_host" | sed 's/github-//')
    
    # Get remote name
    printf "Remote name [%s]: " "$selected_user"
    read -r remote_name
    remote_name=${remote_name:-$selected_user}
    
    # Check if remote already exists
    if _remote_exists "$remote_name"; then
        _print_warning "Remote '$remote_name' already exists"
        printf "Overwrite? (y/N): "
        read -r overwrite
        case "$overwrite" in
            [Yy]*) ;;
            *) printf "Cancelled\n"; return 0 ;;
        esac
    fi

    # Create new remote URL with different user
    new_repo_path="${selected_user}/${repo_name}"
    new_url="git@${selected_host}:${new_repo_path}.git"
    
    printf "Adding remote:\n"
    printf "  Name: %s\n" "$remote_name"
    printf "  URL:  %s\n" "$new_url"
    printf "\n"

    printf "Add this remote? (Y/n): "
    read -r confirm
    case "$confirm" in
        [Nn]*) printf "Cancelled\n"; return 0 ;;
    esac

    if _remote_exists "$remote_name"; then
        if _update_remote_url "$remote_name" "$new_url"; then
            _print_success "Updated remote '$remote_name'"
        else
            _print_error "Failed to update remote"
            return 1
        fi
    else
        if _add_remote "$remote_name" "$new_url"; then
            _print_success "Added remote '$remote_name'"
        else
            _print_error "Failed to add remote"
            return 1
        fi
    fi

    printf "Testing SSH connection...\n"
    if _test_ssh_connection "$selected_host" 5; then
        _print_success "SSH connection successful!"
    else
        _print_warning "SSH connection failed - check your SSH setup"
    fi

    printf "\nCurrent remotes:\n"
    git remote -v | sed 's/^/  /'
}

#================================================================#
# PRIVATE HELPER FUNCTIONS
#================================================================#

# Find SSH host that matches username
_find_matching_ssh_host() {
    target_username="$1"
    ssh_hosts=$(_get_ssh_hosts)
    
    for host in $ssh_hosts; do
        host_user=$(printf "%s" "$host" | sed 's/github-//')
        if [ "$host_user" = "$target_username" ]; then
            printf "%s" "$host"
            return 0
        fi
    done
    
    return 1
}

# Get SSH host suggestions based on configured users
_get_ssh_host_suggestions() {
    repo_username="$1"
    
    # First, try to find exact match
    ssh_host=$(_find_matching_ssh_host "$repo_username")
    if [ -n "$ssh_host" ]; then
        printf "exact:%s" "$ssh_host"
        return 0
    fi
    
    # If no exact match, suggest creating one
    if _check_dependencies 2>/dev/null && _user_exists "$repo_username"; then
        user_details=$(_get_user_details "$repo_username")
        suggested_host=$(printf "%s" "$user_details" | jq -r '.ssh_host')
        printf "suggested:%s" "$suggested_host"
        return 0
    fi
    
    printf "none:"
    return 1
}

# Validate SSH host format
_validate_ssh_host() {
    ssh_host="$1"
    
    case "$ssh_host" in
        github-*) return 0 ;;
        github.com) return 0 ;;
        *) return 1 ;;
    esac
}

# Get remote protocol type
_get_remote_protocol() {
    remote_url="$1"
    
    case "$remote_url" in
        https://*) printf "https" ;;
        git@*:*) printf "ssh" ;;
        *) printf "unknown" ;;
    esac
}

# Show remote recommendations
show_remote_recommendations() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    printf "Remote Recommendations:\n"
    printf "=======================\n"

    origin_url=$(_get_remote_url)
    if [ -z "$origin_url" ]; then
        _print_info "No origin remote configured"
        return 0
    fi

    protocol=$(_get_remote_protocol "$origin_url")
    printf "Current origin: %s (%s)\n" "$origin_url" "$protocol"

    case "$protocol" in
        https)
            if _is_github_https_url "$origin_url"; then
                _print_info "Recommendation: Convert to SSH for passwordless access"
                printf "  Command: ssh_remote\n"
                
                repo_path=$(_extract_repo_path "$origin_url")
                username=$(printf "%s" "$repo_path" | cut -d'/' -f1)
                
                suggestions=$(_get_ssh_host_suggestions "$username")
                case "$suggestions" in
                    exact:*)
                        host=$(printf "%s" "$suggestions" | cut -d':' -f2)
                        _print_success "  Matching SSH host available: $host"
                        ;;
                    suggested:*)
                        host=$(printf "%s" "$suggestions" | cut -d':' -f2)
                        _print_info "  Suggested SSH host: $host"
                        ;;
                    none:*)
                        _print_warning "  No SSH host configured for user '$username'"
                        printf "  Consider adding SSH host configuration\n"
                        ;;
                esac
            else
                _print_info "Non-GitHub HTTPS remote - no specific recommendations"
            fi
            ;;
        ssh)
            if _is_github_ssh_url "$origin_url"; then
                ssh_host=$(_extract_ssh_host "$origin_url")
                printf "SSH remote configured: %s\n" "$ssh_host"
                
                if _test_ssh_connection "$ssh_host" 3; then
                    _print_success "SSH connection working properly"
                else
                    _print_warning "SSH connection not working"
                    printf "  Check SSH key configuration for %s\n" "$ssh_host"
                fi
            else
                _print_info "Non-GitHub SSH remote"
            fi
            ;;
        *)
            _print_warning "Unknown remote protocol"
            ;;
    esac

    printf "\nAll remotes:\n"
    git remote -v | sed 's/^/  /'
}

#================================================================#
# BULK REMOTE OPERATIONS
#================================================================#

# List all remotes with detailed information
list_remotes() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    printf "Repository Remotes\n"
    printf "==================\n"

    remotes_output=$(_get_all_remotes)
    if [ -z "$remotes_output" ]; then
        _print_info "No remotes configured"
        return 0
    fi

    # Group by remote name
    current_remote=""
    while IFS= read -r line; do
        remote_name=$(printf "%s" "$line" | awk '{print $1}')
        remote_url=$(printf "%s" "$line" | awk '{print $2}')
        remote_type=$(printf "%s" "$line" | awk '{print $3}')
        
        if [ "$remote_name" != "$current_remote" ]; then
            [ -n "$current_remote" ] && printf "\n"
            printf "Remote: %s\n" "$remote_name"
            current_remote="$remote_name"
        fi
        
        protocol=$(_get_remote_protocol "$remote_url")
        printf "  %s: %s (%s)\n" "$remote_type" "$remote_url" "$protocol"
        
        # Additional info for GitHub remotes
        if _is_github_https_url "$remote_url" || _is_github_ssh_url "$remote_url"; then
            repo_path=$(_extract_repo_path "$remote_url")
            username=$(printf "%s" "$repo_path" | cut -d'/' -f1)
            printf "    GitHub user: %s\n" "$username"
            
            if [ "$protocol" = "ssh" ]; then
                ssh_host=$(_extract_ssh_host "$remote_url")
                if _test_ssh_connection "$ssh_host" 2; then
                    _print_color green "    SSH: Connected"
                    printf "\n"
                else
                    _print_color red "    SSH: Failed"
                    printf "\n"
                fi
            fi
        fi
    done << EOF
$remotes_output
EOF
}
#================================================================#
# gitssh-remotes.sh refactoring
#================================================================#

# Replacing ssh_remote() with:
remote_convert() {
    ssh_remote "$@"  # Keeping existing implementation
}

# Replacing add_ssh_remote() with:
remote_add() {
    add_ssh_remote "$@"  # Keeping existing implementation
}

# Replacing check_remote() with:
remote_check() {
    check_remote "$@"  # Keeping existing implementation
}

# Add new function:
remote_list() {
    list_remotes "$@"  # Keeping existing implementation
}

remote_recommendations() {
    show_remote_recommendations "$@"  # Keeping existing implementation
}