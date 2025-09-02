#!/bin/sh

#================================================================#
# GIT-SSH UTILITIES MODULE
# Core utility functions for Git-SSH User Session Manager
#================================================================#

#================================================================#
# DEPENDENCY CHECKING
#================================================================#

_check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        printf "Error: jq required but not found. Run 'gitssh_init' for setup instructions.\n"
        return 1
    fi
    return 0
}

#================================================================#
# REPOSITORY UTILITIES
#================================================================#

# Get repository identifier
_get_repo_id() {
    git rev-parse --show-toplevel 2>/dev/null || printf ""
}

# Extract username from remote URL
_extract_username_from_remote() {
    url="$1"
    case "$url" in
        *github.com[:/]*)
            printf "%s" "$url" | sed 's|.*github\.com[:/]\([^/]*\)/.*|\1|'
            ;;
        *)
            printf ""
            ;;
    esac
}

# Extract repository name from URL
_extract_repo_name() {
    local url="$1"
    local repo_name
    
    # Universal extraction: get everything after the last slash
    repo_name=$(printf "%s" "$url" | sed 's|.*/||')
    
    # Remove .git suffix only if it exists at the end
    repo_name=$(printf "%s" "$repo_name" | sed 's|\.git$||')
    
    printf "%s" "$repo_name"
}

# Check if in git repository
_is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Get current branch name
_get_current_branch() {
    git branch --show-current 2>/dev/null || printf ""
}

# Get remote URL
_get_remote_url() {
    remote_name="${1:-origin}"
    git remote get-url "$remote_name" 2>/dev/null || printf ""
}

#================================================================#
# USER DATA UTILITIES
#================================================================#

# Get all configured users
_get_configured_users() {
    _check_dependencies || return 1
    [ ! -f "$GIT_SSH_USERS_FILE" ] && return 1
    jq -r '.users | keys[]' "$GIT_SSH_USERS_FILE" 2>/dev/null
}

# Get user details by username
_get_user_details() {
    username="$1"
    _check_dependencies || return 1
    [ ! -f "$GIT_SSH_USERS_FILE" ] && return 1
    jq -r --arg user "$username" '.users[$user] // empty' "$GIT_SSH_USERS_FILE" 2>/dev/null
}

# Check if user exists in configuration
_user_exists() {
    username="$1"
    user_details=$(_get_user_details "$username")
    [ -n "$user_details" ] && [ "$user_details" != "null" ] && [ "$user_details" != "empty" ]
}

# Get user field value
_get_user_field() {
    username="$1"
    field="$2"
    user_details=$(_get_user_details "$username")
    if [ -n "$user_details" ] && [ "$user_details" != "null" ]; then
        printf "%s" "$user_details" | jq -r ".$field // empty"
    fi
}

#================================================================#
# SSH UTILITIES
#================================================================#

# Get SSH hosts from config
_get_ssh_hosts() {
    if [ -f "$HOME/.ssh/config" ]; then
        grep '^Host github-' "$HOME/.ssh/config" | awk '{print $2}'
    fi
}

# Test SSH connection
_test_ssh_connection() {
    ssh_host="$1"
    timeout="${2:-3}"
    ssh -o ConnectTimeout="$timeout" -T "git@$ssh_host" 2>&1 | grep -q "successfully authenticated"
}

# Check if SSH agent is running
_is_ssh_agent_running() {
    ssh-add -l >/dev/null 2>&1
}

# Get loaded SSH keys
_get_loaded_ssh_keys() {
    if _is_ssh_agent_running; then
        ssh-add -l
    fi
}

#================================================================#
# FILE UTILITIES
#================================================================#

# Validate JSON file structure
_validate_json_file() {
    file_path="$1"
    expected_structure="$2"
    
    [ ! -f "$file_path" ] && return 1
    
    if [ -n "$expected_structure" ]; then
        jq -e "$expected_structure" "$file_path" >/dev/null 2>&1
    else
        jq -e '.' "$file_path" >/dev/null 2>&1
    fi
}

# Create backup of file
_backup_file() {
    file_path="$1"
    backup_suffix="${2:-backup}"
    
    if [ -f "$file_path" ]; then
        cp "$file_path" "${file_path}.${backup_suffix}" 2>/dev/null
        return $?
    fi
    return 1
}

