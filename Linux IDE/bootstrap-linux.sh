#!/usr/bin/env bash
#
# Oncilla IDE — Linux bootstrap installer (Debian / Ubuntu)
# ---------------------------------------------------------
# Reproduces the Oncilla Neovim IDE on a fresh Debian-family machine.
#
# Same design rules as the macOS installer:
#   * Interactive   — every step asks before it changes anything.
#   * Idempotent    — safe to re-run; never duplicates a PATH export, an alias,
#                     or a symlink.
#   * Non-deleting  — existing configs are MOVED to timestamped backups.
#
# Usage:
#   ./bootstrap-linux.sh              # normal interactive run
#   ./bootstrap-linux.sh --dry-run    # print every command, execute nothing
#   ./bootstrap-linux.sh --yes        # auto-answer yes (still prints, no pauses)
#   ./bootstrap-linux.sh --mode=replace|sidebyside    # pre-answer Step 10
#
# NOTE ON SUDO: unlike the macOS script (where only the JDK symlink needed it),
# apt-based installs need root throughout. Every sudo command is printed before
# it runs. Nothing is installed without you saying yes first.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the repo from the script's own position.
# <repo>/Linux IDE/bootstrap-linux.sh -> CONFIG_SRC=<repo>/Linux IDE/nvim
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/nvim"

DEFAULT_APPNAME="oncilla"
DEFAULT_ALIAS="oide"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Minimum versions the config actually requires.
MIN_NVIM_MINOR=11      # vim.uv + vim.lsp.config()
MIN_NODE_MAJOR=18      # the npm-delivered language servers
MIN_JAVA_MAJOR=21      # eclipse.jdt.ls 1.41+ will not run on older

# Composer's global bin directory follows the XDG spec on Linux. This is NOT
# ~/.composer/vendor/bin as it is on macOS -- getting this wrong means phpcs
# and phpcbf are installed but never resolve.
COMPOSER_BIN='$HOME/.config/composer/vendor/bin'
COMPOSER_PATH_LINE="export PATH=\"$COMPOSER_BIN:\$PATH\""
LOCAL_BIN='$HOME/.local/bin'
LOCAL_BIN_LINE="export PATH=\"$LOCAL_BIN:\$PATH\""

DRY_RUN=0
ASSUME_YES=0
FORCED_MODE=""

INSTALL_MODE=""
APPNAME=""
ALIAS_NAME=""

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; RESET=''
fi

STEP_NO=0
banner()  { printf '\n%s%s%s\n' "$BOLD$CYAN" "$1" "$RESET"; }
step()    { STEP_NO=$((STEP_NO + 1)); printf '\n%s── Step %s · %s %s\n' "$BOLD$BLUE" "$STEP_NO" "$1" "$RESET"; }
info()    { printf '   %s\n' "$1"; }
ok()      { printf '   %s✔%s %s\n' "$GREEN" "$RESET" "$1"; }
skip()    { printf '   %s•%s %s\n' "$DIM" "$RESET" "$1"; }
warn()    { printf '   %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail()    { printf '   %s✘%s %s\n' "$RED" "$RESET" "$1"; }

SUM_INSTALLED=""; SUM_SKIPPED=""; SUM_BACKED_UP=""; SUM_FAILED=""; SUM_NOTES=""
record_installed() { SUM_INSTALLED="${SUM_INSTALLED}|$1"; }
record_skipped()   { SUM_SKIPPED="${SUM_SKIPPED}|$1"; }
record_backup()    { SUM_BACKED_UP="${SUM_BACKED_UP}|$1"; }
record_failed()    { SUM_FAILED="${SUM_FAILED}|$1"; }
# Notes are deduplicated: several steps legitimately want to say the same
# thing (e.g. "open a new terminal"), but the summary should say it once.
record_note() {
  case "|$SUM_NOTES|" in *"|$1|"*) return 0 ;; esac
  SUM_NOTES="${SUM_NOTES}|$1"
}

print_list() {
  if [ -z "$1" ]; then
    printf '   %s(none)%s\n' "$DIM" "$RESET"
  else
    # Trailing newline matters: without it `read` drops the final entry.
    printf '%s\n' "$1" | tr '|' '\n' | while IFS= read -r line; do
      [ -n "$line" ] && printf '   • %s\n' "$line"
    done
  fi
}

