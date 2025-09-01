#!/bin/sh

#================================================================#
# GIT-SSH SESSION MANAGEMENT MODULE
# Functions for managing user sessions and persistent storage
#================================================================#

#================================================================#
# PERSISTENT STORAGE FUNCTIONS
#================================================================#

# Get persistent user configuration for repository
_get_persistent_user() {
    repo_id="$1"
    _check_dependencies || return 1
    [ -f "$GIT_SSH_CONFIG_FILE" ] && jq -r --arg repo "$repo_id" '.[$repo] // empty' "$GIT_SSH_CONFIG_FILE" 2>/dev/null
}

# Save persistent user configuration for repository
_save_persistent_user() {
    repo_id="$1" 
    user_info="$2"
    _check_dependencies || return 1
    
    temp_file=$(_create_temp_file)
    if jq --arg repo "$repo_id" --arg user "$user_info" '.[$repo] = $user' "$GIT_SSH_CONFIG_FILE" > "$temp_file"; then
        _safe_file_replace "$temp_file" "$GIT_SSH_CONFIG_FILE"
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Remove persistent user configuration for repository
_remove_persistent_user() {
    repo_id="$1"
    _check_dependencies || return 1
    
    temp_file=$(_create_temp_file)
    if jq --arg repo "$repo_id" 'del(.[$repo])' "$GIT_SSH_CONFIG_FILE" > "$temp_file"; then
        _safe_file_replace "$temp_file" "$GIT_SSH_CONFIG_FILE"
    else
        rm -f "$temp_file"
        return 1
    fi
}

#================================================================#
# SESSION STORAGE FUNCTIONS
#================================================================#

# Get session user for repository
_get_session_user() {
    repo_id="$1"
    [ -f "$GIT_SESSION_TEMP" ] && grep "^$repo_id:" "$GIT_SESSION_TEMP" | cut -d: -f2- 2>/dev/null
}

# Save session user for repository
_save_session_user() {
    repo_id="$1"
    user_info="$2"
    
    # Remove existing entry for this repo
    if [ -f "$GIT_SESSION_TEMP" ]; then
        grep -v "^$repo_id:" "$GIT_SESSION_TEMP" > "$GIT_SESSION_TEMP.tmp" 2>/dev/null || true
        mv "$GIT_SESSION_TEMP.tmp" "$GIT_SESSION_TEMP" 2>/dev/null || true
    fi
    
    # Add new entry
    printf "%s:%s\n" "$repo_id" "$user_info" >> "$GIT_SESSION_TEMP"
}

# Remove session user for repository
_remove_session_user() {
    repo_id="$1"
    
    if [ -f "$GIT_SESSION_TEMP" ]; then
        grep -v "^$repo_id:" "$GIT_SESSION_TEMP" > "$GIT_SESSION_TEMP.tmp" 2>/dev/null || true
        mv "$GIT_SESSION_TEMP.tmp" "$GIT_SESSION_TEMP" 2>/dev/null || true
    fi
}

# Check if user is set in current session
_has_session_user() {
    repo_id="$1"
    session_user=$(_get_session_user "$repo_id")
    [ -n "$session_user" ]
}

#================================================================#
# USER SESSION MANAGEMENT
#================================================================#

# Set git user/session for current repository
session_set() {
    # Handle CLI arguments
    target_user=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --user)
                target_user="$2"
                shift 2
                ;;
            --help|-h)
                printf "Usage: gitssh session set [--user <username>]\n"
                return 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    repo_id=$(_get_repo_id)
    if [ -z "$repo_id" ]; then
        _print_error "Not in a git repository"
        return 1
    fi
    
    if [ -n "$target_user" ]; then
        # Non-interactive mode
        if ! _user_exists "$target_user"; then
            _print_error "User '$target_user' not found"
            return 1
        fi
        _apply_configured_user "$repo_id" "$target_user"
    else
        # Interactive mode (keep existing git_user logic)
        _interactive_user_selection "$repo_id"
    fi
}

