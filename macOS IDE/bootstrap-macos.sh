#!/usr/bin/env bash
#
# Oncilla IDE — macOS bootstrap installer
# ---------------------------------------
# Reproduces the Oncilla Neovim IDE on a fresh Mac (Apple Silicon, Homebrew).
#
# Design rules this script follows:
#   * Interactive   — every step asks before it changes anything.
#   * Idempotent    — safe to re-run; detects what exists, never duplicates
#                     a PATH export, an alias line, or a symlink.
#   * Portable      — stock macOS bash 3.2 + Homebrew. No other dependencies.
#   * Non-surprising— it never deletes. Existing configs are *moved* to a
#                     timestamped backup, never removed.
#
# Usage:
#   ./bootstrap-macos.sh              # normal interactive run
#   ./bootstrap-macos.sh --dry-run    # print every command, execute nothing
#   ./bootstrap-macos.sh --yes        # auto-answer yes (still prints, no pauses)
#   ./bootstrap-macos.sh --mode=replace      # pre-answer Step 8 (option 1)
#   ./bootstrap-macos.sh --mode=sidebyside   # pre-answer Step 8 (option 2)
#
# Note on bash: macOS ships bash 3.2, so this script avoids associative
# arrays, `mapfile`, and `${var,,}` — all bash 4+ features.

set -uo pipefail
# NOTE: deliberately no `set -e`. A failing step must be reported to the user
# and answered by them ("continue or abort?"), not silently kill the script.

# ---------------------------------------------------------------------------
# Locate the repo from the script's own position.
# <repo>/macOS IDE/bootstrap-macos.sh -> CONFIG_SRC=<repo>/macOS IDE/nvim
# This is what makes the script portable: clone the repo anywhere and run it.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/nvim"

# Defaults for the side-by-side install mode (Step 7).
DEFAULT_APPNAME="oncilla"
DEFAULT_ALIAS="ovim"

# Config-mode state. Declared up-front because print_summary may run before
# Step 8 has decided any of them (e.g. the user quits during Step 2).
INSTALL_MODE=""        # "replace" | "sidebyside" | "" (nothing decided yet)
APPNAME=""             # NVIM_APPNAME used for the install
ALIAS_NAME=""          # shell alias, side-by-side mode only

ZSHRC="$HOME/.zshrc"
COMPOSER_PATH_LINE='export PATH="$HOME/.composer/vendor/bin:$PATH"'
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
ASSUME_YES=0
FORCED_MODE=""          # --mode=replace|sidebyside pre-answers Step 8

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

# ---------------------------------------------------------------------------
# Summary tracking — printed at the end (Step 3.6 of the spec).
# Parallel arrays instead of a hash, for bash 3.2 compatibility.
# ---------------------------------------------------------------------------
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

# Print a "|"-delimited list one entry per line, or a placeholder if empty.
print_list() {
  if [ -z "$1" ]; then
    printf '   %s(none)%s\n' "$DIM" "$RESET"
  else
    # The trailing newline matters: without it `read` returns non-zero on the
    # final entry and the loop silently drops it.
    printf '%s\n' "$1" | tr '|' '\n' | while IFS= read -r line; do
      [ -n "$line" ] && printf '   • %s\n' "$line"
    done
  fi
}