# ---------------------------------------------------------------------------
# Final summary. Defined above every caller: `pause` and `handle_failure` can
# both bail out early and print it.
# ---------------------------------------------------------------------------
print_summary() {
  banner "════ Installation summary ════"

  printf '\n%sInstalled / changed%s\n' "$BOLD$GREEN" "$RESET"; print_list "$SUM_INSTALLED"
  printf '\n%sAlready present / skipped%s\n' "$BOLD" "$RESET";  print_list "$SUM_SKIPPED"
  printf '\n%sBacked up%s\n' "$BOLD$YELLOW" "$RESET";           print_list "$SUM_BACKED_UP"
  printf '\n%sFailed%s\n' "$BOLD$RED" "$RESET";                 print_list "$SUM_FAILED"

  printf '\n%sConfig mode%s\n' "$BOLD" "$RESET"
  case "$INSTALL_MODE" in
    sidebyside)
      printf '   • Side-by-side under NVIM_APPNAME=%s\n' "$APPNAME"
      printf '   • Oncilla IDE : %s%s%s\n' "$BOLD" "$ALIAS_NAME" "$RESET"
      printf '   • Your old config remains at ~/.config/nvim, launched by %snvim%s\n' "$BOLD" "$RESET" ;;
    replace)
      printf '   • Replaced ~/.config/nvim (symlinked to this repo)\n'
      printf '   • Oncilla IDE : %snvim%s\n' "$BOLD" "$RESET" ;;
    *)
      printf '   %s(no config change was made)%s\n' "$DIM" "$RESET" ;;
  esac

  printf '\n%sNotes%s\n' "$BOLD" "$RESET"; print_list "$SUM_NOTES"

  # Interior width is 61 columns; box_line pads to it so the frame can't drift.
  box_line() { printf '%s│%s %-59s %s│%s\n' "$YELLOW" "$RESET" "$1" "$YELLOW" "$RESET"; }
  printf '\n%s╭─ MANUAL STEP — cannot be scripted ──────────────────────────╮%s\n' "$BOLD$YELLOW" "$RESET"
  box_line "Set your terminal's font to a Nerd Font by hand:"
  box_line ""
  box_line "  JetBrainsMono Nerd Font"
  box_line ""
  box_line "GNOME Terminal:"
  box_line "  Menu > Preferences > (your profile) > Text"
  box_line "  tick 'Custom font', choose JetBrainsMono Nerd Font"
  box_line ""
  box_line "Konsole:   Settings > Edit Current Profile > Appearance"
  box_line "Alacritty: font.normal.family in alacritty.toml"
  box_line ""
  box_line "Without it the file-tree icons, bufferline separators"
  box_line "and dashboard glyphs render as empty boxes."
  printf '%s╰─────────────────────────────────────────────────────────────╯%s\n\n' "$BOLD$YELLOW" "$RESET"
}

# ---------------------------------------------------------------------------
# Interaction helpers. All reads come from /dev/tty so a step's own stdin
# cannot swallow the prompts.
# ---------------------------------------------------------------------------
ask_yn() {
  local prompt="$1" default="${2:-y}" hint reply
  if [ "$ASSUME_YES" -eq 1 ]; then
    printf '   %s? %s%s [auto-yes]\n' "$BOLD" "$prompt" "$RESET"
    return 0
  fi
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  while true; do
    printf '   %s? %s %s%s ' "$BOLD" "$prompt" "$hint" "$RESET"
    IFS= read -r reply < /dev/tty || reply=""
    [ -z "$reply" ] && reply="$default"
    case "$reply" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo])     return 1 ;;
      *) warn "Please answer y or n." ;;
    esac
  done
}

pause() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local reply
  printf '   %s↵ Press Enter to continue, or q to quit: %s' "$DIM" "$RESET"
  IFS= read -r reply < /dev/tty || reply=""
  case "$reply" in
    [Qq]*) banner "Aborted by user."; print_summary; exit 0 ;;
  esac
}

handle_failure() {
  local what="$1"
  fail "$what failed."
  record_failed "$what"
  if ask_yn "That step failed. Continue anyway?" "n"; then
    warn "Continuing with $what unresolved."
    return 0
  fi
  banner "Aborted after failure in: $what"
  print_summary
  exit 1
}

run_cmd() {
  printf '   %s$ %s%s\n' "$DIM" "$*" "$RESET"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '   %s(dry-run: not executed)%s\n' "$DIM" "$RESET"
    return 0
  fi
  "$@"
}

# The shared check → prompt → install → show output → pause pattern.
#   install_step <label> <detect-cmd> <version-cmd> <install-cmd...>
install_step() {
  local label="$1" detect="$2" version_cmd="$3"; shift 3
  local version

  if eval "$detect" >/dev/null 2>&1; then
    version="$(eval "$version_cmd" 2>/dev/null | head -1)"
    ok "$label already installed${version:+ — $version}"
    record_skipped "$label (present${version:+: $version})"
    return 0
  fi

  warn "$label is not installed."
  if ! ask_yn "Install $label now?" "y"; then
    skip "Skipping $label."
    record_skipped "$label (declined by user)"
    pause
    return 0
  fi

  if run_cmd "$@"; then
    version="$(eval "$version_cmd" 2>/dev/null | head -1)"
    ok "$label installed${version:+ — $version}"
    record_installed "$label${version:+ ($version)}"
  else
    handle_failure "$label"
  fi
  pause
}

# apt_step <apt-package> <binary-to-detect> <why>
apt_step() {
  local pkg="$1" bin="$2" why="$3"
  info "${DIM}$pkg — $why${RESET}"
  install_step "$pkg" "command -v $bin" "$bin --version" \
    sudo apt-get install -y "$pkg"
}

# apt_pkg_step <apt-package> <why> — for packages with no distinctive binary
# of their own (build-essential ships no `build-essential`; php-mbstring is a
# shared library). Detection is by dpkg status, not by command -v.
apt_pkg_step() {
  local pkg="$1" why="$2"
  info "${DIM}$pkg — $why${RESET}"
  install_step "$pkg" \
    "dpkg-query -W -f='\${Status}' $pkg 2>/dev/null | grep -q 'ok installed'" \
    "dpkg-query -W -f='\${Version}' $pkg 2>/dev/null" \
    sudo apt-get install -y "$pkg"
}

