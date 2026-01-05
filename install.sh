#!/usr/bin/env bash
#
# Claude Code Notification Tool - Installer
# Interactively configures notification settings and Claude Code hooks
#

set -euo pipefail

# Configuration paths
CONFIG_DIR="${HOME}/.config/claude-notify"
CONFIG_FILE="${CONFIG_DIR}/config"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Configure Claude Code hooks
configure_hooks() {
    print_step "Configuring Claude Code hooks..."

    local notify_path="$INSTALL_DIR/claude-notify"

    # Create Claude settings directory if needed
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

    # Check if settings.json exists
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        # Backup existing settings
        cp "$CLAUDE_SETTINGS" "${CLAUDE_SETTINGS}.backup.$(date +%Y%m%d%H%M%S)"
        print_success "Backed up existing settings"

        # Read existing settings
        local existing
        existing=$(cat "$CLAUDE_SETTINGS")

        # Check if hooks already exist
        if echo "$existing" | jq -e '.hooks' &>/dev/null; then
            print_warning "Hooks already configured in settings.json"
            read -rp "Overwrite hooks configuration? [y/N]: " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                echo "Skipping hooks configuration"
                return
            fi
        fi

        # Merge hooks into existing settings
        local new_settings
        new_settings=$(echo "$existing" | jq --arg path "$notify_path" '
            .hooks = {
                "Notification": [
                    {
                        "matcher": "",
                        "hooks": [
                            {
                                "type": "command",
                                "command": ($path + " notification")
                            }
                        ]
                    }
                ],
                "Stop": [
                    {
                        "matcher": "",
                        "hooks": [
                            {
                                "type": "command",
                                "command": ($path + " stop")
                            }
                        ]
                    }
                ]
            }
        ')

        echo "$new_settings" > "$CLAUDE_SETTINGS"
    else
        # Create new settings file
        jq -n --arg path "$notify_path" '
            {
                "hooks": {
                    "Notification": [
                        {
                            "matcher": "",
                            "hooks": [
                                {
                                    "type": "command",
                                    "command": ($path + " notification")
                                }
                            ]
                        }
                    ],
                    "Stop": [
                        {
                            "matcher": "",
                            "hooks": [
                                {
                                    "type": "command",
                                    "command": ($path + " stop")
                                }
                            ]
                        }
                    ]
                }
            }
        ' > "$CLAUDE_SETTINGS"
    fi

    print_success "Claude Code hooks configured"
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

# Main installation flow
main() {
    print_banner

    check_dependencies
    select_channel

    case "$NOTIFY_CHANNEL" in
        telegram) configure_telegram ;;
        slack)    configure_slack ;;
        webhook)  configure_webhook ;;
    esac

    save_config
    install_script
    configure_hooks

    echo ""
    read -rp "Send a test notification? [Y/n]: " send_test
    if [[ ! "$send_test" =~ ^[Nn]$ ]]; then
        test_notification
    fi

    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo "Configuration: $CONFIG_FILE"
    echo "Script:        $INSTALL_DIR/claude-notify"
    echo "Claude hooks:  $CLAUDE_SETTINGS"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  claude-notify notification  # Notify when input needed"
    echo "  claude-notify stop          # Notify when task completed"
    echo "  claude-notify --test        # Send test notification"
}

# Handle uninstall
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling claude-notify..."

    rm -f "$INSTALL_DIR/claude-notify"
    rm -rf "$CONFIG_DIR"

    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        # Remove hooks from settings
        local new_settings
        new_settings=$(jq 'del(.hooks)' "$CLAUDE_SETTINGS")
        echo "$new_settings" > "$CLAUDE_SETTINGS"
    fi

    print_success "Uninstalled successfully"
    exit 0
fi

main