# ---------------------------------------------------------------------------
# Final summary. Defined here, above every caller: `pause` and `handle_failure`
# can both bail out early and print it, and a bash function must exist before
# it is called.
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
      printf '   • Oncilla IDE : %sovim%s — and plain %snvim%s opens the same config\n' \
        "$BOLD" "$RESET" "$BOLD" "$RESET" ;;
    *)
      printf '   %s(no config change was made)%s\n' "$DIM" "$RESET" ;;
  esac

  printf '\n%sNotes%s\n' "$BOLD" "$RESET"; print_list "$SUM_NOTES"

  # The one thing that genuinely cannot be scripted: every terminal stores its
  # font in its own preferences (iTerm2's is a binary plist, Terminal.app's is
  # in its own defaults domain), so this is a human step whichever one is used.
  # Interior width is 61 columns; box_line pads to it so the frame can't drift.
  box_line() { printf '%s│%s %-59s %s│%s\n' "$YELLOW" "$RESET" "$1" "$YELLOW" "$RESET"; }

  printf '\n%s╭─ MANUAL STEP — cannot be scripted ──────────────────────────╮%s\n' "$BOLD$YELLOW" "$RESET"
  box_line "Set your terminal's font to a Nerd Font by hand:"
  box_line ""
  box_line "  JetBrainsMono Nerd Font"
  box_line ""
  box_line "in whichever terminal you run the editor from:"
  box_line ""
  # Mark the terminal actually in use, so the relevant line is obvious.
  case "${TERM_PROGRAM:-}" in
    iTerm.app)      box_line "> iTerm2   : Settings > Profiles > Text > Font"
                    box_line "  Terminal : Settings > Profiles > Text > Font" ;;
    Apple_Terminal) box_line "  iTerm2   : Settings > Profiles > Text > Font"
                    box_line "> Terminal : Settings > Profiles > Text > Font" ;;
    *)              box_line "  iTerm2   : Settings > Profiles > Text > Font"
                    box_line "  Terminal : Settings > Profiles > Text > Font" ;;
  esac
  box_line ""
  box_line "Without it the file-tree icons, bufferline separators"
  box_line "and dashboard glyphs render as empty boxes."
  printf '%s╰─────────────────────────────────────────────────────────────╯%s\n\n' "$BOLD$YELLOW" "$RESET"
}

# ---------------------------------------------------------------------------
# Interaction helpers
#
# All reads come from /dev/tty rather than stdin, so prompts still work if the
# script is ever piped (curl | bash) and so a step's own stdin can't eat them.
# ---------------------------------------------------------------------------

# ask_yn "question" [default:y|n] -> returns 0 for yes, 1 for no
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

# Pause after a step so the user can read the output before moving on.
# Answering "q" aborts the whole run cleanly.
pause() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local reply
  printf '   %s↵ Press Enter to continue, or q to quit: %s' "$DIM" "$RESET"
  IFS= read -r reply < /dev/tty || reply=""
  case "$reply" in
    [Qq]*) banner "Aborted by user."; print_summary; exit 0 ;;
  esac
}

# On a failed step: never barrel ahead. Ask.
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

# run_cmd: echo a command, then run it (or not, under --dry-run).
# Output is shown to the user as required by the spec.
run_cmd() {
  printf '   %s$ %s%s\n' "$DIM" "$*" "$RESET"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '   %s(dry-run: not executed)%s\n' "$DIM" "$RESET"
    return 0
  fi
  "$@"
}

# ---------------------------------------------------------------------------
# The shared "check → prompt → install → show output → pause" pattern.
#
#   install_step <label> <detect-cmd> <version-cmd> <install-cmd...>
#
# detect-cmd and version-cmd are strings evaluated by the shell (they need
# pipes and command substitution); the install command is passed as argv.
# ---------------------------------------------------------------------------
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
      sed -n '2,26p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
      exit 0 ;;
    *) fail "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

# ===========================================================================
#                                  PREFLIGHT
# ===========================================================================
banner "Oncilla IDE — macOS bootstrap installer"

if [ "$(uname -s)" != "Darwin" ]; then
  fail "This installer is macOS-only (detected: $(uname -s))."
  exit 1
fi

info "Repo config source : $CONFIG_SRC"
info "macOS              : $(sw_vers -productVersion) ($(uname -m))"
[ "$DRY_RUN"    -eq 1 ] && warn "DRY RUN — nothing will actually be changed."
[ "$ASSUME_YES" -eq 1 ] && warn "ASSUME-YES — every prompt auto-answers yes."

if [ ! -d "$CONFIG_SRC" ]; then
  fail "Cannot find the Neovim config at: $CONFIG_SRC"
  info "This script must stay next to the 'nvim' directory inside 'macOS IDE/'."
  exit 1
fi

# Read the IDE version straight out of the config, so the installer and the
# dashboard can never disagree about which version was installed.
IDE_VERSION="$(
  awk '/^  major/{m=$3} /^  minor/{n=$3} /^  patch/{p=$3}
       END{gsub(/,/,"",m); gsub(/,/,"",n); gsub(/,/,"",p); print m"."n"."p}' \
      "$CONFIG_SRC/lua/oncilla/version.lua" 2>/dev/null
)"
[ -z "$IDE_VERSION" ] || [ "$IDE_VERSION" = ".." ] && IDE_VERSION="unknown"
info "Installing         : Oncilla IDE v$IDE_VERSION"
pause