# add_rc_line <literal-line> <comment> — idempotent by exact-string grep.
add_rc_line() {
  local line="$1" comment="$2"
  if [ -f "$SHELL_RC" ] && grep -qF "$line" "$SHELL_RC"; then
    ok "Already in $(basename "$SHELL_RC") — not adding a duplicate:"
    info "${DIM}  $line${RESET}"
    record_skipped "$(basename "$SHELL_RC") line (already present)"
    return 0
  fi
  info "Would append to $SHELL_RC:"
  info "${DIM}  $line${RESET}"
  if ask_yn "Append it?" "y"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '   %s(dry-run: not appended)%s\n' "$DIM" "$RESET"
    else
      { printf '\n# %s (added by Oncilla IDE bootstrap %s)\n' "$comment" "$TIMESTAMP"
        printf '%s\n' "$line"; } >> "$SHELL_RC"
    fi
    ok "Appended."
    record_installed "$(basename "$SHELL_RC"): $line"
    record_note "Run 'source $SHELL_RC' or open a new terminal for it to take effect."
  else
    record_skipped "$(basename "$SHELL_RC") line (declined)"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    --mode=*)
      FORCED_MODE="${1#--mode=}"
      case "$FORCED_MODE" in
        replace|sidebyside) ;;
        *) fail "--mode must be 'replace' or 'sidebyside' (got: $FORCED_MODE)"; exit 2 ;;
      esac ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
      exit 0 ;;
    *) fail "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

# ===========================================================================
#                                  PREFLIGHT
# ===========================================================================
banner "Oncilla IDE — Linux bootstrap installer"

if [ "$(uname -s)" != "Linux" ]; then
  fail "This installer is Linux-only (detected: $(uname -s)). Use bootstrap-macos.sh on a Mac."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  fail "No apt-get found. This installer targets Debian and Ubuntu."
  info "On another distro, read the dependency manifest in SETUP-linux.md and install by hand."
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  NVIM_TARBALL="nvim-linux-x86_64" ;;
  aarch64) NVIM_TARBALL="nvim-linux-arm64" ;;
  *) fail "Unsupported architecture: $ARCH (Neovim ships x86_64 and arm64 builds)."; exit 1 ;;
esac

# Which rc file gets the PATH lines depends on the login shell, not on which
# shell is running this script.
case "$(basename "${SHELL:-/bin/bash}")" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  *)    SHELL_RC="$HOME/.profile" ;;
esac

DISTRO="$( ( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}" ) )"
info "Repo config source : $CONFIG_SRC"
info "Distribution      : $DISTRO"
info "Architecture      : $ARCH"
info "Shell rc file     : $SHELL_RC"
[ "$DRY_RUN"    -eq 1 ] && warn "DRY RUN — nothing will actually be changed."
[ "$ASSUME_YES" -eq 1 ] && warn "ASSUME-YES — every prompt auto-answers yes."

if [ ! -d "$CONFIG_SRC" ]; then
  fail "Cannot find the Neovim config at: $CONFIG_SRC"
  info "This script must stay next to the 'nvim' directory inside 'Linux IDE/'."
  exit 1
fi

IDE_VERSION="$(
  awk '/^  major/{m=$3} /^  minor/{n=$3} /^  patch/{p=$3}
       END{gsub(/,/,"",m); gsub(/,/,"",n); gsub(/,/,"",p); print m"."n"."p}' \
      "$CONFIG_SRC/lua/oncilla/version.lua" 2>/dev/null
)"
[ -z "$IDE_VERSION" ] || [ "$IDE_VERSION" = ".." ] && IDE_VERSION="unknown"
info "Installing        : Oncilla IDE v$IDE_VERSION"

warn "This installer uses sudo for apt and for installing Neovim into /opt."
info "Every privileged command is printed before it runs."
pause

# ===========================================================================
# Step 1 — apt package index
# ===========================================================================
step "Refresh the apt package index"
if ask_yn "Run 'sudo apt-get update'?" "y"; then
  run_cmd sudo apt-get update || handle_failure "apt-get update"
  ok "Package index refreshed."
else
  warn "Skipped — apt installs below may fail or fetch stale versions."
  record_skipped "apt-get update (declined)"
fi
pause

# ===========================================================================
# Step 2 — Base build tools and CLI utilities
#
# build-essential provides cc, which nvim-treesitter needs to compile parsers.
# ===========================================================================
step "Base tools"
apt_pkg_step build-essential "C toolchain — nvim-treesitter compiles parsers from source"
apt_step git             git    "lazy.nvim clones plugins"
apt_step curl            curl   "Mason and the Neovim tarball download"
apt_step unzip           unzip  "Mason unpacks language servers; the font zip"
apt_step ripgrep         rg     "Telescope live_grep"
apt_step fontconfig      fc-cache "installing the Nerd Font into the user font dir"

# fd on Debian/Ubuntu is packaged as fd-find and installs the binary as
# `fdfind`, because the name `fd` was already taken. Telescope looks for `fd`.
info "${DIM}fd-find — Telescope find_files (installs as 'fdfind' on Debian)${RESET}"
install_step "fd-find" "command -v fdfind || command -v fd" "fdfind --version" \
  sudo apt-get install -y fd-find

