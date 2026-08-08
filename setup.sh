#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Termux Complete Setup Script
# Repo: https://github.com/davealone69-gif/termux-complete-setup
# ============================================================
# One-liner install:
#   pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/davealone69-gif/termux-complete-setup/main/setup.sh | bash
#
# Or with options:
#   bash setup.sh --full          # everything including OmniRoute
#   bash setup.sh --dev           # development tools only
#   bash setup.sh --omniroute     # just OmniRoute after basics
# ============================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
  echo -e "\n${CYAN}══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════${NC}\n"
}

print_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }
print_err()  { echo -e "${RED}[✗]${NC} $1"; }

# Defaults
INSTALL_DEV=true
INSTALL_OMNIROUTE=false
INSTALL_EXTRA=false
NON_INTERACTIVE=false

# Parse args
for arg in "$@"; do
  case $arg in
    --full)          INSTALL_DEV=true; INSTALL_OMNIROUTE=true; INSTALL_EXTRA=true ;;
    --dev)           INSTALL_DEV=true ;;
    --omniroute)     INSTALL_OMNIROUTE=true ;;
    --extra)         INSTALL_EXTRA=true ;;
    -y|--yes)        NON_INTERACTIVE=true ;;
    -h|--help)
      echo "Usage: bash setup.sh [options]"
      echo "  --full       Full install (dev + OmniRoute + extras)"
      echo "  --dev        Development tools (default)"
      echo "  --omniroute  Install OmniRoute AI gateway"
      echo "  --extra      Extra utilities (neovim, fzf, etc.)"
      echo "  -y, --yes    Non-interactive mode"
      exit 0
      ;;
  esac
done

# Safety: refuse root
if [ "$(id -u)" -eq 0 ]; then
  print_err "Do not run this script as root."
  exit 1
fi

print_header "Termux Complete Setup"
echo "Options: DEV=$INSTALL_DEV  OMNIROUTE=$INSTALL_OMNIROUTE  EXTRA=$INSTALL_EXTRA"
echo ""

# ----------------------------------------------------------
# 1. Storage + Update
# ----------------------------------------------------------
print_header "1. Storage Access & System Update"

if [ ! -d "$HOME/storage" ]; then
  print_info "Requesting storage access..."
  termux-setup-storage || true
  sleep 2
fi
print_ok "Storage ready (or already configured)"

print_info "Updating package lists and upgrading..."
pkg update -y
pkg upgrade -y
print_ok "System updated"

# ----------------------------------------------------------
# 2. Essential packages
# ----------------------------------------------------------
print_header "2. Essential Packages"

ESSENTIALS=(
  curl wget git openssh
  coreutils findutils grep sed gawk
  tar gzip unzip zip
  nano vim
  which whichutils
  termux-api
  proot
)

for pkg in "${ESSENTIALS[@]}"; do
  if ! command -v "$pkg" &>/dev/null && ! dpkg -s "$pkg" &>/dev/null; then
    print_info "Installing $pkg..."
    pkg install -y "$pkg" || print_err "Failed to install $pkg (continuing)"
  else
    print_ok "$pkg already present"
  fi
done

print_ok "Essentials installed"

# ----------------------------------------------------------
# 3. Development tools
# ----------------------------------------------------------
if [ "$INSTALL_DEV" = true ]; then
  print_header "3. Development Tools"

  DEV_PKGS=(
    nodejs-lts python
    build-essential clang make cmake
    golang rust
    gh
    jq
    tree
    htop
    neofetch
  )

  for pkg in "${DEV_PKGS[@]}"; do
    print_info "Installing $pkg..."
    pkg install -y "$pkg" || print_err "Failed $pkg"
  done

  # Ensure npm is usable
  if command -v npm &>/dev/null; then
    npm config set fund false
    npm config set update-notifier false
    print_ok "npm configured"
  fi

  # Python tools
  if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
    pip install --upgrade pip setuptools wheel 2>/dev/null || true
  fi

  print_ok "Development tools installed"
fi

# ----------------------------------------------------------
# 4. Extra quality-of-life tools
# ----------------------------------------------------------
if [ "$INSTALL_EXTRA" = true ]; then
  print_header "4. Extra Utilities"

  EXTRA_PKGS=(
    fzf
    ripgrep
    bat
    fd
    tmux
    zsh
    fish
    neovim
    rsync
    rclone
    nmap
    net-tools
  )

  for pkg in "${EXTRA_PKGS[@]}"; do
    print_info "Installing $pkg..."
    pkg install -y "$pkg" || true
  done

  print_ok "Extra utilities installed"
fi

# ----------------------------------------------------------
# 5. Git configuration helpers
# ----------------------------------------------------------
print_header "5. Git & GitHub Setup"

if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
  if [ "$NON_INTERACTIVE" = false ]; then
    read -rp "Git user.name (or press Enter to skip): " GIT_NAME
    if [ -n "${GIT_NAME:-}" ]; then
      git config --global user.name "$GIT_NAME"
    fi
  fi
