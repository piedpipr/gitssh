<img width="702" height="970" alt="Screenshot From 2025-09-02 04-34-31" src="https://github.com/user-attachments/assets/aeccf679-e6e1-4a72-861a-1f75389a7e3c" />

---
# GitSSH
```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║            ██████╗         ███████╗███████╗██╗  ██╗           ║
║           ██╔════╝ ██╗ ██╗ ██╔════╝██╔════╝██║  ██║           ║
║           ██║  ███╗══╝████║███████╗███████╗███████║           ║
║           ██║   ██║██║ ██║ ╚════██║╚════██║██╔══██║           ║
║            ██████╔╝██║ ██║ ███████║███████║██║  ██║           ║
║            ╚═════╝ ╚═╝ ╚═╝ ╚══════╝╚══════╝╚═╝  ╚═╝v1.0-Oz    ║
║                     <-POSIX Compatible->                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
Manage multiple Git, GitHub & GitLab SSH account seesions with ease! 
```

**A small tool to manage multiple Git accounts (GitHub, GitLab etc.) with SSH — without losing your mind.**

---

## Why GitSSH?

If you’ve ever had to juggle a personal GitHub, a work GitHub, maybe a client’s GitLab, and even a random Bitbucket repo — you already know the pain:

* **SSH keys get mixed up** → wrong key, wrong account, failed authentication.
* **Git configs change constantly** → `user.name` and `user.email` never stay correct.
* **HTTPS is annoying** → constantly typing passwords or PATs.
* **Identity confusion** → commits end up under the wrong user.
* **Manual SSH config edits** → one mistake, and nothing works.

GitSSH makes all of that simpler.

---

## What It Does

Instead of constantly adding/removing keys, tweaking configs, and hoping for the best, GitSSH automates it.

**The old way (annoying):**

```bash
ssh-add ~/.ssh/id_rsa_work
git config user.name "Work Name"
git config user.email "work@company.com"
git clone git@github.com-work:company/project.git
```

**With GitSSH (cleaner):**

```bash
gitssh switch work
gitssh clone https://github.com/company/project.git
cd project
gitssh commit -m "fix"
```

GitSSH keeps track of which account is active, sets the right SSH key, updates your Git config, and makes sure you’re committing/pushing as the correct user.

---

## Highlights

* No more SSH key guessing — GitSSH manages them for you.
* Correct identity every time — no accidental commits under the wrong email.
* Works with **GitHub, GitLab, Bitbucket, and custom servers**.
* Remembers settings across sessions and projects.
* Switch accounts with a single command.
* Converts HTTPS clone URLs to SSH automatically.

---

## Installation

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/piedpipr/gitssh/refs/heads/main/install-gitssh | sh
```

### Manual

```bash
git clone https://github.com/piedpipr/gitssh.git
cd gitssh
chmod +x install
./install
```

The installer supports:

```bash
./install install     # Install (default)
./install update      # Update GitSSH
./install uninstall   # Remove everything
./install verify      # Check installation
./install diagnose    # Run diagnostics
```

---

## Basic Usage

### First-time setup

```bash
gitssh onboard
```

or

```bash
gitssh init
gitssh user add
```

### Switching accounts

```bash
gitssh switch github-work
gitssh clone https://github.com/company/project.git
```

### Repo-specific identity

```bash
cd personal-project
gitssh session set github-personal
```

---

## Commands You’ll Actually Use

* `gitssh switch <user>` → switch global account
* `gitssh user add` → add a new user (GitHub/GitLab/etc.)
* `gitssh session set <user>` → set account just for current repo
* `gitssh remote convert` → change HTTPS remotes to SSH
* `gitssh ssh doctor` → debug SSH issues
* `gitssh commit` / `gitssh push` → safer versions of Git commands

## Essential Commands

**Account management:**
```bash
gitssh user add           # Add new account
gitssh user list          # Show all accounts
gitssh switch <user>      # Switch globally
gitssh session set        # Set for current repo only
```

**Working with repos:**
```bash
gitssh clone <url>        # Enhanced clone with auto-setup
gitssh remote convert     # Convert HTTPS remotes to SSH
gitssh status             # Git status + user info
gitssh commit             # Commit with identity verification
```

**Troubleshooting:**
```bash
gitssh ssh doctor         # Diagnose SSH problems
gitssh ssh status         # Check SSH setup
gitssh validate           # Verify installation
```

There's more (`gitssh help` shows everything), but these cover most daily use.

---

## Configuration

GitSSH uses simple JSON files you can read and edit:

- `~/.gitssh-users.json` - your accounts and SSH keys
- `~/.gitssh-sessions.json` - per-repo user mappings

Example user config:
```json
{
  "users": {
    "github-personal": {
      "name": "John Doe",
      "email": "john@example.com",
      "ssh_key": "~/.ssh/id_ed25519_github_personal",
      "host": "github.com"
    },
    "github-work": {
      "name": "John Doe", 
      "email": "john.doe@company.com",
      "ssh_key": "~/.ssh/id_ed25519_github_work",
      "host": "github.com"
    }
  },
  "default_user": "github-personal"
}
```

## Common Workflows

### Multiple GitHub accounts

```bash
# Add accounts
gitssh user add  # Follow prompts for 'github-personal'
gitssh user add  # Follow prompts for 'github-work'