if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  warn "fd-find installed its binary as 'fdfind'; Telescope looks for 'fd'."
  info "Fix: a shim at ~/.local/bin/fd pointing at fdfind."
  if ask_yn "Create the fd shim?" "y"; then
    run_cmd mkdir -p "$HOME/.local/bin"
    if run_cmd ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"; then
      ok "Shim created."
      record_installed "~/.local/bin/fd -> fdfind"
    fi
  else
    record_skipped "fd shim (declined)"
    record_note "Telescope find_files falls back to a slower finder without 'fd' on PATH."
  fi
fi

# Clipboard integration depends on the display server in use.
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  apt_step wl-clipboard wl-copy "clipboard integration (Wayland session detected)"
else
  apt_step xclip xclip "clipboard integration (X11 session)"
fi
pause

# ===========================================================================
# Step 3 — Neovim
#
# NOT from apt. Ubuntu ships 0.6.1 on 22.04 and 0.9.5 on 24.04; this config
# needs >= 0.11 for vim.uv and vim.lsp.config(). The official tarball is the
# most predictable source, so that is what is used, installed to /opt/nvim.
# ===========================================================================
step "Neovim (>= 0.$MIN_NVIM_MINOR, from the official release)"

nvim_ok() {
  command -v nvim >/dev/null 2>&1 || return 1
  local v major minor
  v="$(nvim --version | head -1 | sed 's/^NVIM v//')"
  major="${v%%.*}"; minor="${v#*.}"; minor="${minor%%.*}"
  [ "$major" -gt 0 ] && return 0
  [ "$minor" -ge "$MIN_NVIM_MINOR" ]
}

if nvim_ok; then
  ok "Neovim already satisfies the requirement — $(nvim --version | head -1)"
  record_skipped "neovim (present: $(nvim --version | head -1))"
else
  if command -v nvim >/dev/null 2>&1; then
    warn "Neovim $(nvim --version | head -1) is too old — this config needs >= 0.$MIN_NVIM_MINOR."
    info "${DIM}(apt's Neovim is 0.6.1 on 22.04 and 0.9.5 on 24.04 — both unusable here.)${RESET}"
  else
    warn "Neovim is not installed."
  fi
  info "Will install the official $NVIM_TARBALL build into /opt/nvim."
  if ask_yn "Install Neovim from the official release tarball?" "y"; then
    URL="https://github.com/neovim/neovim/releases/latest/download/$NVIM_TARBALL.tar.gz"
    TMPD="$(mktemp -d)"
    if run_cmd curl -fsSL -o "$TMPD/nvim.tar.gz" "$URL" \
       && run_cmd tar -C "$TMPD" -xzf "$TMPD/nvim.tar.gz"; then
      # Move any existing /opt/nvim aside rather than deleting it.
      if [ -e /opt/nvim ]; then
        info "Existing /opt/nvim found — moving it aside (never deleted)."
        run_cmd sudo mv /opt/nvim "/opt/nvim.bak.$TIMESTAMP" \
          && record_backup "/opt/nvim -> /opt/nvim.bak.$TIMESTAMP"
      fi
      if run_cmd sudo mv "$TMPD/$NVIM_TARBALL" /opt/nvim \
         && run_cmd sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim; then
        ok "Neovim installed — $(/usr/local/bin/nvim --version 2>/dev/null | head -1)"
        record_installed "neovim ($(/usr/local/bin/nvim --version 2>/dev/null | head -1)) in /opt/nvim"
      else
        handle_failure "installing Neovim into /opt"
      fi
    else
      handle_failure "downloading Neovim"
    fi
    [ "$DRY_RUN" -eq 0 ] && rm -rf "$TMPD"
  else
    record_skipped "neovim (declined)"
    record_note "Neovim >= 0.$MIN_NVIM_MINOR is REQUIRED — the config will error without it."
  fi
fi
pause

# ===========================================================================
# Step 4 — Node.js
#
# Runtime for 5 of the 8 language servers plus prettierd and eslint_d. apt's
# nodejs is far too old on 22.04 (12.x), so NodeSource is offered instead.
# An existing new-enough node (nvm, fnm, volta) is detected and left alone.
# ===========================================================================
step "Node.js (>= $MIN_NODE_MAJOR)"

node_ok() {
  command -v node >/dev/null 2>&1 || return 1
  local major
  major="$(node --version | sed 's/^v//;s/\..*//')"
  [ "$major" -ge "$MIN_NODE_MAJOR" ]
}

if node_ok; then
  ok "Node already satisfies the requirement — $(node --version)"
  info "${DIM}npm prefix: $(npm config get prefix 2>/dev/null)${RESET}"
  record_skipped "node (present: $(node --version))"
else
  if command -v node >/dev/null 2>&1; then
    warn "Node $(node --version) is older than v$MIN_NODE_MAJOR — the language servers need newer."
  else
    warn "Node is not installed."
  fi
  info "apt's nodejs is 12.x on Ubuntu 22.04, so the NodeSource LTS repo is used instead."
  if ask_yn "Add the NodeSource LTS repository and install Node?" "y"; then
    if run_cmd bash -c 'curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -' \
       && run_cmd sudo apt-get install -y nodejs; then
      ok "Node installed — $(node --version)"
      record_installed "node ($(node --version 2>/dev/null))"
    else
      handle_failure "Node installation"
    fi
  else
    record_skipped "node (declined)"
    record_note "Without Node, 5 language servers plus prettierd and eslint_d cannot install."
  fi
fi
pause

