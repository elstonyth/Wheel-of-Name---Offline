# Wheel of Names - Offline Clone

An offline clone of [Wheel of Names](https://wheelofnames.com) with remote control capabilities.

## Features

- 🎡 **Full offline functionality** - Clone and run without internet
- 📱 **Remote Control** - Control the wheel from your phone
- 🎯 **Cheat Mode** - Force winners with keyboard shortcuts
- 🔐 **SSL Support** - HTTPS with self-signed certificates
- 📦 **Portable Mode** - Run without installing Node.js
- 📱 **QR Code Access** - Scan QR code to connect remotely

## Quick Start

### Regular Mode (Requires Node.js)

1. Clone and install dependencies:
   ```bash
   git clone https://github.com/elstonyth/Wheel-of-Name---Offline.git
   cd Wheel-of-Name---Offline
   npm install
   ```

2. Run the server:
   ```bash
   # Windows
   start-wheel-server.bat
   
   # Or manually
   node clone.js serve
   ```

3. Open your browser to the displayed URL (default: `https://wheel.local`)

### Portable Mode (No Installation Required)

1. Run the portable setup (one-time):
   ```bash
   setup-portable.bat
   ```
   This downloads Node.js v20.18.0 (~30MB) and sets up everything.

2. Start the server:
   ```bash
   start-portable.bat
   ```

3. Copy the entire folder to any Windows PC and run without installation!

## Remote Control

After starting the server:

1. **Scan QR Code** - A QR code is displayed in the console
2. **Or type URL** - Use the Remote URL shown
3. **Control from phone** - Select winners, search names, see confirmation

### Remote Features

- 📱 Mobile-friendly interface
- 🔍 Real-time search
- ✅ Winner confirmation
- 🔄 Auto-clear after spin
- 🎯 Cancel selection option
- 📳 Haptic feedback

## Cheat Mode

When viewing the wheel:

- **Ctrl+Shift+X** - Open cheat panel
- **5 clicks in bottom-left** - Alternative trigger
- **Select winner** - Force next spin result

## URLs

| Device | URL |
|--------|-----|
| **Main Display** | `https://wheel.local` |
| **HTTP Access** | `http://wheel.local` |
| **Remote Control** | `http://[YOUR_IP]:8080/remote` |

## Requirements

- Windows 10/11
- Administrator privileges (for hosts file modification)
- Node.js 18+ (for regular mode)
- OR use Portable Mode (no Node.js required)

## Troubleshooting

### Port Already in Use
The script automatically finds available ports (8080-8100).

### Certificate Warnings
The first run may show browser warnings for the self-signed SSL certificate. Click "Proceed anyway" or run as administrator to trust automatically.

### Remote Not Connecting
- Check firewall settings
- Ensure devices are on the same network
- Use the IP address shown in the console

## Development

```bash
npm run serve    # Start server
npm run clone    # Re-clone site
npm run test     # Test mode
```

## License

MIT