# ===========================================================================
# Step 1 — Xcode Command Line Tools
# Provides cc/clang (treesitter parser compilation) and git (lazy.nvim clone).
# ===========================================================================
step "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  ok "Command Line Tools present — $(xcode-select -p)"
  record_skipped "Xcode CLT (present)"
else
  warn "Command Line Tools are missing. Treesitter cannot compile parsers without a C compiler."
  if ask_yn "Launch the Command Line Tools installer?" "y"; then
    run_cmd xcode-select --install
    warn "Finish the GUI installer, then re-run this script."
    exit 0
  else
    record_skipped "Xcode CLT (declined)"
    warn "Continuing without a compiler — treesitter parsers will fail to build."
  fi
fi
pause

# ===========================================================================
# Step 2 — Homebrew
# Everything downstream depends on it, so it goes first.
# ===========================================================================
step "Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed — $(brew --version | head -1)"
  record_skipped "Homebrew (present)"
else
  warn "Homebrew is not installed."
  info "The official installer will be downloaded from https://brew.sh and will ask for your password."
  if ask_yn "Install Homebrew now?" "y"; then
    if run_cmd /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      # A fresh install isn't on PATH yet in this shell session.
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      ok "Homebrew installed — $(brew --version | head -1)"
      record_installed "Homebrew"
      record_note "Add Homebrew to your shell: eval \"\$($(command -v brew) shellenv)\" in ~/.zprofile"
    else
      handle_failure "Homebrew"
    fi
  else
    fail "Homebrew is required. Nothing else can be installed without it."
    exit 1
  fi
fi
pause

# ===========================================================================
# Step 3 — System runtimes and CLI tools (Homebrew formulae)
#
# Ordering inside this step matters for one pair only: php must exist before
# composer is useful, and both must exist before Step 6. Everything else is
# order-independent, but they are grouped runtimes-first for readability.
# ===========================================================================
step "System runtimes and tools"

# brew_step <formula> <binary-to-detect> <why it's needed>
brew_step() {
  local formula="$1" bin="$2" why="$3"
  info "${DIM}$formula — $why${RESET}"
  install_step "$formula" \
    "command -v $bin" \
    "$bin --version" \
    brew install "$formula"
}

brew_step neovim   nvim         "the editor itself (config requires >= 0.11)"
brew_step git      git          "lazy.nvim clones plugins over git"
brew_step ripgrep  rg           "Telescope live_grep"
brew_step fd       fd           "Telescope find_files"
brew_step node     node         "runtime for ts_ls, intelephense, html/css/json, emmet, prettierd, eslint_d"
brew_step php      php          "runtime for Composer and phpcs/phpcbf"
brew_step composer composer     "installs phpcs/phpcbf (needs PHP above)"

# tree-sitter CLI: required specifically because treesitter.lua pins the
# `main` branch, which fetches and compiles parsers via the CLI. The `master`
# branch did not need this.
info "${DIM}tree-sitter — required by the 'main' branch of nvim-treesitter${RESET}"
install_step "tree-sitter CLI" \
  "command -v tree-sitter" \
  "tree-sitter --version" \
  brew install tree-sitter tree-sitter-cli

# Neovim version gate — the config uses vim.uv and vim.lsp.config(), both 0.11+.
if command -v nvim >/dev/null 2>&1; then
  NVIM_VER="$(nvim --version | head -1 | sed 's/^NVIM v//')"
  NVIM_MAJOR="${NVIM_VER%%.*}"
  NVIM_REST="${NVIM_VER#*.}"
  NVIM_MINOR="${NVIM_REST%%.*}"
  if [ "$NVIM_MAJOR" -eq 0 ] && [ "$NVIM_MINOR" -lt 11 ]; then
    warn "Neovim $NVIM_VER is too old. This config needs >= 0.11 (vim.uv, vim.lsp.config)."
    if ask_yn "Upgrade Neovim now?" "y"; then
      run_cmd brew upgrade neovim || handle_failure "neovim upgrade"
      record_installed "neovim (upgraded)"
    fi
  else
    ok "Neovim $NVIM_VER satisfies the >= 0.11 requirement."
  fi
