#!/bin/sh

#================================================================#
# GIT-SSH ENHANCED COMMANDS MODULE
# Enhanced versions of common Git commands with user verification
#================================================================#

#================================================================#
# REPOSITORY INFORMATION COMMANDS
#================================================================#

# Show detailed repository information
git_info() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi
    
    repo_id=$(_get_repo_id)
    
    printf "Repository Information\n"
    printf "=========================\n"
    printf "Repository: %s\n" "$(basename "$repo_id")"
    printf "Location: %s\n" "$repo_id"
    
    # Branch info
    current_branch=$(_get_current_branch)
    printf "Current branch: %s\n" "${current_branch:-unknown}"
    
    # User info
    effective_user=$(_get_effective_git_user)
    printf "Git user: %s\n" "$effective_user"
    
    # Session info
    session_user=$(_get_session_user "$repo_id")
    if [ -n "$session_user" ]; then
        printf "Session user: %s\n" "$session_user"
    fi
    
    # Remote info
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        printf "Remote: %s\n" "$origin_url"
        
        remote_user=$(_extract_username_from_remote "$origin_url")
        if [ -n "$remote_user" ]; then
            printf "Remote user: %s\n" "$remote_user"
            
            current_name=$(_get_git_config "user.name")
            if [ -n "$current_name" ] && [ "$remote_user" != "$current_name" ]; then
                _print_warning "User mismatch detected!"
            fi
        fi
        
        protocol=$(_get_remote_protocol "$origin_url")
        case "$protocol" in
            https)
                printf "Protocol: HTTPS\n"
                _print_info "Consider 'ssh_remote' for passwordless access"
                ;;
            ssh)
                printf "Protocol: SSH\n"
                ssh_host=$(_extract_ssh_host "$origin_url")
                if _test_ssh_connection "$ssh_host" 2; then
                    _print_success "SSH connection working"
                else
                    _print_warning "SSH connection failed"
                fi
                ;;
            *)
                printf "Protocol: %s\n" "$protocol"
                ;;
        esac
    else
        printf "Remote: Not configured\n"
    fi
    
    # Repository status
    status_output=$(git status --porcelain 2>/dev/null)
    if [ -n "$status_output" ]; then
        changes_count=$(printf "%s" "$status_output" | wc -l)
        printf "Working directory: %s uncommitted changes\n" "$changes_count"
    else
        printf "Working directory: Clean\n"
    fi
    
    # Last commit info
    if git rev-parse HEAD >/dev/null 2>&1; then
        last_commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
        last_commit_message=$(git log -1 --pretty=format:"%s" 2>/dev/null)
        last_commit_date=$(git log -1 --pretty=format:"%cr" 2>/dev/null)
        printf "Last commit: %s - \"%s\" (%s)\n" "$last_commit_hash" "$last_commit_message" "$last_commit_date"
    else
        printf "Last commit: No commits yet\n"
    fi
    
    # Show stash info if any
    stash_count=$(git stash list 2>/dev/null | wc -l)
    if [ "$stash_count" -gt 0 ]; then
        printf "Stashes: %s\n" "$stash_count"
    fi
}

# Enhanced git status with user info
git_status() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    repo_id=$(_get_repo_id)
    
    printf "Git Repository Status\n"
    printf "========================\n"
    printf "Repository: %s\n" "$(basename "$repo_id")"
    
    # Current user info
    effective_user=$(_get_effective_git_user)
    printf "Current user: %s\n" "$effective_user"
    
    # Session tracking
    session_user=$(_get_session_user "$repo_id")
    if [ -n "$session_user" ]; then
        printf "Session user: %s\n" "$session_user"
    fi
    
    # Remote info with warnings
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        printf "Remote: %s\n" "$origin_url"
        remote_user=$(_extract_username_from_remote "$origin_url")
        if [ -n "$remote_user" ]; then
            printf "Remote user: %s\n" "$remote_user"
            
            current_name=$(_get_git_config "user.name")
            if [ -n "$current_name" ] && [ "$remote_user" != "$current_name" ]; then
                _print_warning "User mismatch detected!"
            fi
        fi
        
        protocol=$(_get_remote_protocol "$origin_url")
        case "$protocol" in
            https)
                printf "Remote type: HTTPS "
                _print_color yellow "(consider 'ssh_remote' for passwordless)"
                printf "\n"
                ;;
            ssh)
                printf "Remote type: SSH\n"
                ;;
            *)
                printf "Remote type: %s\n" "$protocol"
                ;;
        esac
    fi
    
    printf "========================\n"
    
    # Standard git status
    git status "$@"
}

