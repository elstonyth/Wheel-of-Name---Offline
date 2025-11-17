# Wheel of Names Offline – Work Log (Nov 17, 2025)

## Completed
- Rebuilt `start-wheel-server.bat` into a production-ready launcher: dependency checks, automatic host entry management, PID tracking, log files per run, graceful shutdown, and guards that stop lingering Node/Caddy instances before relaunching.
- Added health checks so the script waits for Node and Caddy ports, bails on early failures, and prints actionable log locations.
- Extended the offline Node server (`clone.js`) to return the `spinsPerSecond` field in `/api/v2/client-settings` and to treat hashed preload assets as empty scripts, eliminating console errors.
- Updated the `Caddyfile` and launcher defaults to non-privileged ports (HTTP 8081, HTTPS 8443) so we can run without Administrator access while keeping TLS via Caddy’s internal CA.

## Outstanding Issues
- Caddy still refuses to become “ready” even though the launcher spawns it (PID logged). We suspect the actual server process exits immediately when binding to ports 8081/8443, but because the process is launched through `cmd.exe`, stdout/stderr never hit the `caddy-*.log` files and the readiness probe spins forever.
- Need a clean Caddy log to confirm whether the port is occupied or if Caddy is crashing for another reason.

## Next Steps (Tomorrow)
1. Manually run `caddy.exe run --config Caddyfile` in an elevated PowerShell to capture the precise bind error for ports 8081/8443; free or adjust ports based on that output.
2. Once manual Caddy works, revert to the launcher and confirm readiness succeeds; if necessary, redirect Caddy’s stdout/stderr directly to the log (e.g., `--observe-config --log file`) instead of using the current `cmd.exe` wrapper.
3. When both services report ready, verify `https://wheelofnames.local:8443/` loads without certificate warnings, then document the final launch instructions.
