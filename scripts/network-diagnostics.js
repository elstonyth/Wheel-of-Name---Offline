/**
 * Network Diagnostics for Wheel of Names
 * Troubleshoots connectivity issues
 */

const os = require('os');
const net = require('net');
const dns = require('dns');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Colors for console
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    cyan: '\x1b[36m',
    white: '\x1b[37m'
};

function log(msg, color = 'white') {
    console.log(`${colors[color]}${msg}${colors.reset}`);
}

function success(msg) { log(`  ✓ ${msg}`, 'green'); }
function fail(msg) { log(`  ✗ ${msg}`, 'red'); }
function warn(msg) { log(`  ⚠ ${msg}`, 'yellow'); }
function info(msg) { log(`  ${msg}`, 'white'); }
function header(msg) { log(msg, 'cyan'); }

// Get all network interfaces
function getNetworkInterfaces() {
    const interfaces = os.networkInterfaces();
    const results = [];
    
    for (const [name, addrs] of Object.entries(interfaces)) {
        for (const addr of addrs) {
            if (addr.family === 'IPv4' && !addr.internal) {
                results.push({
                    name,
                    address: addr.address,
                    netmask: addr.netmask,
                    mac: addr.mac
                });
            }
        }
    }
    return results;
}

// Check if port is in use
function checkPort(port, host = '127.0.0.1') {
    return new Promise((resolve) => {
        const client = new net.Socket();
        client.setTimeout(2000);
        
        client.on('connect', () => {
            client.destroy();
            resolve({ port, host, inUse: true });
        });
        
        client.on('timeout', () => {
            client.destroy();
            resolve({ port, host, inUse: false });
        });
        
        client.on('error', () => {
            client.destroy();
            resolve({ port, host, inUse: false });
        });
        
        client.connect(port, host);
    });
}

// Check DNS resolution
function checkDNS(hostname) {
    return new Promise((resolve) => {
        dns.lookup(hostname, (err, address) => {
            if (err) {
                resolve({ hostname, resolved: false, error: err.code });
            } else {
                resolve({ hostname, resolved: true, address });
            }
        });
    });
}

// Check hosts file
function checkHostsFile(hostname) {
    const hostsPath = process.platform === 'win32' 
        ? 'C:\\Windows\\System32\\drivers\\etc\\hosts'
        : '/etc/hosts';
    
    try {
        const content = fs.readFileSync(hostsPath, 'utf8');
        const lines = content.split('\n');
        
        for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed && !trimmed.startsWith('#')) {
                if (trimmed.includes(hostname)) {
                    const parts = trimmed.split(/\s+/);
                    return { found: true, ip: parts[0], line: trimmed };
                }
            }
        }
        return { found: false };
    } catch (err) {
        return { found: false, error: err.message };
    }
}

// Check Windows Firewall
function checkFirewall() {
    return new Promise((resolve) => {
        if (process.platform !== 'win32') {
            resolve({ supported: false });
            return;
        }
        
        exec('netsh advfirewall firewall show rule name="Wheel of Names Server"', (err, stdout) => {
            if (err || !stdout.includes('Wheel of Names Server')) {
                resolve({ ruleExists: false });
            } else {
                resolve({ ruleExists: true, details: stdout });
            }
        });
    });
}

// Test connectivity to a host
function testConnectivity(host, port) {
    return new Promise((resolve) => {
        const start = Date.now();
        const client = new net.Socket();
        client.setTimeout(5000);
        
        client.on('connect', () => {
            const latency = Date.now() - start;
            client.destroy();
            resolve({ host, port, reachable: true, latency });
        });
        
        client.on('timeout', () => {
            client.destroy();
            resolve({ host, port, reachable: false, error: 'timeout' });
        });
        
        client.on('error', (err) => {
            client.destroy();
            resolve({ host, port, reachable: false, error: err.code });
        });
        
        client.connect(port, host);
    });
}

