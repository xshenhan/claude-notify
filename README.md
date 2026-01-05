# Claude Code Notify

Get notified when Claude Code needs your attention or completes a task.

Perfect for running multiple Claude Code instances on a remote server via SSH.

## Features

- **Stop Hook** - Get notified when Claude completes a response and waits for input
- **Notification Hook** - Get notified for permission requests, idle prompts, etc.
- **Session Context** - Notifications include session ID and task summary
- **Project Context** - Notifications include project directory and hostname
- **Multiple Channels** - Telegram, Slack, or custom webhook

## Quick Start

```bash
# Clone the repository
git clone https://github.com/xshenhan/claude-notify.git
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

**Important:** After installation, restart your Claude Code session for hooks to take effect.

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
   - Send `/newbot` and follow instructions
   - Save the bot token
2. Start a chat with your bot and send any message
3. Get your chat ID from `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Look for `"chat":{"id":XXXXXXXX}`

### Slack

1. Create a [Slack App](https://api.slack.com/apps)
2. Enable Incoming Webhooks
3. Add webhook to your channel
4. Copy the webhook URL

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

If you prefer manual setup instead of using `install.sh`:

### 1. Config File

Create `~/.config/claude-notify/config`:

```bash
NOTIFY_CHANNEL="telegram"
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

### 2. Install Script

```bash
mkdir -p ~/.local/bin
cp notify.sh ~/.local/bin/claude-notify
chmod +x ~/.local/bin/claude-notify
```

### 3. Claude Code Hooks

Add to `~/.claude/settings.json` (use **absolute path**, not `~`):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/home/YOUR_USERNAME/.local/bin/claude-notify notification"
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
            "command": "/home/YOUR_USERNAME/.local/bin/claude-notify stop"
          }
        ]
      }
    ]
  }
}
```

**Important:**
- Replace `YOUR_USERNAME` with your actual username
- Use absolute paths (e.g., `/home/user/...`), not `~` - Claude Code doesn't expand `~`
- Restart Claude Code session after modifying hooks

### Merging with Existing Hooks

If you already have hooks configured, add the Notification and Stop hooks to your existing configuration rather than replacing it.

## Usage

```bash
# Send a test notification
claude-notify --test

# Manually trigger notifications (usually called by hooks)
claude-notify notification
claude-notify stop

# Show help
claude-notify --help
```

## Example Notifications

**Task Completed (Stop hook):**
```
✅ Claude Code - Task Completed

📁 Project: my-awesome-project
🖥️ Host: dev-server
🆔 Session: abc12345
📝 Task: Help me implement a new feature...
⏰ Time: 2024-01-15 14:35:00
```

**Input Required (Notification hook):**
```
🔔 Claude Code - Input Required

📁 Project: my-awesome-project
🖥️ Host: dev-server
🆔 Session: abc12345
📝 Task: Help me implement a new feature...
💬 Claude needs your permission to use Bash
⏰ Time: 2024-01-15 14:30:00
```

## How It Works

- **Stop Hook**: Triggers every time Claude finishes responding and waits for your input
- **Notification Hook**: Triggers for specific events like permission requests (after 60s idle)

The script reads context from Claude Code via stdin JSON, including:
- `session_id` - Unique session identifier
- `message` - Notification message (for Notification hook)
- `transcript_path` - Path to conversation history (used to extract task summary)

## Troubleshooting

### Notifications not working?

1. **Check hooks are configured correctly:**
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```

2. **Test the script directly:**
   ```bash
   ~/.local/bin/claude-notify --test
   ```

3. **Check with debug logging:**
   ```bash
   # Temporarily add logging to your hook command:
   "/path/to/claude-notify stop >> /tmp/claude-notify.log 2>&1"
   ```

4. **Restart Claude Code** - Hooks are loaded at session start

### Using absolute paths

Claude Code doesn't expand `~` in hook commands. Always use absolute paths like `/home/username/...`.

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
