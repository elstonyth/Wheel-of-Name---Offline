/**
 * QR Code Display for Wheel of Names
 * Generates QR codes for easy mobile access
 */

const qrcode = require('qrcode-terminal');
const os = require('os');

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

function displayQR(options = {}) {
    const hostname = options.hostname || process.env.CUSTOM_HOST || 'wheel.local';
    const port = options.port || process.env.PORT || 8080;
    const localIP = options.ip || getLocalIP();
    
    const urls = {
        main: `https://${hostname}`,
        mainHttp: `http://${hostname}`,
        ip: `https://${localIP}`,
        ipHttp: `http://${localIP}`,
        remote: `http://${localIP}:${port}/remote`
    };

    console.log('');
    console.log('  ┌──────────────────────────────────────────────────────┐');
    console.log('  │  📱 SCAN QR CODE TO ACCESS                           │');
    console.log('  └──────────────────────────────────────────────────────┘');
    console.log('');
    
    // Main URL QR
    console.log(`  Main Display: ${urls.ip}`);
    qrcode.generate(urls.ip, { small: true }, (code) => {
        console.log(code.split('\n').map(line => '  ' + line).join('\n'));
    });
    
    console.log('');
    console.log('  ─────────────────────────────────────────────────────────');
    console.log('');
    
    // Remote Control QR
    console.log(`  📱 Remote Control: ${urls.remote}`);
    qrcode.generate(urls.remote, { small: true }, (code) => {
        console.log(code.split('\n').map(line => '  ' + line).join('\n'));
    });
    
    console.log('');
    
    return urls;
}

// Run if called directly
if (require.main === module) {
    const args = process.argv.slice(2);
    const options = {};
    
    args.forEach(arg => {
        if (arg.startsWith('--port=')) options.port = arg.split('=')[1];
        if (arg.startsWith('--hostname=')) options.hostname = arg.split('=')[1];
        if (arg.startsWith('--ip=')) options.ip = arg.split('=')[1];
    });
    
    displayQR(options);
}

module.exports = { displayQR, getLocalIP };