# Auto-prompt when entering repositories
_git_auto_prompt() {
    repo_id=$(_get_repo_id)
    [ -z "$repo_id" ] && return 0
    
    # Skip if already configured in session
    if _has_session_user "$repo_id"; then
        session_user=$(_get_session_user "$repo_id")
        printf "Session user for %s: %s\n" "$(basename "$repo_id")" "$session_user"
        return 0
    fi

    # Check for saved configuration
    persistent_user=$(_get_persistent_user "$repo_id")
    
    if [ -n "$persistent_user" ] && [ "$persistent_user" != "null" ] && [ "$persistent_user" != "empty" ]; then
        printf "Found saved config for %s: %s\n" "$(basename "$repo_id")" "$persistent_user"
        
        saved_name=$(printf "%s" "$persistent_user" | sed 's/ <.*//')
        saved_email=$(printf "%s" "$persistent_user" | sed 's/.*<\(.*\)>.*/\1/')
        
        _set_git_config "user.name" "$saved_name" "local"
        _set_git_config "user.email" "$saved_email" "local"
        _save_session_user "$repo_id" "$persistent_user"
        
        printf "Use saved config? (Y/n): "
        read -r use_saved
        case "$use_saved" in
            [Nn]*)
                git_user
                ;;
            *)
                _print_success "Applied saved configuration"
                
                # Show quick status
                origin_url=$(_get_remote_url)
                case "$origin_url" in
                    https://github.com/*)
                        _print_info "Tip: Use 'ssh_remote' for passwordless access"
                        ;;
                esac
                ;;
        esac
        return 0
    fi

    # New repository setup
    printf "Git Repository Detected: %s\n" "$(basename "$repo_id")"
    
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        printf "Remote: %s\n" "$origin_url"
        remote_user=$(_extract_username_from_remote "$origin_url")
        [ -n "$remote_user" ] && printf "Remote user: %s\n" "$remote_user"
        
        case "$origin_url" in
            https://github.com/*)
                printf "Using HTTPS remote\n"
                _print_info "Tip: Use 'ssh_remote' to convert to SSH for passwordless access"
                ;;
        esac
    fi
    
    current_name=$(_get_git_config "user.name" "local")
    current_email=$(_get_git_config "user.email" "local")

    if [ -n "$current_name" ] && [ -n "$current_email" ]; then
        printf "Current user: %s <%s>\n" "$current_name" "$current_email"
        
        # Check for user/remote mismatch
        if [ -n "$remote_user" ] && [ "$remote_user" != "$current_name" ]; then
            _print_warning "Git user ($current_name) doesn't match remote user ($remote_user)"
            
            # Suggest matching user if available
            if _check_dependencies 2>/dev/null && _user_exists "$remote_user"; then
                _print_info "You have '$remote_user' configured - use 'git_user' to switch"
            fi
        fi
        
        printf "\n"
        printf "Use current user for this repository? (Y/n): "
        read -r keep_user
        case "$keep_user" in
            [Nn]*)
                git_user
                ;;
            *)
                user_info="$current_name <$current_email>"
                _save_session_user "$repo_id" "$user_info"
                _save_persistent_user "$repo_id" "$user_info"
                _print_success "Saved current user for future sessions"
                ;;
        esac
    else
        printf "No git user configured for this repository\n"
        printf "Setting up user configuration...\n"
        git_user
    fi
    printf "\n"
}

#================================================================#
# SESSION MANAGEMENT COMMANDS
#================================================================#

# Show current session and persistent configurations
session_show() {
    case "$1" in
        --verbose|-v)
            _show_detailed_session_info
            ;;
        *)
            _show_basic_session_info
            ;;
    esac
}

session_clear() {
    rm -f "$GIT_SESSION_TEMP"
    _print_success "Cleared session mappings"
}

session_forget() {
    repo_id=$(_get_repo_id)
    if [ -z "$repo_id" ]; then
        _print_error "Not in a git repository"
        return 1
    fi

    if _check_dependencies && [ -f "$GIT_SSH_CONFIG_FILE" ]; then
        _remove_persistent_user "$repo_id"
        _remove_session_user "$repo_id"
        _print_success "Removed config for $(basename "$repo_id")"
    fi
}
#================================================================#
# PRIVATE HELPER FUNCTIONS
#================================================================#