// Main diagnostics
async function runDiagnostics(options = {}) {
    const hostname = options.hostname || process.env.CUSTOM_HOST || 'wheel.local';
    const port = parseInt(options.port || process.env.PORT || 8080);
    
    console.log('');
    header('  ╔══════════════════════════════════════════════════════╗');
    header('  ║         🔍 NETWORK DIAGNOSTICS                       ║');
    header('  ╚══════════════════════════════════════════════════════╝');
    console.log('');
    
    const results = {
        passed: 0,
        failed: 0,
        warnings: 0,
        issues: []
    };
    
    // 1. Network Interfaces
    header('  ─────────────────────────────────────────────────────────');
    header('  [1/7] NETWORK INTERFACES');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    const interfaces = getNetworkInterfaces();
    if (interfaces.length === 0) {
        fail('No active network interfaces found');
        results.failed++;
        results.issues.push('No network connection');
    } else {
        for (const iface of interfaces) {
            success(`${iface.name}: ${iface.address}`);
            info(`     Netmask: ${iface.netmask}`);
        }
        results.passed++;
    }
    console.log('');
    
    // 2. Port Availability
    header('  ─────────────────────────────────────────────────────────');
    header('  [2/7] PORT STATUS');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    const portsToCheck = [port, 80, 443];
    for (const p of portsToCheck) {
        const status = await checkPort(p);
        if (status.inUse) {
            if (p === port) {
                success(`Port ${p}: In use (server running)`);
                results.passed++;
            } else {
                warn(`Port ${p}: In use`);
                results.warnings++;
            }
        } else {
            if (p === port) {
                warn(`Port ${p}: Available (server not running?)`);
                results.warnings++;
            } else {
                info(`Port ${p}: Available`);
            }
        }
    }
    console.log('');
    
    // 3. Hosts File
    header('  ─────────────────────────────────────────────────────────');
    header('  [3/7] HOSTS FILE');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    const hostsCheck = checkHostsFile(hostname);
    if (hostsCheck.found) {
        success(`Entry found: ${hostsCheck.line}`);
        results.passed++;
    } else if (hostsCheck.error) {
        fail(`Cannot read hosts file: ${hostsCheck.error}`);
        results.failed++;
        results.issues.push('Cannot read hosts file - run as administrator');
    } else {
        warn(`No entry for "${hostname}" in hosts file`);
        info(`     Add: 127.0.0.1 ${hostname}`);
        results.warnings++;
    }
    console.log('');
    
    // 4. DNS Resolution
    header('  ─────────────────────────────────────────────────────────');
    header('  [4/7] DNS RESOLUTION');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    const dnsCheck = await checkDNS(hostname);
    if (dnsCheck.resolved) {
        success(`${hostname} → ${dnsCheck.address}`);
        results.passed++;
    } else {
        fail(`Cannot resolve "${hostname}": ${dnsCheck.error}`);
        results.failed++;
        results.issues.push(`DNS resolution failed for ${hostname}`);
    }
    
    // Also check external DNS
    const googleDns = await checkDNS('google.com');
    if (googleDns.resolved) {
        success('External DNS working (google.com)');
    } else {
        warn('External DNS not working');
        results.warnings++;
    }
    console.log('');
    
    // 5. Firewall Status
    header('  ─────────────────────────────────────────────────────────');
    header('  [5/7] FIREWALL STATUS');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    const fwCheck = await checkFirewall();
    if (fwCheck.ruleExists) {
        success('Firewall rule "Wheel of Names Server" exists');
        results.passed++;
    } else if (fwCheck.supported === false) {
        info('Firewall check not supported on this platform');
    } else {
        warn('No firewall rule found');
        info('     Other devices may not be able to connect');
        results.warnings++;
        results.issues.push('Firewall rule not configured');
    }
    console.log('');
    
    // 6. Local Connectivity
    header('  ─────────────────────────────────────────────────────────');
    header('  [6/7] LOCAL CONNECTIVITY');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    const localTest = await testConnectivity('127.0.0.1', port);
    if (localTest.reachable) {
        success(`localhost:${port} reachable (${localTest.latency}ms)`);
        results.passed++;
    } else {
        fail(`localhost:${port} not reachable: ${localTest.error}`);
        results.failed++;
        results.issues.push('Server not responding on localhost');
    }
    
    // Test hostname
    if (dnsCheck.resolved) {
        const hostnameTest = await testConnectivity(dnsCheck.address, port);
        if (hostnameTest.reachable) {
            success(`${hostname}:${port} reachable (${hostnameTest.latency}ms)`);
            results.passed++;
        } else {
            fail(`${hostname}:${port} not reachable`);
            results.failed++;
        }
    }
    console.log('');
    
    // 7. LAN Accessibility
    header('  ─────────────────────────────────────────────────────────');
    header('  [7/7] LAN ACCESSIBILITY');
    header('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    if (interfaces.length > 0) {
        const lanIP = interfaces[0].address;
        const lanTest = await testConnectivity(lanIP, port);
        if (lanTest.reachable) {
            success(`LAN ${lanIP}:${port} reachable (${lanTest.latency}ms)`);
            info(`     Other devices can connect to: http://${lanIP}:${port}`);
            results.passed++;
        } else {
            fail(`LAN ${lanIP}:${port} not reachable: ${lanTest.error}`);
            info('     Other devices may not be able to connect');
            results.failed++;
            results.issues.push('Server not accessible from LAN IP');
        }
    }
    console.log('');
    
    // Summary
    header('  ═══════════════════════════════════════════════════════════');
    header('   SUMMARY');
    header('  ═══════════════════════════════════════════════════════════');
    console.log('');
    
    success(`Passed: ${results.passed}`);
    if (results.warnings > 0) warn(`Warnings: ${results.warnings}`);
    if (results.failed > 0) fail(`Failed: ${results.failed}`);
    console.log('');
    
    if (results.issues.length > 0) {
        header('  Issues to fix:');
        for (const issue of results.issues) {
            info(`    • ${issue}`);
        }
        console.log('');
    }
    
    if (results.failed === 0) {
        success('Network configuration looks good!');
    } else {
        warn('Some issues detected. Review the items above.');
    }
    console.log('');
    
    return results;
}

// CLI
if (require.main === module) {
    const args = process.argv.slice(2);
    const options = {};
    
    args.forEach(arg => {
        if (arg.startsWith('--port=')) options.port = arg.split('=')[1];
        if (arg.startsWith('--hostname=')) options.hostname = arg.split('=')[1];
    });
    
    runDiagnostics(options).then(results => {
        process.exit(results.failed > 0 ? 1 : 0);
    });
}

module.exports = { runDiagnostics, getNetworkInterfaces, checkPort, checkDNS };