#================================================================#
# ENHANCED GIT COMMANDS WITH USER VERIFICATION
#================================================================#

# Enhanced git commit with user verification
git_commit() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    repo_id=$(_get_repo_id)
    
    # Check if user is configured in session
    if ! _has_session_user "$repo_id"; then
        _print_warning "No user set for this repository"
        session_set
        printf "\n"
    fi

    # Show who will be committing
    effective_user=$(_get_effective_git_user)
    printf "Committing as: %s\n" "$effective_user"
    
    # Check for user/remote mismatch
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        remote_user=$(_extract_username_from_remote "$origin_url")
        current_name=$(_get_git_config "user.name")
        
        if [ -n "$remote_user" ] && [ -n "$current_name" ] && [ "$remote_user" != "$current_name" ]; then
            _print_warning "User ($current_name) doesn't match remote user ($remote_user)"
            printf "Continue anyway? (y/N): "
            read -r continue_commit
            case "$continue_commit" in
                [Yy]*) ;;
                *) printf "Commit cancelled\n"; return 0 ;;
            esac
        fi
    fi
    
    # Execute commit
    git commit "$@"
}

# Enhanced git push with user verification  
git_push() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    repo_id=$(_get_repo_id)
    
    # Check if user is configured in session
    if ! _has_session_user "$repo_id"; then
        _print_warning "No user set for this repository"
        session_set
        printf "\n"
    fi

    # Show who will be pushing
    effective_user=$(_get_effective_git_user)
    printf "Pushing as: %s\n" "$effective_user"

    # Check remote type and provide tips
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        protocol=$(_get_remote_protocol "$origin_url")
        case "$protocol" in
            https)
                _print_info "Tip: Use 'ssh_remote' to avoid password prompts"
                ;;
            ssh)
                ssh_host=$(_extract_ssh_host "$origin_url")
                if ! _test_ssh_connection "$ssh_host" 2; then
                    _print_warning "SSH connection test failed - push may require authentication"
                fi
                ;;
        esac
        
        # Check for user/remote mismatch
        remote_user=$(_extract_username_from_remote "$origin_url")
        current_name=$(_get_git_config "user.name")
        
        if [ -n "$remote_user" ] && [ -n "$current_name" ] && [ "$remote_user" != "$current_name" ]; then
            _print_warning "User ($current_name) doesn't match remote user ($remote_user)"
            printf "Continue anyway? (y/N): "
            read -r continue_push
            case "$continue_push" in
                [Yy]*) ;;
                *) printf "Push cancelled\n"; return 0 ;;
            esac
        fi
    fi

    # Execute push
    git push "$@"
}