fi

if [ -z "$(git config --global user.email 2>/dev/null || true)" ]; then
  if [ "$NON_INTERACTIVE" = false ]; then
    read -rp "Git user.email (or press Enter to skip): " GIT_EMAIL
    if [ -n "${GIT_EMAIL:-}" ]; then
      git config --global user.email "$GIT_EMAIL"
    fi
  fi
fi

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global credential.helper store
print_ok "Git defaults configured"

# Optional GitHub CLI login hint
if command -v gh &>/dev/null; then
  print_info "GitHub CLI (gh) is installed. Run 'gh auth login' later to authenticate."
fi

# ----------------------------------------------------------
# 6. OmniRoute (optional)
# ----------------------------------------------------------
if [ "$INSTALL_OMNIROUTE" = true ]; then
  print_header "6. OmniRoute AI Gateway"

  print_info "Installing build dependencies for native modules..."
  pkg install -y nodejs-lts python build-essential 2>/dev/null || true

  print_info "Installing OmniRoute via npm (this may take a while and use significant storage)..."
  if npm install -g omniroute; then
    print_ok "OmniRoute installed globally"
  else
    print_err "Global install failed – trying npx fallback"
    print_info "You can still run: npx -y omniroute@latest"
  fi

  # Create a simple start script
  cat > "$HOME/start-omniroute.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME"
echo "Starting OmniRoute on http://localhost:20128 ..."
if command -v omniroute &>/dev/null; then
  nohup omniroute > "$HOME/omniroute.log" 2>&1 &
else
  nohup npx -y omniroute@latest > "$HOME/omniroute.log" 2>&1 &
fi
echo "PID: $!"
echo "Logs: $HOME/omniroute.log"
echo "Dashboard: http://localhost:20128"
EOF
  chmod +x "$HOME/start-omniroute.sh"
  print_ok "Created ~/start-omniroute.sh"

  # Optional Termux:Boot support
  if [ -d "$HOME/.termux" ]; then
    mkdir -p "$HOME/.termux/boot"
    cat > "$HOME/.termux/boot/omniroute.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
cd "$HOME"
if command -v omniroute >/dev/null 2>&1; then
  nohup omniroute > "$HOME/omniroute.log" 2>&1 &
else
  nohup npx -y omniroute@latest > "$HOME/omniroute.log" 2>&1 &
fi
EOF
    chmod +x "$HOME/.termux/boot/omniroute.sh"
    print_ok "Termux:Boot script created (requires Termux:Boot app)"
  fi

  print_info "To start OmniRoute:  ~/start-omniroute.sh"
  print_info "Or simply:           omniroute"
  print_info "Dashboard:           http://localhost:20128"
fi

# ----------------------------------------------------------
# 7. Final touches
# ----------------------------------------------------------
print_header "7. Final Configuration"

# Create a useful .bashrc addition
if ! grep -q "# Termux Complete Setup" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" << 'EOF'

# Termux Complete Setup aliases
alias ll='ls -lah --color=auto'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias update='pkg update && pkg upgrade'
alias cls='clear'
export EDITOR=nano
EOF
  print_ok "Added helpful aliases to ~/.bashrc"
fi

# Create a simple welcome message
cat > "$HOME/.termux_motd" << 'EOF'

  Termux Complete Setup is ready!
  Run:  source ~/.bashrc
  Help: cat ~/termux-setup-help.txt

EOF

# Help file
cat > "$HOME/termux-setup-help.txt" << 'EOF'
Termux Complete Setup – Quick Reference
=======================================

Essential commands:
  pkg update && pkg upgrade     Update everything
  termux-setup-storage          Re-request storage permission
  git config --global ...       Configure Git identity
  gh auth login                 Authenticate GitHub CLI

OmniRoute (if installed):
  ~/start-omniroute.sh          Start in background
  omniroute                     Start in foreground
  pkill -f omniroute            Stop it
  Dashboard: http://localhost:20128
  API:       http://localhost:20128/v1

Useful packages already installed (depending on flags):
  nodejs-lts, python, git, gh, clang, make, golang, rust,
  fzf, ripgrep, bat, neovim, tmux, etc.

Restart Termux after first run for best results.
EOF

print_ok "Help file written to ~/termux-setup-help.txt"

print_header "Setup Complete!"
echo -e "${GREEN}Everything is ready.${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart Termux (or run: source ~/.bashrc)"
echo "  2. Configure Git if you skipped it:"
echo "       git config --global user.name  \"Your Name\""
echo "       git config --global user.email \"you@example.com\""
echo "  3. Authenticate GitHub CLI (optional): gh auth login"
if [ "$INSTALL_OMNIROUTE" = true ]; then
  echo "  4. Start OmniRoute:  ~/start-omniroute.sh"
fi
echo ""
echo "Repository: https://github.com/davealone69-gif/termux-complete-setup"
echo ""