fi
pause

# ===========================================================================
# Step 4 — Java (jdtls)
#
# Homebrew's openjdk is keg-only: `java` is NOT on PATH after install, and
# jdtls silently fails to start. The system-wide symlink below is the fix,
# and it is the only step in this script that needs sudo.
# ===========================================================================
step "Java / JDK — required by the jdtls language server"

install_step "openjdk" \
  "brew list --formula openjdk" \
  "brew list --versions openjdk" \
  brew install openjdk

JDK_LINK="/Library/Java/JavaVirtualMachines/openjdk.jdk"
JDK_TARGET="$(brew --prefix 2>/dev/null)/opt/openjdk/libexec/openjdk.jdk"

if command -v java >/dev/null 2>&1 && [ -e "$JDK_LINK" ]; then
  ok "java resolves — $(java --version 2>&1 | head -1)"
  record_skipped "JDK symlink (present)"
elif [ ! -d "$JDK_TARGET" ]; then
  warn "openjdk is not installed, so there is nothing to symlink. jdtls will not work."
  record_skipped "JDK symlink (no openjdk)"
else
  warn "openjdk is installed but keg-only — 'java' is not on PATH, so jdtls will fail."
  info "Fix: symlink the JDK into the system location."
  info "${DIM}  $JDK_TARGET${RESET}"
  info "${DIM}  -> $JDK_LINK${RESET}"
  warn "This is the ONLY step that requires sudo (writes to /Library)."
  if ask_yn "Create the JDK symlink with sudo?" "y"; then
    if run_cmd sudo ln -sfn "$JDK_TARGET" "$JDK_LINK"; then
      ok "JDK linked — $(java --version 2>&1 | head -1)"
      record_installed "JDK symlink"
    else
      handle_failure "JDK symlink"
    fi
  else
    skip "Skipped. jdtls (Java autocomplete) will not start until this is done."
    record_skipped "JDK symlink (declined)"
    record_note "Java autocomplete is disabled until the JDK symlink is created."
  fi
fi
pause

# ===========================================================================
# Step 5 — Nerd Font
#
# Needed by nvim-web-devicons (nvim-tree, bufferline) and by the glyphs
# hardcoded in the dashboard's key list.
# NOTE: `brew tap homebrew/cask-fonts` is deprecated — fonts now live in the
# main cask repository, so no tap is required.
# ===========================================================================
step "Nerd Font (JetBrains Mono)"
install_step "font-jetbrains-mono-nerd-font" \
  "brew list --cask font-jetbrains-mono-nerd-font" \
  "echo installed" \
  brew install --cask font-jetbrains-mono-nerd-font
record_note "MANUAL STEP: set your terminal's font to 'JetBrainsMono Nerd Font' (see summary)."

# ===========================================================================
# Step 6 — npm global packages
#
# conform.nvim and nvim-lint resolve these from PATH, NOT from Mason. Without
# them, format-on-save and linting silently do nothing.
# ===========================================================================
step "npm global packages (formatter + linter)"
if ! command -v npm >/dev/null 2>&1; then
  fail "npm is unavailable — node was skipped or failed. Cannot install prettierd/eslint_d."
  record_skipped "npm globals (no npm)"
else
  install_step "prettierd" \
    "command -v prettierd" \
    "prettierd --version" \
    npm install -g @fsouza/prettierd
  install_step "eslint_d" \
    "command -v eslint_d" \
    "eslint_d --version" \
    npm install -g eslint_d
fi

# ===========================================================================
# Step 7 — Composer globals + PATH
#
# php_codesniffer ships BOTH binaries the config wants: phpcs (linter, from
# nvim-lint) and phpcbf (formatter, from conform).
# ===========================================================================
step "Composer global packages (phpcs / phpcbf)"
if ! command -v composer >/dev/null 2>&1; then
  fail "composer is unavailable — PHP linting/formatting will not work."
  record_skipped "composer globals (no composer)"