# ===========================================================================
# Step 5 — tree-sitter CLI
#
# Required because treesitter.lua pins nvim-treesitter to the `main` branch,
# which fetches and builds parsers through the CLI. Not packaged in apt, so it
# comes from npm.
# ===========================================================================
step "tree-sitter CLI"

# npm global installs need sudo only when the prefix is root-owned. An nvm or
# fnm managed node has a writable prefix in $HOME and must NOT use sudo.
npm_global() {
  local prefix
  prefix="$(npm config get prefix 2>/dev/null)"
  if [ -w "$prefix" ]; then
    npm install -g "$@"
  else
    sudo npm install -g "$@"
  fi
}

if ! command -v npm >/dev/null 2>&1; then
  fail "npm unavailable — Node was skipped or failed. Cannot install the tree-sitter CLI."
  record_skipped "tree-sitter CLI (no npm)"
else
  info "${DIM}required by the 'main' branch of nvim-treesitter${RESET}"
  install_step "tree-sitter CLI" \
    "command -v tree-sitter" \
    "tree-sitter --version" \
    npm_global tree-sitter-cli
fi

# ===========================================================================
# Step 6 — PHP and Composer
# Ordering: PHP first. Composer is a PHP application.
# ===========================================================================
step "PHP and Composer"
apt_step     php-cli       php      "runtime for Composer and for phpcs/phpcbf"
apt_pkg_step php-mbstring           "string handling php_codesniffer relies on"
apt_pkg_step php-xml                "XML support Composer needs to read packages"
apt_step     composer      composer "installs phpcs/phpcbf (needs PHP above)"
pause

# ===========================================================================
# Step 7 — Java (jdtls)
#
# Much simpler than macOS: no keg-only symlink dance. But Ubuntu 22.04's
# default-jdk is Java 11, which current jdtls will not run on, so 21 is
# requested explicitly with default-jdk as the fallback.
# ===========================================================================
step "Java / JDK — required by the jdtls language server"

java_ok() {
  command -v javac >/dev/null 2>&1 || return 1
  local major
  major="$(javac -version 2>&1 | sed 's/^javac //;s/\..*//')"
  [ "${major:-0}" -ge "$MIN_JAVA_MAJOR" ]
}

if java_ok; then
  ok "JDK already satisfies the requirement — $(javac -version 2>&1)"
  record_skipped "JDK (present: $(javac -version 2>&1))"
else
  if command -v javac >/dev/null 2>&1; then
    warn "$(javac -version 2>&1) is older than Java $MIN_JAVA_MAJOR — jdtls will not start on it."
    info "${DIM}(Ubuntu 22.04's default-jdk is Java 11.)${RESET}"
  else
    warn "No JDK found. jdtls (Java autocomplete) cannot run without one."
  fi
  if ask_yn "Install openjdk-21-jdk?" "y"; then
    if run_cmd sudo apt-get install -y openjdk-21-jdk; then
      ok "JDK installed — $(javac -version 2>&1)"
      record_installed "openjdk-21-jdk"
    else
      warn "openjdk-21-jdk unavailable on this release — falling back to default-jdk."
      if run_cmd sudo apt-get install -y default-jdk; then
        record_installed "default-jdk ($(javac -version 2>&1))"
        java_ok || record_note "The installed JDK is older than Java $MIN_JAVA_MAJOR — jdtls may not start."
      else
        handle_failure "JDK installation"
      fi
    fi
  else
    record_skipped "JDK (declined)"
    record_note "Java autocomplete is disabled without a JDK."
  fi
fi
pause

# ===========================================================================
# Step 8 — Nerd Font
#
# No Homebrew cask here: the font is fetched from the nerd-fonts release and
# unpacked into the user font directory, then the font cache is rebuilt.
# ===========================================================================
step "Nerd Font (JetBrains Mono)"

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if [ -d "$FONT_DIR" ] && [ -n "$(ls -A "$FONT_DIR" 2>/dev/null)" ]; then
  ok "JetBrainsMono Nerd Font already installed in $FONT_DIR"
  record_skipped "Nerd Font (present)"
elif fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
  ok "JetBrainsMono Nerd Font already known to fontconfig."
  record_skipped "Nerd Font (present in fontconfig)"
else
  warn "JetBrainsMono Nerd Font is not installed."
  info "Downloads JetBrainsMono.zip from the nerd-fonts release into $FONT_DIR."
  if ask_yn "Install the Nerd Font?" "y"; then
    FURL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    TMPF="$(mktemp -d)"
    if run_cmd curl -fsSL -o "$TMPF/JetBrainsMono.zip" "$FURL" \
       && run_cmd mkdir -p "$FONT_DIR" \
       && run_cmd unzip -oq "$TMPF/JetBrainsMono.zip" -d "$FONT_DIR" \
       && run_cmd fc-cache -f "$FONT_DIR"; then
      ok "Font installed and cache rebuilt."
      record_installed "JetBrainsMono Nerd Font"
    else
      handle_failure "Nerd Font installation"
    fi
    [ "$DRY_RUN" -eq 0 ] && rm -rf "$TMPF"
  else
    record_skipped "Nerd Font (declined)"
  fi
fi
record_note "MANUAL STEP: set your terminal's font to 'JetBrainsMono Nerd Font' (see summary)."
pause

