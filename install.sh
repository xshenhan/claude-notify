#!/usr/bin/env bash
#
# Claude Code Notification Tool - Installer
# Interactively configures notification settings and Claude Code hooks
#
# Usage:
#   ./install.sh              # Full install with global hooks
#   ./install.sh --local      # Configure hooks for current project only
#   ./install.sh --hooks-only # Only configure hooks (skip script install)
#   ./install.sh --uninstall  # Remove claude-notify
#

set -euo pipefail

# Configuration paths
CONFIG_DIR="${HOME}/.config/claude-notify"
CONFIG_FILE="${CONFIG_DIR}/config"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Options
LOCAL_MODE=false
HOOKS_ONLY=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║     Claude Code Notification Installer    ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Get settings file path based on mode
get_settings_path() {
    if [[ "$LOCAL_MODE" == true ]]; then
        echo "${PWD}/.claude/settings.local.json"
    else
        echo "${HOME}/.claude/settings.json"
    fi
}

# Check dependencies
check_dependencies() {
    print_step "Checking dependencies..."

    local missing=()

    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi

    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo "Please install them first:"
        echo "  Ubuntu/Debian: sudo apt install ${missing[*]}"
        echo "  CentOS/RHEL:   sudo yum install ${missing[*]}"
        echo "  macOS:         brew install ${missing[*]}"
        exit 1
    fi

    print_success "All dependencies installed"
}

# Select notification channel
select_channel() {
    print_step "Select notification channel"
    echo ""
    echo "  1) Telegram (recommended)"
    echo "  2) Slack"
    echo "  3) Custom Webhook"
    echo ""

    while true; do
        read -rp "Enter choice [1-3]: " choice
        case "$choice" in
            1) NOTIFY_CHANNEL="telegram"; break ;;
            2) NOTIFY_CHANNEL="slack"; break ;;
            3) NOTIFY_CHANNEL="webhook"; break ;;
            *) echo "Invalid choice. Please enter 1, 2, or 3." ;;
        esac
    done

    print_success "Selected: $NOTIFY_CHANNEL"
}

# Configure Telegram
configure_telegram() {
    print_step "Configuring Telegram"
    echo ""
    echo -e "${CYAN}To get your Telegram Bot Token:${NC}"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send /newbot and follow the instructions"
    echo "  3. Copy the token provided"
    echo ""

    read -rp "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN

    echo ""
    echo -e "${CYAN}To get your Chat ID:${NC}"
    echo "  1. Start a chat with your bot"
    echo "  2. Send any message to the bot"
    echo "  3. Visit: https://api.telegram.org/bot<TOKEN>/getUpdates"
    echo "  4. Look for \"chat\":{\"id\":XXXXXXXX}"
    echo ""

    read -rp "Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
}

# Configure Slack
configure_slack() {
    print_step "Configuring Slack"
    echo ""
    echo -e "${CYAN}To get your Slack Webhook URL:${NC}"
    echo "  1. Go to https://api.slack.com/apps"
    echo "  2. Create a new app or select existing one"
    echo "  3. Enable 'Incoming Webhooks'"
    echo "  4. Add webhook to a channel and copy the URL"
    echo ""

    read -rp "Enter Slack Webhook URL: " SLACK_WEBHOOK_URL
}

# Configure custom webhook
configure_webhook() {
    print_step "Configuring Custom Webhook"
    echo ""
    echo -e "${CYAN}The webhook will receive POST requests with JSON:${NC}"
    echo '  {"event": "notification|stop", "project": "...", "message": "..."}'
    echo ""

    read -rp "Enter Webhook URL: " WEBHOOK_URL
}

# Save configuration
save_config() {
    print_step "Saving configuration..."

    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG_FILE" << EOF
# Claude Code Notification Configuration
# Generated on $(date)

NOTIFY_CHANNEL="$NOTIFY_CHANNEL"

EOF

    case "$NOTIFY_CHANNEL" in
        telegram)
            cat >> "$CONFIG_FILE" << EOF
# Telegram Configuration
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
            ;;
        slack)
            cat >> "$CONFIG_FILE" << EOF
# Slack Configuration
SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"
EOF
            ;;
        webhook)
            cat >> "$CONFIG_FILE" << EOF
# Custom Webhook Configuration
WEBHOOK_URL="$WEBHOOK_URL"
EOF
            ;;
    esac

    chmod 600 "$CONFIG_FILE"
    print_success "Configuration saved to $CONFIG_FILE"
}