else
  install_step "php_codesniffer (phpcs + phpcbf)" \
    "command -v phpcs" \
    "phpcs --version" \
    composer global require squizlabs/php_codesniffer
fi

# --- PATH entry, added only if genuinely absent (never duplicated) ---------
info "Checking ~/.zshrc for the Composer bin PATH entry..."
if [ -f "$ZSHRC" ] && grep -qF '.composer/vendor/bin' "$ZSHRC"; then
  COUNT="$(grep -cF '.composer/vendor/bin' "$ZSHRC")"
  if [ "$COUNT" -gt 1 ]; then
    warn "The Composer PATH entry appears $COUNT times in ~/.zshrc."
    info "Harmless, but untidy. This script will not edit existing lines — clean up by hand if you like."
    record_note "~/.zshrc has $COUNT duplicate Composer PATH lines (pre-existing; not touched)."
  else
    ok "Composer PATH entry already present (exactly once). Not adding it again."
  fi
  record_skipped "Composer PATH entry (already in ~/.zshrc)"
else
  warn "Composer PATH entry is missing — phpcs/phpcbf would not resolve in a new shell."
  info "Would append to $ZSHRC:"
  info "${DIM}  $COMPOSER_PATH_LINE${RESET}"
  if ask_yn "Append it to ~/.zshrc?" "y"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '   %s(dry-run: not appended)%s\n' "$DIM" "$RESET"
    else
      {
        printf '\n# Composer global binaries (added by Oncilla IDE bootstrap %s)\n' "$TIMESTAMP"
        printf '%s\n' "$COMPOSER_PATH_LINE"
      } >> "$ZSHRC"
    fi
    ok "Appended."
    record_installed "Composer PATH entry in ~/.zshrc"
    record_note "Run 'source ~/.zshrc' (or open a new terminal) to pick up the PATH change."
  else
    record_skipped "Composer PATH entry (declined)"
  fi
fi
pause

# ===========================================================================
# Step 8 — Existing Neovim / SpaceVim configuration
#
# Runs BEFORE anything config-related is written. Distinguishes:
#   (a) nothing there
#   (b) a real directory (stock / kickstart / LazyVim / SpaceVim)
#   (c) a symlink — including one already pointing at THIS repo
# and treats a symlink differently from a directory (never `mv` a symlink as
# if it were a folder).
# ===========================================================================
step "Existing Neovim configuration"

NVIM_CONFIG="$HOME/.config/nvim"
NVIM_DATA="$HOME/.local/share/nvim"
NVIM_STATE="$HOME/.local/state/nvim"
NVIM_CACHE="$HOME/.cache/nvim"

