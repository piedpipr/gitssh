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
curl -fsSL https://raw.githubusercontent.com/piedpipr/gitssh/main/install-gitssh.sh | sh
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

There’s a lot more (`gitssh help` shows everything), but those are the essentials.

---

## Config Files

GitSSH stores data in JSON (easy to read/edit):

* `~/.gitssh-users.json` → users & SSH keys
* `~/.gitssh-sessions.json` → repo-to-user mapping

Example user config:

```json
{
  "users": {
    "github-personal": {
      "name": "John Doe",
      "email": "john@example.com",
      "ssh_key": "~/.ssh/id_ed25519_github_personal",
      "host": "github.com"
    }
  },
  "default_user": "github-personal"
}
```

---

## Troubleshooting

* Run `gitssh ssh doctor` for SSH issues.
* Run `gitssh validate` to check setup.
* If something’s really broken:

  ```bash
  ./install uninstall
  ./install install
  ```

---

## Requirements

* `git`
* `ssh` (OpenSSH)
* `jq`

Install them with your package manager (`apt`, `yum`, `brew`, etc.).

---

## License

MIT — do whatever you want, just don’t blame me if it breaks.

---

## Links

* Docs: [Wiki](https://github.com/piedpipr/gitssh/wiki)
* Issues: [Report here](https://github.com/piedpipr/gitssh/issues)
* Discussions: [Join here](https://github.com/piedpipr/gitssh/discussions)

---
