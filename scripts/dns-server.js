/**
 * Lightweight DNS Server for Wheel of Names
 * Resolves the custom hostname to the server's LAN IP
 * Other devices can point their DNS to this server to use the custom URL
 */

const dns2 = require('dns2');
const { Packet } = dns2;
const os = require('os');
const path = require('path');
const fs = require('fs');

// Configuration
const DNS_PORT = parseInt(process.env.DNS_PORT) || 53;
const HOSTNAME = process.env.CUSTOM_HOST || 'wheel.local';
const SERVER_IP = process.env.SERVER_IP || getLocalIP();

// Upstream DNS for queries we don't handle
const UPSTREAM_DNS = '8.8.8.8';

function getLocalIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return '127.0.0.1';
}

// Create DNS server
const server = dns2.createServer({
    udp: true,
    tcp: true,
    handle: async (request, send, rinfo) => {
        const response = Packet.createResponseFromRequest(request);
        const [question] = request.questions;
        const { name, type } = question;
        
        console.log(`[DNS] Query: ${name} (Type: ${type}) from ${rinfo.address}`);
        
        // Check if this is our custom hostname
        const normalizedName = name.toLowerCase().replace(/\.$/, '');
        const normalizedHostname = HOSTNAME.toLowerCase();
        
        if (normalizedName === normalizedHostname || normalizedName.endsWith('.' + normalizedHostname)) {
            if (type === Packet.TYPE.A) {
                console.log(`[DNS] Resolved ${name} -> ${SERVER_IP}`);
                response.answers.push({
                    name,
                    type: Packet.TYPE.A,
                    class: Packet.CLASS.IN,
                    ttl: 300,
                    address: SERVER_IP
                });
            }
        } else {
            // Forward to upstream DNS
            try {
                const resolver = new dns2({ dns: UPSTREAM_DNS });
                const result = await resolver.resolve(name, type === Packet.TYPE.A ? 'A' : 'AAAA');
                if (result.answers) {
                    response.answers = result.answers;
                }
            } catch (err) {
                console.log(`[DNS] Upstream lookup failed for ${name}: ${err.message}`);
            }
        }
        
        send(response);
    }
});

server.on('listening', () => {
    console.log('');
    console.log('  ╔══════════════════════════════════════════════════════╗');
    console.log('  ║         🌐 WHEEL OF NAMES - DNS SERVER 🌐            ║');
    console.log('  ╚══════════════════════════════════════════════════════╝');
    console.log('');
    console.log(`  ✓ DNS Server listening on port ${DNS_PORT}`);
    console.log(`  ✓ Resolving: ${HOSTNAME} -> ${SERVER_IP}`);
    console.log('');
    console.log('  ─────────────────────────────────────────────────────────');
    console.log('  📱 TO USE ON OTHER DEVICES:');
    console.log('  ─────────────────────────────────────────────────────────');
    console.log('');
    console.log(`    1. Go to your device's WiFi/Network settings`);
    console.log(`    2. Change DNS server to: ${SERVER_IP}`);
    console.log(`    3. Open browser and go to: https://${HOSTNAME}`);
    console.log('');
    console.log('  ─────────────────────────────────────────────────────────');
    console.log('');
});

server.on('error', (err) => {
    if (err.code === 'EACCES') {
        console.error('');
        console.error('  ❌ ERROR: Cannot bind to port 53');
        console.error('     DNS requires Administrator/root privileges');
        console.error('');
        console.error('  Solutions:');
        console.error('    1. Run as Administrator');
        console.error('    2. Or use --dns-port=5353 (then configure devices to use that port)');
        console.error('');
    } else if (err.code === 'EADDRINUSE') {
        console.error('');
        console.error('  ❌ ERROR: Port 53 is already in use');
        console.error('     Another DNS server may be running');
        console.error('');
    } else {
        console.error('DNS Server error:', err);
    }
    process.exit(1);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n  Shutting down DNS server...');
    server.close();
    process.exit(0);
});

process.on('SIGTERM', () => {
    server.close();
    process.exit(0);
});

// Start server
server.listen({ udp: DNS_PORT, tcp: DNS_PORT });

// Export for potential programmatic use
module.exports = { server, getLocalIP };
