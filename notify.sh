#!/usr/bin/env bash
#
# Claude Code Notification Script
# Sends notifications via Telegram, Slack, or custom webhook
#

set -euo pipefail

# Configuration
CONFIG_DIR="${HOME}/.config/claude-notify"
CONFIG_FILE="${CONFIG_DIR}/config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    # Environment variables override config file
    NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-${CLAUDE_NOTIFY_CHANNEL:-telegram}}"

    # Telegram
    TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-${CLAUDE_TELEGRAM_BOT_TOKEN:-}}"
    TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-${CLAUDE_TELEGRAM_CHAT_ID:-}}"

    # Slack
    SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-${CLAUDE_SLACK_WEBHOOK_URL:-}}"

    # Custom Webhook
    WEBHOOK_URL="${WEBHOOK_URL:-${CLAUDE_WEBHOOK_URL:-}}"
}

# Get project name from current directory
get_project_name() {
    basename "${PWD}"
}

# Send Telegram notification
send_telegram() {
    local message="$1"

    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        echo -e "${RED}Error: Telegram credentials not configured${NC}" >&2
        echo "Please set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID" >&2
        return 1
    fi

    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"${message}\", \"parse_mode\": \"Markdown\"}" \
        --connect-timeout 10 \
        --max-time 30)

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        echo -e "${RED}Error: Telegram API returned HTTP $http_code${NC}" >&2
        echo "$body" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Telegram notification sent${NC}"
}

# Send Slack notification
send_slack() {
    local message="$1"

    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        echo -e "${RED}Error: Slack webhook URL not configured${NC}" >&2
        return 1
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$SLACK_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${message}\"}" \
        --connect-timeout 10 \
        --max-time 30)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" != "200" ]]; then
        echo -e "${RED}Error: Slack webhook returned HTTP $http_code${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Slack notification sent${NC}"
}

# Send custom webhook notification
send_webhook() {
    local message="$1"
    local event_type="$2"

    if [[ -z "$WEBHOOK_URL" ]]; then
        echo -e "${RED}Error: Webhook URL not configured${NC}" >&2
        return 1
    fi

    local project
    project=$(get_project_name)

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"event\": \"${event_type}\", \"project\": \"${project}\", \"message\": \"${message}\"}" \
        --connect-timeout 10 \
        --max-time 30)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" -lt 200 ]] || [[ "$http_code" -ge 300 ]]; then
        echo -e "${RED}Error: Webhook returned HTTP $http_code${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Webhook notification sent${NC}"
}

# Send notification based on configured channel
send_notification() {
    local message="$1"
    local event_type="${2:-notification}"

    case "$NOTIFY_CHANNEL" in
        telegram)
            send_telegram "$message"
            ;;
        slack)
            send_slack "$message"
            ;;
        webhook)
            send_webhook "$message" "$event_type"
            ;;
        *)
            echo -e "${RED}Error: Unknown notification channel: $NOTIFY_CHANNEL${NC}" >&2
            return 1
            ;;
    esac
}

# Format notification message
format_message() {
    local event_type="$1"
    local project
    project=$(get_project_name)
    local hostname
    hostname=$(hostname -s 2>/dev/null || echo "unknown")

    local emoji title
    case "$event_type" in
        notification)
            emoji="🔔"
            title="Input Required"
            ;;
        stop)
            emoji="✅"
            title="Task Completed"
            ;;
        *)
            emoji="📢"
            title="Notification"
            ;;
    esac

    echo "${emoji} *Claude Code - ${title}*

📁 Project: \`${project}\`
🖥️ Host: \`${hostname}\`
⏰ Time: $(date '+%Y-%m-%d %H:%M:%S')"
}

# Main function
main() {
    local event_type="${1:-notification}"

    load_config

    local message
    message=$(format_message "$event_type")

    # Retry logic with exponential backoff
    local max_retries=3
    local retry_delay=1

    for ((i=1; i<=max_retries; i++)); do
        if send_notification "$message" "$event_type"; then
            return 0
        fi

        if [[ $i -lt $max_retries ]]; then
            echo -e "${YELLOW}Retrying in ${retry_delay}s... (attempt $((i+1))/$max_retries)${NC}"
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))
        fi
    done

    echo -e "${RED}Failed to send notification after $max_retries attempts${NC}" >&2
    return 1
}

# Handle script arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $(basename "$0") [EVENT_TYPE]"
        echo ""
        echo "Event types:"
        echo "  notification  - Claude needs user input (default)"
        echo "  stop          - Task completed"
        echo ""
        echo "Configuration:"
        echo "  Config file: $CONFIG_FILE"
        echo "  Or use environment variables:"
        echo "    NOTIFY_CHANNEL        - telegram, slack, or webhook"
        echo "    TELEGRAM_BOT_TOKEN    - Telegram bot token"
        echo "    TELEGRAM_CHAT_ID      - Telegram chat ID"
        echo "    SLACK_WEBHOOK_URL     - Slack incoming webhook URL"
        echo "    WEBHOOK_URL           - Custom webhook URL"
        exit 0
        ;;
    -t|--test)
        load_config
        echo "Testing notification..."
        message="🧪 *Test Notification*

This is a test from claude-notify.
📁 Project: \`$(get_project_name)\`
⏰ Time: $(date '+%Y-%m-%d %H:%M:%S')"
        send_notification "$message" "test"
        ;;
    *)
        main "${1:-notification}"
        ;;
esac
