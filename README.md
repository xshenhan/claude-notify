# Claude Code Notify

Get notified when Claude Code needs your attention or completes a task.

Perfect for running multiple Claude Code instances on a remote server via SSH.

## Features

- **Notification Hook** - Get notified when Claude needs user input
- **Stop Hook** - Get notified when a task is completed
- **Project Context** - Notifications include project directory name
- **Multiple Channels** - Telegram, Slack, or custom webhook

## Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/claude-notify.git
cd claude-notify

# Run the installer
./install.sh
```

The installer will:
1. Check dependencies (curl, jq)
2. Guide you through channel configuration
3. Install the notify script to `~/.local/bin/`
4. Configure Claude Code hooks in `~/.claude/settings.json`
5. Send a test notification

## Requirements

- `curl` - For sending HTTP requests
- `jq` - For JSON processing

```bash
# Ubuntu/Debian
sudo apt install curl jq

# CentOS/RHEL
sudo yum install curl jq

# macOS
brew install curl jq
```

## Notification Channels

### Telegram (Recommended)

1. Create a bot via [@BotFather](https://t.me/botfather)
2. Start a chat with your bot
3. Get your chat ID from `https://api.telegram.org/bot<TOKEN>/getUpdates`

### Slack

1. Create a [Slack App](https://api.slack.com/apps)
2. Enable Incoming Webhooks
3. Add webhook to your channel

### Custom Webhook

Receives POST requests with JSON payload:

```json
{
  "event": "notification|stop",
  "project": "project-name",
  "message": "formatted message"
}
```

## Manual Configuration

### Config File

Create `~/.config/claude-notify/config`:

```bash
NOTIFY_CHANNEL="telegram"
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

### Environment Variables

Alternatively, use environment variables:

```bash
export NOTIFY_CHANNEL="telegram"
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

### Claude Code Hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/claude-notify notification"
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
            "command": "~/.local/bin/claude-notify stop"
          }
        ]
      }
    ]
  }
}
```

## Usage

```bash
# Notify when input is needed
claude-notify notification

# Notify when task is completed
claude-notify stop

# Send a test notification
claude-notify --test

# Show help
claude-notify --help
```

## Example Notifications

**Input Required:**
```
🔔 Claude Code - Input Required

📁 Project: my-awesome-project
🖥️ Host: dev-server
⏰ Time: 2024-01-15 14:30:00
```

**Task Completed:**
```
✅ Claude Code - Task Completed

📁 Project: my-awesome-project
🖥️ Host: dev-server
⏰ Time: 2024-01-15 14:35:00
```

## Uninstall

```bash
./install.sh --uninstall
```

Or manually:

```bash
rm ~/.local/bin/claude-notify
rm -rf ~/.config/claude-notify
# Remove hooks from ~/.claude/settings.json
```

## License

MIT