# Handle custom user input
_handle_custom_user_input() {
    repo_id="$1"
    
    printf "Enter name: "
    read -r custom_name
    custom_name=$(_trim "$custom_name")
    
    if _is_empty "$custom_name"; then
        _print_error "Name cannot be empty"
        return 1
    fi
    
    printf "Enter email: "
    read -r custom_email
    custom_email=$(_trim "$custom_email")
    
    if _is_empty "$custom_email"; then
        _print_error "Email cannot be empty"
        return 1
    fi
    
    if ! _validate_email "$custom_email"; then
        _print_error "Invalid email format"
        return 1
    fi
    
    _set_git_config "user.name" "$custom_name" "local"
    _set_git_config "user.email" "$custom_email" "local"
    
    user_info="$custom_name <$custom_email>"
    _save_session_user "$repo_id" "$user_info"
    _save_persistent_user "$repo_id" "$user_info"
    
    _print_success "Set custom user: $user_info"
}

# Apply configured user to repository
_apply_configured_user() {
    repo_id="$1"
    username="$2"
    
    user_details=$(_get_user_details "$username")
    name=$(printf "%s" "$user_details" | jq -r '.name')
    email=$(printf "%s" "$user_details" | jq -r '.email')
    
    _set_git_config "user.name" "$name" "local"
    _set_git_config "user.email" "$email" "local"
    
    user_info="$name <$email>"
    _save_session_user "$repo_id" "$user_info"
    _save_persistent_user "$repo_id" "$user_info"
    
    _print_success "Set user: $user_info"
}

#================================================================#
# SESSION VALIDATION AND CLEANUP
#================================================================#

# Validate session file integrity
_validate_session_file() {
    [ ! -f "$GIT_SESSION_TEMP" ] && return 0  # No file is valid
    
    # Check if file has valid format (repo_path:user_info)
    while IFS=: read -r repo_path user_info; do
        if [ -z "$repo_path" ] || [ -z "$user_info" ]; then
            return 1  # Invalid format
        fi
        # Check if repo_path exists and is a git repository
        if [ ! -d "$repo_path" ] || ! git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
            # Repository no longer exists, mark for cleanup
            continue
        fi
    done < "$GIT_SESSION_TEMP"
    
    return 0
}

# Clean up session entries for non-existent repositories
_cleanup_invalid_sessions() {
    [ ! -f "$GIT_SESSION_TEMP" ] && return 0
    
    temp_file=$(_create_temp_file)
    
    while IFS=: read -r repo_path user_info; do
        # Keep entry only if repository still exists
        if [ -d "$repo_path" ] && git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
            printf "%s:%s\n" "$repo_path" "$user_info" >> "$temp_file"
        fi
    done < "$GIT_SESSION_TEMP"
    
    _safe_file_replace "$temp_file" "$GIT_SESSION_TEMP"
}

# Get session statistics
_get_session_stats() {
    active_repos=0
    invalid_repos=0
    
    if [ -f "$GIT_SESSION_TEMP" ]; then
        while IFS=: read -r repo_path user_info; do
            if [ -d "$repo_path" ] && git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
                active_repos=$((active_repos + 1))
            else
                invalid_repos=$((invalid_repos + 1))
            fi
        done < "$GIT_SESSION_TEMP"
    fi
    
    printf "active:%d,invalid:%d" "$active_repos" "$invalid_repos"
}

#================================================================#
# ADVANCED SESSION OPERATIONS
#================================================================#

# List all repositories in current session
git_session_list() {
    printf "Session Repositories:\n"
    printf "====================\n"
    
    if [ ! -f "$GIT_SESSION_TEMP" ] || [ ! -s "$GIT_SESSION_TEMP" ]; then
        printf "  (no repositories in session)\n"
        return 0
    fi
    
    i=1
    while IFS=: read -r repo_path user_info; do
        repo_name=$(basename "$repo_path")
        
        # Check if repository still exists
        if [ -d "$repo_path" ] && git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
            printf "  %d. %s\n" "$i" "$repo_name"
            printf "     Path: %s\n" "$repo_path"
            printf "     User: %s\n" "$user_info"
            
            # Show current branch if possible
            current_branch=$(git -C "$repo_path" branch --show-current 2>/dev/null)
            [ -n "$current_branch" ] && printf "     Branch: %s\n" "$current_branch"
            
            printf "\n"
            i=$((i + 1))
        fi
    done < "$GIT_SESSION_TEMP"
    
    # Show statistics
    stats=$(_get_session_stats)
    active=$(printf "%s" "$stats" | cut -d',' -f1 | cut -d':' -f2)
    invalid=$(printf "%s" "$stats" | cut -d',' -f2 | cut -d':' -f2)
    
    printf "Session Summary: %s active repositories" "$active"
    if [ "$invalid" -gt 0 ]; then
        printf ", %s invalid entries (use git_session_cleanup)" "$invalid"
    fi
    printf "\n"
}