# Enhanced git clone with auto-setup
git_clone() {
    if [ $# -eq 0 ]; then
        printf "Usage: git_clone <repository-url> [directory]\n"
        printf "Enhanced clone with automatic user configuration\n"
        return 1
    fi
    
    repo_url="$1"
    clone_dir="$2"
    
    printf "Enhanced Git Clone\n"
    printf "====================\n"
    
    # Extract repository info
    case "$repo_url" in
        *github.com[:/]*)
            remote_user=$(_extract_username_from_remote "$repo_url")
            repo_name=$(_extract_repo_name "$repo_url")
            if [ -n "$remote_user" ] && [ -n "$repo_name" ]; then
                printf "Detected: %s/%s\n" "$remote_user" "$repo_name"
            fi
            ;;
    esac
    
    # Suggest SSH if HTTPS provided and user is configured
    protocol=$(_get_remote_protocol "$repo_url")
    if [ "$protocol" = "https" ] && [ -n "$remote_user" ]; then
        if _check_dependencies 2>/dev/null && _user_exists "$remote_user"; then
            user_details=$(_get_user_details "$remote_user")
            ssh_host=$(printf "%s" "$user_details" | jq -r '.ssh_host')
            
            if [ -n "$ssh_host" ] && [ "$ssh_host" != "null" ]; then
                ssh_url="git@${ssh_host}:${remote_user}/${repo_name}.git"
                printf "SSH alternative available for user '%s':\n" "$remote_user"
                printf "   %s\n" "$ssh_url"
                printf "Use SSH URL for passwordless access? (Y/n): "
                read -r use_ssh
                case "$use_ssh" in
                    [Nn]*) ;;
                    *) 
                        repo_url="$ssh_url"
                        _print_success "Switching to SSH URL"
                        ;;
                esac
            fi
        fi
    fi
    
    # Perform clone
    printf "Cloning repository...\n"
    if git clone "$repo_url" ${clone_dir:+"$clone_dir"}; then
        _print_success "Clone successful!"
        
        # Navigate to cloned directory
        if [ -n "$clone_dir" ]; then
            target_dir="$clone_dir"
        else
            target_dir="$repo_name"
        fi
        
        if [ -d "$target_dir" ]; then
            printf "Entering %s\n" "$target_dir"
            cd "$target_dir" || return 1
            printf "Setting up user configuration...\n"
            _git_auto_prompt
        fi
    else
        _print_error "Clone failed"
        return 1
    fi
}

# Enhanced git pull with user verification
git_pull() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    repo_id=$(_get_repo_id)
    
    # Show current user info
    effective_user=$(_get_effective_git_user)
    printf "Pulling as: %s\n" "$effective_user"

    # Check remote connection if SSH
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        protocol=$(_get_remote_protocol "$origin_url")
        if [ "$protocol" = "ssh" ]; then
            ssh_host=$(_extract_ssh_host "$origin_url")
            if ! _test_ssh_connection "$ssh_host" 2; then
                _print_warning "SSH connection test failed - pull may require authentication"
            fi
        fi
    fi

    # Execute pull
    git pull "$@"
}

# Enhanced git fetch with connection testing
git_fetch() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    # Test remote connection if SSH
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        protocol=$(_get_remote_protocol "$origin_url")
        if [ "$protocol" = "ssh" ]; then
            ssh_host=$(_extract_ssh_host "$origin_url")
            printf "Testing SSH connection to %s...\n" "$ssh_host"
            if _test_ssh_connection "$ssh_host" 3; then
                _print_success "SSH connection verified"
            else
                _print_warning "SSH connection failed - fetch may require authentication"
            fi
        fi
    fi

    # Execute fetch
    git fetch "$@"
}

#================================================================#
# REPOSITORY INITIALIZATION
#================================================================#

# Enhanced git init with user setup
git_init() {
    # Initialize repository
    if git init "$@"; then
        _print_success "Initialized git repository"
        
        # Auto-setup user if in the new repository
        if _is_git_repo; then
            printf "Setting up user configuration...\n"
            _git_auto_prompt
        fi
    else
        _print_error "Failed to initialize repository"
        return 1
    fi
}

#================================================================#
# BRANCH MANAGEMENT WITH USER CONTEXT
#================================================================#

