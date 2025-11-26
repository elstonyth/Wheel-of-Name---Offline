# 🎡 Wheel of Names - Offline Server

Run [Wheel of Names](https://wheelofnames.com) completely offline with network-wide access, custom domains, and remote control from mobile devices.

## ✨ Features

- **100% Offline** - No internet required after initial setup
- **Zero Manual Setup** - Auto-downloads Node.js and Caddy if missing
- **Custom Domains** - Use `wheel.locally` or any custom hostname
- **Network Access** - Access from any device on your LAN
- **Mobile Remote Control** - Control the wheel from your phone via `/remote`
- **HTTPS Support** - Automatic TLS certificates via Caddy
- **Cheat Mode** - Pre-select winners with `Ctrl+Shift+X`
- **QR Codes** - Easy mobile access with scannable QR codes

---

## 🚀 Quick Start

### Windows
```cmd
start-wheel-server.bat
```

That's it! The script will:
1. Download Node.js (if not installed)
2. Download Caddy (if not installed)
3. Install dependencies
4. Start the server
5. Open your browser

---

## 📱 Mobile Access

### Option A: Direct IP (Works Immediately)

After starting the server, use the **LAN IP** shown on screen:

| Device | URL |
|--------|-----|
| **Main Display** | `http://YOUR_LAN_IP:8080` |
| **Remote Control** | `http://YOUR_LAN_IP:8080/remote` |

### Option B: Custom URL on Mobile

The DNS server starts automatically! To use `http://wheel.locally` on your phone:

#### 📱 iPhone / iPad (iOS)
1. Open **Settings** → **Wi-Fi**
2. Tap the **(i)** icon next to your WiFi network
3. Scroll down to **Configure DNS** → tap **Manual**
4. Delete existing servers, tap **Add Server**
5. Enter your PC's IP (shown on server screen, e.g., `192.168.1.100`)
6. Tap **Save**
7. Open Safari → go to `http://wheel.locally`

#### 🤖 Android
1. Open **Settings** → **Wi-Fi**
2. Long-press your WiFi network → **Modify network**
3. Tap **Advanced options**
4. Change **IP settings** to **Static**
5. In **DNS 1**, enter your PC's IP (e.g., `192.168.1.100`)
6. Leave **DNS 2** as `8.8.8.8` (Google backup)
7. Tap **Save**
8. Open Chrome → go to `http://wheel.locally`

> ⚠️ **Important: Reset DNS When Done!**
> 
> When the server is **OFF**, your phone won't load websites if DNS is still pointing to your PC.
> 
> **To reset:** Change DNS back to **Automatic** (iOS) or **DHCP** (Android) after use.

### Option C: QR Codes

Press `S` in the server console to display QR codes. Scan with your phone's camera for instant access.

---

## 🎮 Two-Device Setup (Recommended)

Perfect for presentations and events:

| Device | Role | URL |
|--------|------|-----|
| **TV/Projector** | Main wheel display | `http://LAN_IP:8080` |
| **Phone/Tablet** | Remote control | `http://LAN_IP:8080/remote` |

### How It Works
1. Display the main wheel on a big screen
2. Control spins from your phone
3. Audience sees results in real-time

---

## 🔧 Server Modes

| Command | Description |
|---------|-------------|
| `start-wheel-server.bat` | Normal mode with prompts |
| `start-wheel-server.bat quick` | Skip prompts, use saved config |
| `start-wheel-server.bat dns` | Start DNS server for custom domains |
| `start-wheel-server.bat tray` | Run in system tray |
| `start-wheel-server.bat silent` | Background mode with auto-recovery |
| `start-wheel-server.bat test` | Run automated tests |
| `start-wheel-server.bat --help` | Show all options |

---

## ⌨️ Keyboard Shortcuts

### In Browser
| Key | Action |
|-----|--------|
| `Ctrl+Shift+X` | Open cheat mode panel |
| `Space` | Spin the wheel |

### In Server Console
| Key | Action |
|-----|--------|
| `Q` | Quit server |
| `R` | Refresh display |
| `S` | Show QR codes |
| `N` | Network diagnostics |
| `U` | Check for updates |

---

## 🎯 Cheat Mode

Pre-select a winner before spinning:

1. Press `Ctrl+Shift+X` to open the cheat panel
2. Select the desired winner
3. Spin the wheel - it will land on your selection
4. Panel auto-hides after use

---

## 📁 Project Structure

```
Wheel-of-Name---Offline/
├── start-wheel-server.bat    # Main launcher
├── clone.js                  # Server & cloner
├── cloned-site-offline/      # Offline website files
├── scripts/
│   ├── injectables/          # Wheel modifications
│   │   ├── won-spin.js       # Cheat mode logic
│   │   └── won-expose-engine.js
│   ├── dns-server.js         # Custom DNS server
│   ├── qr-display.js         # QR code generator
│   ├── network-diagnostics.js
│   └── update-check.js
└── setup-client.bat          # Client hosts file setup
```

---

## 🛠️ Troubleshooting

### Can't access from mobile?
1. Ensure both devices are on the same WiFi network
2. Check Windows Firewall allows the connection
3. Use the direct IP address, not the custom hostname
4. Run `start-wheel-server.bat network` for diagnostics

### Custom domain not working?
- On the server PC: Works automatically via hosts file
- On other devices: Use direct IP or DNS server mode

### Port already in use?
The server will automatically find an available port if 8080 is busy.

### Phone can't browse internet after using custom URL?
You probably forgot to reset DNS settings after the server was stopped.

**iPhone/iPad:** Settings → Wi-Fi → (i) → Configure DNS → **Automatic**

**Android:** Settings → Wi-Fi → Long-press network → Modify → IP settings → **DHCP**

---

## 📋 Requirements

- **Windows 10/11** (for batch script)
- **Network connection** (for LAN access)
- Node.js and Caddy are **auto-downloaded** if missing

---

## 📄 License

This is an offline wrapper for [Wheel of Names](https://wheelofnames.com). 
Please respect the original site's terms of service.
