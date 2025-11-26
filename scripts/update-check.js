/**
 * Update Checker for Wheel of Names
 * Checks GitHub for new releases
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const REPO_OWNER = 'elstonyth';
const REPO_NAME = 'Wheel-of-Name---Offline';
const GITHUB_API = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;

function getCurrentVersion() {
    try {
        const packagePath = path.join(__dirname, '..', 'package.json');
        const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
        return pkg.version || '1.0.0';
    } catch (err) {
        return '1.0.0';
    }
}

function compareVersions(current, latest) {
    const currentParts = current.replace(/^v/, '').split('.').map(Number);
    const latestParts = latest.replace(/^v/, '').split('.').map(Number);
    
    for (let i = 0; i < 3; i++) {
        const c = currentParts[i] || 0;
        const l = latestParts[i] || 0;
        if (l > c) return 1;  // Update available
        if (c > l) return -1; // Current is newer
    }
    return 0; // Same version
}

function checkForUpdates() {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.github.com',
            path: `/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`,
            headers: {
                'User-Agent': 'Wheel-of-Names-Offline',
                'Accept': 'application/vnd.github.v3+json'
            }
        };

        const req = https.get(options, (res) => {
            let data = '';
            
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode === 200) {
                    try {
                        const release = JSON.parse(data);
                        const currentVersion = getCurrentVersion();
                        const latestVersion = release.tag_name || release.name || '0.0.0';
                        const comparison = compareVersions(currentVersion, latestVersion);
                        
                        resolve({
                            currentVersion,
                            latestVersion,
                            updateAvailable: comparison > 0,
                            releaseUrl: release.html_url,
                            releaseName: release.name,
                            releaseNotes: release.body,
                            publishedAt: release.published_at
                        });
                    } catch (err) {
                        reject(new Error('Failed to parse release info'));
                    }
                } else if (res.statusCode === 404) {
                    // No releases yet
                    resolve({
                        currentVersion: getCurrentVersion(),
                        latestVersion: null,
                        updateAvailable: false,
                        message: 'No releases published yet'
                    });
                } else {
                    reject(new Error(`GitHub API returned ${res.statusCode}`));
                }
            });
        });

        req.on('error', reject);
        req.setTimeout(10000, () => {
            req.destroy();
            reject(new Error('Request timeout'));
        });
    });
}

async function main() {
    console.log('');
    console.log('  ╔══════════════════════════════════════════════════════╗');
    console.log('  ║         🔄 CHECKING FOR UPDATES...                   ║');
    console.log('  ╚══════════════════════════════════════════════════════╝');
    console.log('');

    try {
        const result = await checkForUpdates();
        
        console.log(`  Current version: v${result.currentVersion}`);
        
        if (result.latestVersion === null) {
            console.log('  Latest version:  No releases yet');
            console.log('');
            console.log('  ✓ You have the latest code');
        } else if (result.updateAvailable) {
            console.log(`  Latest version:  ${result.latestVersion}`);
            console.log('');
            console.log('  ┌──────────────────────────────────────────────────────┐');
            console.log('  │  🆕 UPDATE AVAILABLE!                                │');
            console.log('  └──────────────────────────────────────────────────────┘');
            console.log('');
            if (result.releaseName) {
                console.log(`  Release: ${result.releaseName}`);
            }
            if (result.publishedAt) {
                console.log(`  Published: ${new Date(result.publishedAt).toLocaleDateString()}`);
            }
            console.log('');
            console.log('  Download from:');
            console.log(`  ${result.releaseUrl || `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases`}`);
            console.log('');
            if (result.releaseNotes) {
                console.log('  Release Notes:');
                console.log('  ' + result.releaseNotes.split('\n').slice(0, 5).join('\n  '));
                if (result.releaseNotes.split('\n').length > 5) {
                    console.log('  ...(see GitHub for full notes)');
                }
            }
        } else {
            console.log(`  Latest version:  ${result.latestVersion}`);
            console.log('');
            console.log('  ✓ You are running the latest version!');
        }
        
        console.log('');
        return result;
    } catch (err) {
        console.log(`  ✗ Could not check for updates: ${err.message}`);
        console.log('');
        console.log('  This could be due to:');
        console.log('    - No internet connection');
        console.log('    - GitHub API rate limit');
        console.log('    - Firewall blocking the request');
        console.log('');
        return { error: err.message };
    }
}

if (require.main === module) {
    main().then(result => {
        process.exit(result.error ? 1 : 0);
    });
}

module.exports = { checkForUpdates, getCurrentVersion, compareVersions };