# Show branch info with user context
git_branch_info() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    printf "Branch Information\n"
    printf "==================\n"
    
    # Current branch
    current_branch=$(_get_current_branch)
    printf "Current branch: %s\n" "${current_branch:-unknown}"
    
    # User info for commits
    effective_user=$(_get_effective_git_user)
    printf "Commits will be authored by: %s\n" "$effective_user"
    
    # Branch list
    printf "\nAll branches:\n"
    git branch -a
    
    # Remote tracking info
    if [ -n "$current_branch" ]; then
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            printf "\nUpstream: %s\n" "$upstream"
            
            # Check if ahead/behind
            ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
            if [ -n "$ahead_behind" ]; then
                ahead=$(printf "%s" "$ahead_behind" | awk '{print $1}')
                behind=$(printf "%s" "$ahead_behind" | awk '{print $2}')
                
                if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
                    printf "Status: "
                    [ "$ahead" -gt 0 ] && printf "%s commits ahead" "$ahead"
                    [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ] && printf ", "
                    [ "$behind" -gt 0 ] && printf "%s commits behind" "$behind"
                    printf "\n"
                else
                    printf "Status: Up to date\n"
                fi
            fi
        else
            printf "\nNo upstream branch configured\n"
        fi
    fi
}

#================================================================#
# WORKTREE MANAGEMENT
#================================================================#

# Enhanced git worktree with user setup
git_worktree_add() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    if [ $# -eq 0 ]; then
        printf "Usage: git_worktree_add <path> [branch]\n"
        return 1
    fi

    worktree_path="$1"
    branch_name="$2"
    
    # Create worktree
    if [ -n "$branch_name" ]; then
        git worktree add "$worktree_path" "$branch_name"
    else
        git worktree add "$worktree_path"
    fi
    
    worktree_result=$?
    
    if [ $worktree_result -eq 0 ] && [ -d "$worktree_path" ]; then
        printf "Setting up user configuration for worktree...\n"
        
        # Get current repository's user config
        repo_id=$(_get_repo_id)
        session_user=$(_get_session_user "$repo_id")
        
        if [ -n "$session_user" ]; then
            # Apply same user config to worktree
            saved_name=$(printf "%s" "$session_user" | sed 's/ <.*//')
            saved_email=$(printf "%s" "$session_user" | sed 's/.*<\(.*\)>.*/\1/')
            
            # Set user config in worktree
            git -C "$worktree_path" config user.name "$saved_name"
            git -C "$worktree_path" config user.email "$saved_email"
            
            _print_success "Applied user config to worktree: $session_user"
        else
            printf "No user config found for main repository\n"
            printf "Set up user config in worktree manually if needed\n"
        fi
    fi
    
    return $worktree_result
}

#================================================================#
# REPOSITORY ANALYSIS
#================================================================#

# Analyze repository for potential issues
git_analyze() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    repo_id=$(_get_repo_id)
    
    printf "Repository Analysis\n"
    printf "===================\n"
    printf "Repository: %s\n" "$(basename "$repo_id")"
    printf "\n"

    issues_found=0

    # Check user configuration
    printf "User Configuration:\n"
    effective_user=$(_get_effective_git_user)
    printf "  Current: %s\n" "$effective_user"
    
    current_name=$(_get_git_config "user.name")
    current_email=$(_get_git_config "user.email")
    
    if [ -z "$current_name" ] || [ -z "$current_email" ]; then
        _print_warning "  Issue: Incomplete user configuration"
        printf "  Fix: Run 'session_set' to configure\n"
        issues_found=$((issues_found + 1))
    fi

    # Check remote configuration
    printf "\nRemote Configuration:\n"
    origin_url=$(_get_remote_url)
    if [ -n "$origin_url" ]; then
        protocol=$(_get_remote_protocol "$origin_url")
        printf "  Origin: %s (%s)\n" "$origin_url" "$protocol"
        
        if [ "$protocol" = "https" ] && _is_github_https_url "$origin_url"; then
            _print_warning "  Issue: Using HTTPS (requires password for push)"
            printf "  Fix: Run 'ssh_remote' to convert to SSH\n"
            issues_found=$((issues_found + 1))
        fi
        
        # Check user/remote mismatch
        remote_user=$(_extract_username_from_remote "$origin_url")
        if [ -n "$remote_user" ] && [ -n "$current_name" ] && [ "$remote_user" != "$current_name" ]; then
            _print_warning "  Issue: User mismatch (git: $current_name, remote: $remote_user)"
            printf "  Fix: Use 'session_set' to select correct user\n"
            issues_found=$((issues_found + 1))
        fi
    else
        _print_warning "  Issue: No origin remote configured"
        issues_found=$((issues_found + 1))
    fi

    # Check SSH connection if applicable
    if [ -n "$origin_url" ] && [ "$protocol" = "ssh" ]; then
        printf "\nSSH Connection:\n"
        ssh_host=$(_extract_ssh_host "$origin_url")
        if _test_ssh_connection "$ssh_host" 3; then
            _print_success "  SSH connection working"
        else
            _print_warning "  Issue: SSH connection failed"
            printf "  Fix: Check SSH key configuration for %s\n" "$ssh_host"
            issues_found=$((issues_found + 1))
        fi
    fi

    # Check for uncommitted changes
    printf "\nWorking Directory:\n"
    if git diff --quiet && git diff --staged --quiet; then
        _print_success "  Clean working directory"
    else
        _print_info "  Uncommitted changes present"
        printf "  Note: Remember to commit changes before switching users\n"
    fi

    # Summary
    printf "\nAnalysis Summary:\n"
    if [ "$issues_found" -eq 0 ]; then
        _print_success "No issues found - repository is properly configured"
    else
        _print_warning "Found $issues_found issue(s) that may need attention"
    fi
    
    return "$issues_found"
}