# Create temporary file safely
_create_temp_file() {
    mktemp
}

# Safe file replace using temporary file
_safe_file_replace() {
    source_file="$1"
    target_file="$2"
    
    if [ -f "$source_file" ]; then
        mv "$source_file" "$target_file"
        return $?
    fi
    return 1
}

#================================================================#
# INPUT/OUTPUT UTILITIES
#================================================================#

# Print colored output (if terminal supports it)
_print_color() {
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

# Print error message
_print_error() {
    _print_color red "Error: $1"
    printf "\n"
}

# Print success message
_print_success() {
    _print_color green "$1"
    printf "\n"
}

# Print warning message
_print_warning() {
    _print_color yellow "Warning: $1"
    printf "\n"
}

# Print info message
_print_info() {
    _print_color blue "$1"
    printf "\n"
}

#================================================================#
# VALIDATION UTILITIES
#================================================================#

# Validate email format (basic)
_validate_email() {
    email="$1"
    case "$email" in
        *@*.*) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate username (alphanumeric, dash, underscore)
_validate_username() {
    username="$1"
    case "$username" in
        *[!a-zA-Z0-9_-]*) return 1 ;;
        "") return 1 ;;
        *) return 0 ;;
    esac
}

# Check if string is empty or whitespace only
_is_empty() {
    text="$1"
    # Remove all whitespace and check if empty
    trimmed=$(printf "%s" "$text" | sed 's/[[:space:]]//g')
    [ -z "$trimmed" ]
}

#================================================================#
# CONFIGURATION UTILITIES
#================================================================#

# Get current git config values
_get_git_config() {
    config_key="$1"
    scope="${2:-}"  # Can be --global, --local, or empty for effective
    
    case "$scope" in
        global) git config --global "$config_key" 2>/dev/null ;;
        local)  git config --local "$config_key" 2>/dev/null ;;
        *)      git config "$config_key" 2>/dev/null ;;
    esac
}

# Set git config value
_set_git_config() {
    config_key="$1"
    config_value="$2"
    scope="${3:-local}"  # Default to local scope
    
    case "$scope" in
        global) git config --global "$config_key" "$config_value" ;;
        local)  git config --local "$config_key" "$config_value" ;;
        *)      git config "$config_key" "$config_value" ;;
    esac
}

# Get effective git user info
_get_effective_git_user() {
    name=$(_get_git_config "user.name")
    email=$(_get_git_config "user.email")
    
    if [ -n "$name" ] && [ -n "$email" ]; then
        printf "%s <%s>" "$name" "$email"
    else
        printf "Not configured"
    fi
}

#================================================================#
# STRING PROCESSING UTILITIES
#================================================================#

# Trim whitespace from string
_trim() {
    text="$1"
    # Remove leading and trailing whitespace
    printf "%s" "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Convert to lowercase
_to_lower() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert to uppercase
_to_upper() {
    printf "%s" "$1" | tr '[:lower:]' '[:upper:]'
}

# Count words in string
_count_words() {
    printf "%s" "$1" | wc -w
}

#================================================================#
# PLATFORM DETECTION
#================================================================#

# Detect operating system
_detect_os() {
    case "$(uname -s)" in
        Linux*)     printf "linux" ;;
        Darwin*)    printf "macos" ;;
        CYGWIN*)    printf "windows" ;;
        MINGW*)     printf "windows" ;;
        FreeBSD*)   printf "freebsd" ;;
        *)          printf "unknown" ;;
    esac
}

# Get package manager suggestions based on OS
_get_package_manager_hint() {
    os=$(_detect_os)
    case "$os" in
        linux)
            if command -v apt >/dev/null 2>&1; then
                printf "sudo apt install"
            elif command -v yum >/dev/null 2>&1; then
                printf "sudo yum install"
            elif command -v dnf >/dev/null 2>&1; then
                printf "sudo dnf install"
            elif command -v pacman >/dev/null 2>&1; then
                printf "sudo pacman -S"
            else
                printf "package manager install"
            fi
            ;;
        macos)
            if command -v brew >/dev/null 2>&1; then
                printf "brew install"
            else
                printf "brew install (install Homebrew first)"
            fi
            ;;
        *)
            printf "install via your package manager:"
            ;;
    esac
}