# ===========================================================================
# Step 9 — npm globals and Composer globals, plus the PATH entries
#
# conform.nvim and nvim-lint resolve these from PATH, not from Mason.
# ===========================================================================
step "Formatters and linters"

if ! command -v npm >/dev/null 2>&1; then
  fail "npm unavailable — cannot install prettierd/eslint_d."
  record_skipped "npm globals (no npm)"
else
  install_step "prettierd" "command -v prettierd" "prettierd --version" \
    npm_global @fsouza/prettierd
  install_step "eslint_d" "command -v eslint_d" "eslint_d --version" \
    npm_global eslint_d
fi

if ! command -v composer >/dev/null 2>&1; then
  fail "composer unavailable — PHP linting/formatting will not work."
  record_skipped "composer globals (no composer)"
else
  install_step "php_codesniffer (phpcs + phpcbf)" \
    "command -v phpcs" "phpcs --version" \
    composer global require squizlabs/php_codesniffer
fi

# --- PATH entries, added only if genuinely absent -------------------------
info "Checking $SHELL_RC for the required PATH entries..."
info "${DIM}Composer's global bin on Linux is ~/.config/composer/vendor/bin${RESET}"
info "${DIM}(not ~/.composer/vendor/bin, which is the macOS location)${RESET}"

if [ -f "$SHELL_RC" ] && grep -qF '.config/composer/vendor/bin' "$SHELL_RC"; then
  COUNT="$(grep -cF '.config/composer/vendor/bin' "$SHELL_RC")"
  if [ "$COUNT" -gt 1 ]; then
    warn "The Composer PATH entry appears $COUNT times in $SHELL_RC."
    record_note "$SHELL_RC has $COUNT duplicate Composer PATH lines (pre-existing; not touched)."
  else
    ok "Composer PATH entry already present (exactly once)."
  fi
  record_skipped "Composer PATH entry (already in $(basename "$SHELL_RC"))"
else
  add_rc_line "$COMPOSER_PATH_LINE" "Composer global binaries"
fi

# ~/.local/bin holds the fd shim. Ubuntu's default .profile adds it only if the
# directory existed at login, so an explicit entry is safer.
case ":${PATH}:" in
  *":$HOME/.local/bin:"*) ok "~/.local/bin is already on PATH." 
                          record_skipped "~/.local/bin PATH entry (already active)" ;;
  *) add_rc_line "$LOCAL_BIN_LINE" "user-local binaries (fd shim)" ;;
esac
pause

# ===========================================================================
# Step 10 — Existing Neovim / SpaceVim configuration
# ===========================================================================
step "Existing Neovim configuration"

NVIM_CONFIG="$HOME/.config/nvim"
NVIM_DATA="$HOME/.local/share/nvim"
NVIM_STATE="$HOME/.local/state/nvim"
NVIM_CACHE="$HOME/.cache/nvim"