#================================================================#
# ADDITIONAL ENHANCED COMMANDS
#================================================================#

# Enhanced git log with user context
git_log_user() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    # Show commits by current user
    current_email=$(_get_git_config "user.email")
    if [ -n "$current_email" ]; then
        printf "Commits by current user (%s):\n" "$current_email"
        printf "=====================================\n"
        git log --author="$current_email" --oneline "$@"
    else
        _print_warning "No user email configured"
        git log --oneline "$@"
    fi
}

# Show repository configuration summary
git_config_summary() {
    if ! _is_git_repo; then
        _print_error "Not in a git repository"
        return 1
    fi

    repo_id=$(_get_repo_id)
    
    printf "Git Configuration Summary\n"
    printf "=========================\n"
    printf "Repository: %s\n" "$(basename "$repo_id")"
    
    # User configuration
    printf "\nUser Configuration:\n"
    global_name=$(_get_git_config "user.name" "global")
    global_email=$(_get_git_config "user.email" "global")
    local_name=$(_get_git_config "user.name" "local")
    local_email=$(_get_git_config "user.email" "local")
    effective_user=$(_get_effective_git_user)
    
    printf "  Global:    %s <%s>\n" "${global_name:-Not set}" "${global_email:-Not set}"
    printf "  Local:     %s <%s>\n" "${local_name:-Not set}" "${local_email:-Not set}"
    printf "  Effective: %s\n" "$effective_user"
    
    # Session information
    session_user=$(_get_session_user "$repo_id")
    if [ -n "$session_user" ]; then
        printf "  Session:   %s\n" "$session_user"
    fi
    
    # Remote configuration
    printf "\nRemote Configuration:\n"
    remotes_output=$(_get_all_remotes)
    if [ -n "$remotes_output" ]; then
        while IFS= read -r line; do
            remote_name=$(printf "%s" "$line" | awk '{print $1}')
            remote_url=$(printf "%s" "$line" | awk '{print $2}')
            remote_type=$(printf "%s" "$line" | awk '{print $3}')
            
            [ "$remote_type" != "(fetch)" ] && continue
            
            protocol=$(_get_remote_protocol "$remote_url")
            printf "  %s: %s (%s)\n" "$remote_name" "$remote_url" "$protocol"
        done << EOF
$remotes_output
EOF
    else
        printf "  No remotes configured\n"
    fi
    
    # Other Git configuration
    printf "\nOther Settings:\n"
    core_editor=$(_get_git_config "core.editor")
    init_branch=$(_get_git_config "init.defaultBranch")
    printf "  Editor: %s\n" "${core_editor:-Not set}"
    printf "  Default branch: %s\n" "${init_branch:-Not set}"
}