# Switch contexts
gitssh switch github-work
gitssh clone git@github.com:company/project.git

gitssh switch github-personal  
gitssh clone git@github.com:myuser/personal-project.git
```

### Per-repository identity

```bash
# Set specific user for this repo
cd work-project
gitssh session set github-work

cd personal-project  
gitssh session set github-personal

# GitSSH remembers these settings
```

### Fix existing repositories

```bash
# Convert HTTPS to SSH
cd existing-repo
gitssh remote convert

# Check what's configured
gitssh info
gitssh ssh status
```

## Architecture

GitSSH installs as a modular system:

```
~/.local/bin/gitssh-libs/     # Main installation
├── gitssh                   # CLI dispatcher
├── install                  # Installer
└── modules/                 # Core functionality
    ├── gitssh-utils.sh      # Utilities
    ├── gitssh-users.sh      # User management
    ├── gitssh-sessions.sh   # Session handling
    ├── gitssh-remotes.sh    # Remote management
    ├── gitssh-commands.sh   # Git command wrappers
    ├── gitssh-init.sh       # Initialization
    └── gitssh-setup.sh      # Setup wizards

~/.local/bin/gitssh          # Symlink for easy access
```

## Requirements

You need these installed:
- `git` - obviously
- `ssh` - OpenSSH or compatible
- `jq` - for JSON config handling

Install with your package manager:
```bash
# Ubuntu/Debian
sudo apt install git openssh-client jq

# macOS  
brew install git openssh jq

# Others: yum, dnf, pacman, etc.
```

## Troubleshooting

**Command not found:**
```bash
# Check installation
./install verify
source ~/.bashrc  # Reload shell
```

**SSH problems:**
```bash
gitssh ssh doctor    # Auto-diagnose issues
gitssh ssh test github.com  # Test specific host
```

**Identity issues:**
```bash
gitssh user status   # Check current user
gitssh session show  # Check repo mappings
gitssh session clear # Reset if confused
```

**Nuclear option:**
```bash
./install uninstall
./install install    # Fresh start
```

## Advanced Features

**Interactive setup wizards:**
```bash
gitssh setup github  # GitHub-specific setup
gitssh setup gitlab  # GitLab-specific setup
```

**Configuration management:**
```bash
gitssh config backup   # Backup settings
gitssh config restore  # Restore from backup
gitssh config migrate  # Upgrade config format
```

**Batch operations:**
```bash
# Check SSH for all configured hosts
gitssh ssh status

# Get recommendations for current repo
gitssh remote recommendations
```

## Development

The codebase is modular and POSIX-compatible. Each module handles a specific area (users, sessions, SSH, etc.) with comprehensive error handling.

To contribute:
1. Fork the repo
2. Follow POSIX shell conventions  
3. Add proper error handling
4. Test with `./install verify`
5. Submit a pull request

## License

MIT - use it however you want.

## Links

- **Issues:** [Report problems](https://github.com/piedpipr/gitssh/issues)
- **Discussions:** [Get help](https://github.com/piedpipr/gitssh/discussions)  
- **Wiki:** [Detailed docs](https://github.com/piedpipr/gitssh/wiki)

---