EXISTING="none"
LINK_TARGET=""
if [ -L "$NVIM_CONFIG" ]; then
  # -L must be tested BEFORE -d: a symlink to a directory satisfies both.
  LINK_TARGET="$(readlink "$NVIM_CONFIG")"
  case "$LINK_TARGET" in
    /*) ;;
    *)  LINK_TARGET="$HOME/.config/$LINK_TARGET" ;;
  esac
  if [ "$LINK_TARGET" = "$CONFIG_SRC" ]; then
    EXISTING="symlink-self"
  else
    EXISTING="symlink-other"
  fi
elif [ -d "$NVIM_CONFIG" ]; then
  EXISTING="directory"
fi

FLAVOUR="an existing Neovim config"
if [ "$EXISTING" = "directory" ]; then
  if [ -d "$HOME/.SpaceVim" ] || [ -d "$HOME/.SpaceVim.d" ] \
     || grep -rqs "SpaceVim" "$NVIM_CONFIG" 2>/dev/null; then
    FLAVOUR="a SpaceVim installation"
  elif [ -f "$NVIM_CONFIG/lua/config/lazy.lua" ]; then
    FLAVOUR="a LazyVim installation"
  elif [ -f "$NVIM_CONFIG/init.lua" ] && grep -qs "kickstart" "$NVIM_CONFIG/init.lua" 2>/dev/null; then
    FLAVOUR="a kickstart.nvim installation"
  fi
fi

case "$EXISTING" in
  none)          ok "~/.config/nvim does not exist — clean install." ;;
  symlink-self)  ok "~/.config/nvim is already a symlink to THIS repo."
                 info "${DIM}  -> $LINK_TARGET${RESET}" ;;
  symlink-other) warn "~/.config/nvim is a symlink to a DIFFERENT location:"
                 info "${DIM}  -> $LINK_TARGET${RESET}"
                 info "It will be removed as a link — the directory it points at is never touched." ;;
  directory)     warn "~/.config/nvim is a real directory: $FLAVOUR" ;;
esac

for d in "$NVIM_DATA" "$NVIM_STATE" "$NVIM_CACHE" "$HOME/.SpaceVim" "$HOME/.SpaceVim.d"; do
  [ -e "$d" ] && info "${DIM}  also present: $d${RESET}"
done

if [ "$EXISTING" = "none" ] && [ -z "$FORCED_MODE" ]; then
  INSTALL_MODE="replace"
elif [ "$EXISTING" = "none" ]; then
  INSTALL_MODE="$FORCED_MODE"
  info "--mode=$FORCED_MODE (nothing existing to preserve)."
else
  printf '\n   %sWhat would you like to do?%s\n\n' "$BOLD" "$RESET"
  printf '     %s1)%s Back up and replace\n' "$BOLD" "$RESET"
  printf '        Moves the existing config (and nvim data/state/cache) to\n'
  printf '        timestamped .bak.%s folders, then symlinks this repo to\n' "$TIMESTAMP"
  printf '        ~/.config/nvim. Plain `nvim` launches the Oncilla IDE.\n'
  printf '        %sNothing is deleted — everything is recoverable.%s\n\n' "$DIM" "$RESET"
  printf '     %s2)%s Install side-by-side under a separate app name\n' "$BOLD" "$RESET"
  printf '        Leaves ~/.config/nvim completely untouched. Installs this\n'
  printf '        config at ~/.config/<name> using NVIM_APPNAME, and adds a\n'
  printf '        shell alias so both editors coexist:\n'
  printf '          %s`nvim` -> your current config, `%s` -> Oncilla IDE%s\n\n' "$DIM" "$DEFAULT_ALIAS" "$RESET"
  printf '     %s3)%s Quit\n' "$BOLD" "$RESET"
  printf '        Aborts now. Nothing on disk changes.\n\n'

  if [ -n "$FORCED_MODE" ]; then
    [ "$FORCED_MODE" = "replace" ] && CHOICE=1 || CHOICE=2
    warn "--mode=$FORCED_MODE: choosing option $CHOICE."
  elif [ "$ASSUME_YES" -eq 1 ]; then
    CHOICE=1
    warn "auto-yes: choosing option 1 (back up and replace)."
  else
    while true; do
      printf '   %s? Choose 1, 2 or 3: %s' "$BOLD" "$RESET"
      IFS= read -r CHOICE < /dev/tty || CHOICE=3
      case "$CHOICE" in
        1|2|3) break ;;
        *) warn "Please enter 1, 2 or 3." ;;
      esac
    done
  fi

  case "$CHOICE" in
    3) banner "Quit — nothing was changed."; print_summary; exit 0 ;;
    2) INSTALL_MODE="sidebyside" ;;
    1) INSTALL_MODE="replace" ;;
  esac
fi

if [ "$INSTALL_MODE" = "replace" ] && [ "$EXISTING" != "none" ]; then
  if [ "$EXISTING" = "symlink-self" ]; then
    info "The symlink already points here; there is nothing to back up."
    if ask_yn "Re-create the symlink anyway (harmless refresh)?" "n"; then
      run_cmd rm -f "$NVIM_CONFIG"
      EXISTING="none"
    fi
  elif [ "$EXISTING" = "symlink-other" ]; then
    info "Removing the symlink (its target directory is left alone)."
    if run_cmd rm -f "$NVIM_CONFIG"; then
      ok "Symlink removed."
      record_backup "removed symlink ~/.config/nvim -> $LINK_TARGET (target untouched)"
    else
      handle_failure "removing existing symlink"
    fi
  else
    BACKUP="$NVIM_CONFIG.bak.$TIMESTAMP"
    info "Backing up $FLAVOUR:"
    info "${DIM}  $NVIM_CONFIG -> $BACKUP${RESET}"
    if run_cmd mv "$NVIM_CONFIG" "$BACKUP"; then
      ok "Config backed up."
      record_backup "$NVIM_CONFIG -> $BACKUP"
    else
      handle_failure "backing up ~/.config/nvim"
    fi

    if [ -d "$NVIM_DATA" ] || [ -d "$NVIM_STATE" ] || [ -d "$NVIM_CACHE" ]; then
      warn "Plugin/runtime data from the previous config is still present."
      info "Leaving it can confuse lazy.nvim and Mason on first launch."
      if ask_yn "Also back up nvim data/state/cache directories?" "y"; then
        for d in "$NVIM_DATA" "$NVIM_STATE" "$NVIM_CACHE"; do
          if [ -e "$d" ]; then
            run_cmd mv "$d" "$d.bak.$TIMESTAMP" \
              && record_backup "$d -> $d.bak.$TIMESTAMP" \
              || warn "Could not back up $d — continuing."
          fi
        done
        ok "Runtime data backed up."
      else
        record_note "Existing nvim data/state/cache kept — may conflict with lazy.nvim."
      fi
    fi

    if [ -d "$HOME/.SpaceVim" ] || [ -d "$HOME/.SpaceVim.d" ]; then
      warn "SpaceVim directories detected (~/.SpaceVim, ~/.SpaceVim.d)."
      if ask_yn "Back up the SpaceVim directories too?" "n"; then
        for d in "$HOME/.SpaceVim" "$HOME/.SpaceVim.d"; do
          [ -e "$d" ] && run_cmd mv "$d" "$d.bak.$TIMESTAMP" \
            && record_backup "$d -> $d.bak.$TIMESTAMP"
        done
      else
        record_skipped "SpaceVim directories (left in place)"
      fi
    fi
  fi
fi
pause

# ===========================================================================
# Step 11 — Install the config
# ===========================================================================
step "Installing the Oncilla IDE config"

if [ "$INSTALL_MODE" = "sidebyside" ]; then
  if [ "$ASSUME_YES" -eq 1 ] || [ -n "$FORCED_MODE" ]; then
    APPNAME="$DEFAULT_APPNAME"; ALIAS_NAME="$DEFAULT_ALIAS"
  else
    printf '   %s? App name [%s]: %s' "$BOLD" "$DEFAULT_APPNAME" "$RESET"
    IFS= read -r APPNAME < /dev/tty || APPNAME=""
    [ -z "$APPNAME" ] && APPNAME="$DEFAULT_APPNAME"
    printf '   %s? Shell alias [%s]: %s' "$BOLD" "$DEFAULT_ALIAS" "$RESET"
    IFS= read -r ALIAS_NAME < /dev/tty || ALIAS_NAME=""
    [ -z "$ALIAS_NAME" ] && ALIAS_NAME="$DEFAULT_ALIAS"
  fi

  TARGET="$HOME/.config/$APPNAME"
  info "Config will live at : $TARGET"
  info "Launch command      : $ALIAS_NAME"
  info "~/.config/nvim      : ${GREEN}untouched${RESET}"

  if [ -L "$TARGET" ]; then
    if [ "$(readlink "$TARGET")" = "$CONFIG_SRC" ]; then
      ok "$TARGET already links to this repo. Nothing to do."
      record_skipped "$TARGET symlink (already correct)"
    else
      warn "$TARGET is a symlink to something else: $(readlink "$TARGET")"
      ask_yn "Repoint it at this repo?" "y" \
        && run_cmd ln -sfn "$CONFIG_SRC" "$TARGET" \
        && record_installed "$TARGET -> $CONFIG_SRC"
    fi
  elif [ -d "$TARGET" ]; then
    warn "$TARGET already exists as a real directory."
    if ask_yn "Back it up to $TARGET.bak.$TIMESTAMP and replace it?" "y"; then
      run_cmd mv "$TARGET" "$TARGET.bak.$TIMESTAMP" && record_backup "$TARGET -> $TARGET.bak.$TIMESTAMP"
      run_cmd ln -sfn "$CONFIG_SRC" "$TARGET" && record_installed "$TARGET -> $CONFIG_SRC"
    else
      record_skipped "$TARGET (left alone)"
    fi
  else
    run_cmd mkdir -p "$HOME/.config"
    if run_cmd ln -sfn "$CONFIG_SRC" "$TARGET"; then
      ok "Linked $TARGET -> $CONFIG_SRC"
      record_installed "$TARGET -> $CONFIG_SRC"
    else
      handle_failure "creating $TARGET symlink"
    fi
  fi

  add_rc_line "alias $ALIAS_NAME='NVIM_APPNAME=$APPNAME nvim'" "Oncilla IDE launcher"
  record_note "Launch the Oncilla IDE with: $ALIAS_NAME   (plain 'nvim' still runs your old config)"
else
  run_cmd mkdir -p "$HOME/.config"
  APPNAME="nvim"
  if [ -L "$NVIM_CONFIG" ] && [ "$(readlink "$NVIM_CONFIG")" = "$CONFIG_SRC" ]; then
    ok "~/.config/nvim already links to this repo. Nothing to do."
    record_skipped "~/.config/nvim symlink (already correct)"
  elif [ -e "$NVIM_CONFIG" ]; then
    fail "~/.config/nvim still exists — the backup step did not clear it."
    handle_failure "symlinking ~/.config/nvim"
  else
    info "Linking the repo config into place:"
    info "${DIM}  $NVIM_CONFIG -> $CONFIG_SRC${RESET}"
    if run_cmd ln -sfn "$CONFIG_SRC" "$NVIM_CONFIG"; then
      ok "Linked."
      record_installed "~/.config/nvim -> $CONFIG_SRC"
    else
      handle_failure "symlinking ~/.config/nvim"
    fi
  fi
  record_note "Launch the Oncilla IDE with: nvim"
fi
pause

# ===========================================================================
# Step 12 — First launch
# ===========================================================================
step "First launch — plugin and LSP installation"

info "The first run will:"
info "  1. bootstrap lazy.nvim and install all 31 pinned plugins"
info "  2. compile treesitter parsers (lua, java, ts, tsx, js, php, html, css, scss, json, xml)"
info "  3. have Mason download 8 language servers"

if ! command -v nvim >/dev/null 2>&1; then
  fail "nvim is not on PATH — skipping the first launch."
  record_skipped "first launch (no nvim)"
elif ask_yn "Run the headless first-launch now?" "y"; then
  export NVIM_APPNAME="$APPNAME"
  info "Syncing plugins (NVIM_APPNAME=$APPNAME)..."
  # `Lazy! sync` also brings lazy.nvim itself to the commit in lazy-lock.json,
  # which matters: a bootstrap-fresh lazy can differ from the pinned one.
  if run_cmd nvim --headless "+Lazy! sync" +qa; then
    ok "Plugins synced."
    record_installed "lazy.nvim plugin sync"
  else
    handle_failure "lazy.nvim plugin sync"
  fi

  info "Giving Mason a run to fetch language servers..."
  run_cmd nvim --headless "+sleep 60" +qa
  ok "Mason kicked off. Check progress inside Neovim with :Mason."
  record_note "Verify with :Lazy, :Mason and :checkhealth after opening the editor."
  unset NVIM_APPNAME
else
  record_skipped "first launch (declined)"
  record_note "Plugins install automatically the first time you open the editor."
fi
pause

print_summary
banner "Oncilla IDE v$IDE_VERSION — bootstrap complete."