# --- Classify what is at ~/.config/nvim ------------------------------------
EXISTING="none"
LINK_TARGET=""
if [ -L "$NVIM_CONFIG" ]; then
  # -L must be tested BEFORE -d: a symlink to a directory satisfies both.
  LINK_TARGET="$(readlink "$NVIM_CONFIG")"
  case "$LINK_TARGET" in
    /*) ;;                                        # already absolute
    *)  LINK_TARGET="$HOME/.config/$LINK_TARGET" ;;  # resolve relative link
  esac
  if [ "$LINK_TARGET" = "$CONFIG_SRC" ]; then
    EXISTING="symlink-self"
  else
    EXISTING="symlink-other"
  fi
elif [ -d "$NVIM_CONFIG" ]; then
  EXISTING="directory"
fi

# --- Identify the flavour of an existing real directory --------------------
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

# --- Report everything found, including related state dirs -----------------
case "$EXISTING" in
  none)          ok "~/.config/nvim does not exist — clean install." ;;
  symlink-self)  ok "~/.config/nvim is already a symlink to THIS repo."
                 info "${DIM}  -> $LINK_TARGET${RESET}"
                 info "This script has been run here before." ;;
  symlink-other) warn "~/.config/nvim is a symlink to a DIFFERENT location:"
                 info "${DIM}  -> $LINK_TARGET${RESET}"
                 info "It will be removed as a link — the directory it points at is never touched." ;;
  directory)     warn "~/.config/nvim is a real directory: $FLAVOUR" ;;
esac

for d in "$NVIM_DATA" "$NVIM_STATE" "$NVIM_CACHE" "$HOME/.SpaceVim" "$HOME/.SpaceVim.d"; do
  [ -e "$d" ] && info "${DIM}  also present: $d${RESET}"
done

# --- Present the three choices --------------------------------------------
if [ "$EXISTING" = "none" ] && [ -z "$FORCED_MODE" ]; then
  INSTALL_MODE="replace"   # nothing to preserve; plain symlink install
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
  printf '        config at ~/.config/<name> using Neovim'"'"'s NVIM_APPNAME, and\n'
  printf '        adds a shell alias so both editors coexist:\n'
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

# --- Option 1: back up whatever is in the way ------------------------------
if [ "$INSTALL_MODE" = "replace" ] && [ "$EXISTING" != "none" ]; then

  if [ "$EXISTING" = "symlink-self" ]; then
    info "The symlink already points here; there is nothing to back up."
    if ask_yn "Re-create the symlink anyway (harmless refresh)?" "n"; then
      run_cmd rm -f "$NVIM_CONFIG"
      EXISTING="none"
    fi
  elif [ "$EXISTING" = "symlink-other" ]; then
    # A symlink is unlinked, never moved — moving it would drag the name
    # around without preserving anything meaningful.
    info "Removing the symlink (its target directory is left alone)."
    if run_cmd rm -f "$NVIM_CONFIG"; then
      ok "Symlink removed."
      record_backup "removed symlink ~/.config/nvim -> $LINK_TARGET (target untouched)"
    else
      handle_failure "removing existing symlink"
    fi
  else
    # A real directory is moved aside, never deleted.
    BACKUP="$NVIM_CONFIG.bak.$TIMESTAMP"
    info "Backing up $FLAVOUR:"
    info "${DIM}  $NVIM_CONFIG -> $BACKUP${RESET}"
    if run_cmd mv "$NVIM_CONFIG" "$BACKUP"; then
      ok "Config backed up."
      record_backup "$NVIM_CONFIG -> $BACKUP"
    else
      handle_failure "backing up ~/.config/nvim"
    fi

    # Stale plugin/runtime data from the previous config will confuse lazy.nvim
    # and Mason, so offer to move it aside too. Asked separately: some people
    # want a truly clean slate, others want to keep the old install intact.
    if [ -d "$NVIM_DATA" ] || [ -d "$NVIM_STATE" ] || [ -d "$NVIM_CACHE" ]; then
      warn "Plugin/runtime data from the previous config is still present."
      info "Leaving it can confuse lazy.nvim and Mason on first launch."
      if ask_yn "Also back up nvim data/state/cache directories?" "y"; then
        for d in "$NVIM_DATA" "$NVIM_STATE" "$NVIM_CACHE"; do
          if [ -e "$d" ]; then
            if run_cmd mv "$d" "$d.bak.$TIMESTAMP"; then
              record_backup "$d -> $d.bak.$TIMESTAMP"
            else
              warn "Could not back up $d — continuing."
            fi
          fi
        done
        ok "Runtime data backed up."
      else
        record_note "Existing nvim data/state/cache kept in place — may conflict with lazy.nvim."
      fi
    fi

    # SpaceVim keeps its own state outside ~/.config/nvim.
    if [ -d "$HOME/.SpaceVim" ] || [ -d "$HOME/.SpaceVim.d" ]; then
      warn "SpaceVim directories detected (~/.SpaceVim, ~/.SpaceVim.d)."
      info "They do not conflict with this config, but you may want them out of the way."
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
# Step 9 — Install the config (symlink, or NVIM_APPNAME + alias)
# ===========================================================================
step "Installing the Oncilla IDE config"

# add_zshrc_line <literal-line> <comment> — idempotent by exact-string grep.
add_zshrc_line() {
  local line="$1" comment="$2"
  if [ -f "$ZSHRC" ] && grep -qF "$line" "$ZSHRC"; then
    ok "Already in ~/.zshrc — not adding a duplicate:"
    info "${DIM}  $line${RESET}"
    record_skipped "~/.zshrc line (already present)"
    return 0
  fi
  info "Would append to $ZSHRC:"
  info "${DIM}  $line${RESET}"
  if ask_yn "Append it?" "y"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '   %s(dry-run: not appended)%s\n' "$DIM" "$RESET"
    else
      { printf '\n# %s (added by Oncilla IDE bootstrap %s)\n' "$comment" "$TIMESTAMP"
        printf '%s\n' "$line"; } >> "$ZSHRC"
    fi
    ok "Appended."
    record_installed "~/.zshrc: $line"
    record_note "Run 'source ~/.zshrc' or open a new terminal for it to take effect."
  else
    record_skipped "~/.zshrc line (declined)"
  fi
}

if [ "$INSTALL_MODE" = "sidebyside" ]; then
  # ---- Side-by-side install via NVIM_APPNAME ------------------------------
  if [ "$ASSUME_YES" -eq 1 ]; then
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
    EXISTING_TARGET="$(readlink "$TARGET")"
    if [ "$EXISTING_TARGET" = "$CONFIG_SRC" ]; then
      ok "$TARGET already links to this repo. Nothing to do."
      record_skipped "$TARGET symlink (already correct)"
    else
      warn "$TARGET is a symlink to something else: $EXISTING_TARGET"
      if ask_yn "Repoint it at this repo?" "y"; then
        run_cmd ln -sfn "$CONFIG_SRC" "$TARGET" && record_installed "$TARGET -> $CONFIG_SRC"
      fi
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
    mkdir -p "$HOME/.config"
    if run_cmd ln -sfn "$CONFIG_SRC" "$TARGET"; then
      ok "Linked $TARGET -> $CONFIG_SRC"
      record_installed "$TARGET -> $CONFIG_SRC"
    else
      handle_failure "creating $TARGET symlink"
    fi
  fi

  add_zshrc_line "alias $ALIAS_NAME='NVIM_APPNAME=$APPNAME nvim'" "Oncilla IDE launcher"
  record_note "Launch the Oncilla IDE with: $ALIAS_NAME   (plain 'nvim' still runs your old config)"

else
  # ---- Replace mode: plain symlink at ~/.config/nvim ----------------------
  mkdir -p "$HOME/.config"
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
  # In replace mode ~/.config/nvim IS the IDE, so `ovim` is just a second name
  # for the same editor -- no NVIM_APPNAME, one config, one plugin tree.
  add_zshrc_line "alias ovim='nvim'" "Oncilla IDE launcher"
  ALIAS_NAME="ovim"
  record_note "Launch with: ovim (or nvim -- both open this config)"
fi
pause

# ===========================================================================
# Step 10 — First launch: let lazy.nvim and Mason do their work
#
# Deliberately LAST: Mason resolves jdtls against java, and the npm-based
# servers against node. Both must already exist, which they now do.
# ===========================================================================
step "First launch — plugin and LSP installation"

info "The first run will:"
info "  1. bootstrap lazy.nvim and install all 31 pinned plugins"
info "  2. compile treesitter parsers (lua, java, ts, tsx, js, php, html, css, scss, json, xml)"
info "  3. have Mason download 8 language servers"
info "This takes a few minutes and needs a network connection."

if ask_yn "Run the headless first-launch now?" "y"; then
  export NVIM_APPNAME="$APPNAME"
  info "Syncing plugins (NVIM_APPNAME=$APPNAME)..."
  if run_cmd nvim --headless "+Lazy! sync" +qa; then
    ok "Plugins synced."
    record_installed "lazy.nvim plugin sync"
  else
    handle_failure "lazy.nvim plugin sync"
  fi

  info "Giving Mason a run to fetch language servers..."
  # Mason installs asynchronously on setup; the sleep lets it finish enough
  # work to be useful. Anything unfinished completes on the next real launch.
  run_cmd nvim --headless "+sleep 60" +qa
  ok "Mason kicked off. Check progress inside Neovim with :Mason."
  record_note "Verify servers with :Mason and :checkhealth after opening the editor."
  unset NVIM_APPNAME
else
  record_skipped "first launch (declined)"
  record_note "Plugins install automatically the first time you open the editor."
fi
pause

# ===========================================================================
# Summary
# ===========================================================================

print_summary
banner "Oncilla IDE v$IDE_VERSION — bootstrap complete."