# Install notify script
install_script() {
    print_step "Installing notify script..."

    mkdir -p "$INSTALL_DIR"

    cp "$SCRIPT_DIR/notify.sh" "$INSTALL_DIR/claude-notify"
    chmod +x "$INSTALL_DIR/claude-notify"

    print_success "Script installed to $INSTALL_DIR/claude-notify"

    # Check if INSTALL_DIR is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_warning "$INSTALL_DIR is not in your PATH"
        echo "Add this to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# Configure Claude Code hooks (with merge support)
configure_hooks() {
    local settings_path
    settings_path=$(get_settings_path)
    local settings_dir
    settings_dir=$(dirname "$settings_path")

    if [[ "$LOCAL_MODE" == true ]]; then
        print_step "Configuring project-level hooks..."
        echo -e "  ${CYAN}Target: ${settings_path}${NC}"
    else
        print_step "Configuring global hooks..."
        echo -e "  ${CYAN}Target: ${settings_path}${NC}"
    fi

    local notify_path="$INSTALL_DIR/claude-notify"

    # Create directory if needed
    mkdir -p "$settings_dir"

    # Define the new hooks to add
    local notification_hook
    notification_hook=$(jq -n --arg cmd "$notify_path notification" '{
        "matcher": "",
        "hooks": [{"type": "command", "command": $cmd}]
    }')

    local stop_hook
    stop_hook=$(jq -n --arg cmd "$notify_path stop" '{
        "matcher": "",
        "hooks": [{"type": "command", "command": $cmd}]
    }')

    if [[ -f "$settings_path" ]]; then
        # Backup existing settings
        cp "$settings_path" "${settings_path}.backup.$(date +%Y%m%d%H%M%S)"
        print_success "Backed up existing settings"

        # Read existing settings
        local existing
        existing=$(cat "$settings_path")

        # Show existing hooks
        if echo "$existing" | jq -e '.hooks' &>/dev/null; then
            echo ""
            echo -e "${CYAN}Existing hooks:${NC}"
            echo "$existing" | jq '.hooks'
            echo ""
        fi

        # Merge hooks (append to existing arrays)
        local new_settings
        new_settings=$(echo "$existing" | jq \
            --argjson notif "$notification_hook" \
            --argjson stop "$stop_hook" '
            # Initialize hooks object if not exists
            .hooks //= {}
            # Append to Notification array (or create it)
            | .hooks.Notification = (.hooks.Notification // []) + [$notif]
            # Append to Stop array (or create it)
            | .hooks.Stop = (.hooks.Stop // []) + [$stop]
        ')

        echo "$new_settings" > "$settings_path"
        print_success "Hooks merged into existing configuration"
    else
        # Create new settings file
        jq -n \
            --argjson notif "$notification_hook" \
            --argjson stop "$stop_hook" '{
            "hooks": {
                "Notification": [$notif],
                "Stop": [$stop]
            }
        }' > "$settings_path"
        print_success "Created new settings file with hooks"
    fi

    # Show final hooks config
    echo ""
    echo -e "${CYAN}Final hooks configuration:${NC}"
    jq '.hooks' "$settings_path"
}

# Test notification
test_notification() {
    print_step "Testing notification..."

    if "$INSTALL_DIR/claude-notify" --test; then
        print_success "Test notification sent successfully!"
    else
        print_error "Failed to send test notification"
        echo "Please check your configuration and try again"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --local       Configure hooks for current project only"
    echo "                (creates .claude/settings.local.json in current directory)"
    echo "  --hooks-only  Only configure hooks (skip script and config installation)"
    echo "  --uninstall   Remove claude-notify"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./install.sh              # Full install with global hooks"
    echo "  ./install.sh --local      # Project-level hooks only"
    echo "  ./install.sh --hooks-only --local  # Just add hooks to current project"
}

# Handle uninstall
do_uninstall() {
    echo "Uninstalling claude-notify..."

    rm -f "$INSTALL_DIR/claude-notify"
    rm -rf "$CONFIG_DIR"

    local settings_path
    settings_path=$(get_settings_path)

    if [[ -f "$settings_path" ]]; then
        print_warning "Hooks in $settings_path were not removed"
        echo "Please manually remove the Notification and Stop hooks if needed"
    fi

    print_success "Uninstalled successfully"
}

# Main installation flow
main() {
    print_banner

    if [[ "$LOCAL_MODE" == true ]]; then
        echo -e "${YELLOW}Local mode: hooks will be added to current project only${NC}"
        echo -e "Project: ${CYAN}${PWD}${NC}"
    fi

    check_dependencies

    if [[ "$HOOKS_ONLY" == false ]]; then
        # Check if already configured
        if [[ -f "$CONFIG_FILE" ]]; then
            print_warning "Configuration already exists at $CONFIG_FILE"
            read -rp "Reconfigure notification settings? [y/N]: " reconfig
            if [[ "$reconfig" =~ ^[Yy]$ ]]; then
                select_channel
                case "$NOTIFY_CHANNEL" in
                    telegram) configure_telegram ;;
                    slack)    configure_slack ;;
                    webhook)  configure_webhook ;;
                esac
                save_config
            fi
        else
            select_channel
            case "$NOTIFY_CHANNEL" in
                telegram) configure_telegram ;;
                slack)    configure_slack ;;
                webhook)  configure_webhook ;;
            esac
            save_config
        fi

        install_script
    fi

    configure_hooks

    if [[ "$HOOKS_ONLY" == false ]]; then
        echo ""
        read -rp "Send a test notification? [Y/n]: " send_test
        if [[ ! "$send_test" =~ ^[Nn]$ ]]; then
            test_notification
        fi
    fi

    local settings_path
    settings_path=$(get_settings_path)

    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    if [[ "$HOOKS_ONLY" == false ]]; then
        echo "Configuration: $CONFIG_FILE"
        echo "Script:        $INSTALL_DIR/claude-notify"
    fi
    echo "Claude hooks:  $settings_path"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  claude-notify notification  # Notify when input needed"
    echo "  claude-notify stop          # Notify when task completed"
    echo "  claude-notify --test        # Send test notification"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            LOCAL_MODE=true
            shift
            ;;
        --hooks-only)
            HOOKS_ONLY=true
            shift
            ;;
        --uninstall)
            do_uninstall
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

main