# Clean up invalid session entries
git_session_cleanup() {
    printf "Cleaning up session...\n"
    
    stats_before=$(_get_session_stats)
    invalid_before=$(printf "%s" "$stats_before" | cut -d',' -f2 | cut -d':' -f2)
    
    if [ "$invalid_before" -eq 0 ]; then
        _print_info "No cleanup needed"
        return 0
    fi
    
    _cleanup_invalid_sessions
    
    stats_after=$(_get_session_stats)
    active_after=$(printf "%s" "$stats_after" | cut -d',' -f1 | cut -d':' -f2)
    
    _print_success "Removed $invalid_before invalid entries, $active_after repositories remain"
}

# Export session to file
git_session_export() {
    output_file="${1:-git-session-export.json}"
    
    if [ ! -f "$GIT_SESSION_TEMP" ] || [ ! -s "$GIT_SESSION_TEMP" ]; then
        _print_info "No session data to export"
        return 0
    fi
    
    temp_file=$(_create_temp_file)
    printf '{\n  "session_repositories": {\n' > "$temp_file"
    
    first=true
    while IFS=: read -r repo_path user_info; do
        if [ -d "$repo_path" ] && git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
            if [ "$first" = "false" ]; then
                printf ',\n' >> "$temp_file"
            fi
            
            repo_name=$(basename "$repo_path")
            printf '    "%s": {"path": "%s", "user": "%s"}' "$repo_name" "$repo_path" "$user_info" >> "$temp_file"
            first=false
        fi
    done < "$GIT_SESSION_TEMP"
    
    printf '\n  },\n  "export_date": "%s"\n}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$temp_file"
    
    if _safe_file_replace "$temp_file" "$output_file"; then
        _print_success "Session exported to $output_file"
    else
        _print_error "Failed to export session"
        return 1
    fi
}

# Import session from file
git_session_import() {
    import_file="${1:-git-session-export.json}"
    
    if [ ! -f "$import_file" ]; then
        _print_error "Import file not found: $import_file"
        return 1
    fi
    
    if ! _validate_json_file "$import_file" ".session_repositories"; then
        _print_error "Invalid import file format"
        return 1
    fi
    
    printf "Importing session from: %s\n" "$import_file"
    
    # Show what will be imported
    printf "Session data to import:\n"
    jq -r '.session_repositories | to_entries[] | "  " + .key + ": " + .value.user' "$import_file" 2>/dev/null
    
    printf "\nProceed with import? (y/N): "
    read -r confirm
    case "$confirm" in
        [Yy]*) ;;
        *) printf "Import cancelled\n"; return 0 ;;
    esac
    
    # Import session data
    imported_count=0
    while IFS= read -r line; do
        repo_name=$(printf "%s" "$line" | jq -r '.key')
        repo_path=$(printf "%s" "$line" | jq -r '.value.path')
        user_info=$(printf "%s" "$line" | jq -r '.value.user')
        
        # Validate repository exists
        if [ -d "$repo_path" ] && git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
            _save_session_user "$repo_path" "$user_info"
            imported_count=$((imported_count + 1))
        else
            _print_warning "Skipping missing repository: $repo_path"
        fi
    done << EOF
$(jq -c '.session_repositories | to_entries[]' "$import_file" 2>/dev/null)
EOF
    
    _print_success "Imported $imported_count repository sessions"
}

session_list() {
    _git_session_list  # Keeping existing implementation
}

session_cleanup() {
    _cleanup_invalid_sessions  # Keeping existing implementation
}

session_export() {
    _git_session_export "$@"  # Keeping existing implementation
}

session_import() {
    _git_session_import "$@"  # Keeping existing implementation  
}
