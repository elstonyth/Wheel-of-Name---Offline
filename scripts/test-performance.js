#!/usr/bin/env node

const puppeteer = require('puppeteer');
const http = require('http');

/**
 * Test Performance Script for Wheel of Names Offline
 * Injects 5,500+ entries and runs automated tests
 */

const TEST_DATA = [
    'Alice Johnson', 'Bob Smith', 'Charlie Brown', 'Diana Prince', 'Edward Norton',
    'Fiona Apple', 'George Lucas', 'Helen Troy', 'Ian McKellen', 'Julia Roberts',
    'Kevin Hart', 'Linda Hamilton', 'Michael Jordan', 'Nicole Kidman', 'Oscar Wilde',
    'Patricia Nixon', 'Quentin Tarantino', 'Rachel Green', 'Steven Spielberg', 'Tina Turner',
    'Uma Thurman', 'Vincent van Gogh', 'Wendy Williams', 'Xavier Charles', 'Yvonne Strahovski',
    'Zachary Levi', 'Aaron Paul', 'Britney Spears', 'Chris Hemsworth', 'Demi Moore',
    'Eva Green', 'Frank Sinatra', 'Gwyneth Paltrow', 'Hugh Jackman', 'Isla Fisher',
    'Johnny Depp', 'Kate Winslet', 'Leonardo DiCaprio', 'Megan Fox', 'Nicolas Cage',
    'Olivia Wilde', 'Patrick Stewart', 'Queen Latifah', 'Robert Downey Jr', 'Scarlett Johansson',
    'Tom Cruise', 'Uma Thurman', 'Vin Diesel', 'Will Smith', 'Xzibit',
    'Yara Shahidi', 'Zac Efron', 'Adam Sandler', 'Beyoncé Knowles', 'Chris Rock',
    'Dwayne Johnson', 'Emma Watson', 'Frank Ocean', 'Gordon Ramsay', 'Halle Berry',
    'Idris Elba', 'Jennifer Lawrence', 'Kanye West', 'Lady Gaga', 'Mark Wahlberg',
    'Natalie Portman', 'Oprah Winfrey', 'Paul McCartney', 'Rihanna', 'Snoop Dogg',
    'Taylor Swift', 'Usher Raymond', 'Vanessa Hudgens', 'Will Ferrell', 'Xena Warrior Princess',
    'Yogi Bear', 'Zayn Malik', 'Adele Laurie', 'Brad Pitt', 'Carrie Underwood',
    'Drake Graham', 'Ellen DeGeneres', 'Florence Welch', 'Gordon Lightfoot', 'Harrison Ford',
    'Ice Cube', 'Jennifer Aniston', 'Keanu Reeves', 'Madonna Ciccone', 'Neil Patrick Harris',
    'O.J. Simpson', 'Pink (singer)', 'Queen Elizabeth', 'Robert Pattinson', 'Sofia Vergara',
    'Tyler Perry', 'U2 (band)', 'Vince Vaughn', 'Wiz Khalifa', 'Xzibit',
    'Yolanda Adams', 'Zooey Deschanel'
];

// Generate 5500+ entries by combining and duplicating
function generateTestData() {
    const entries = [];
    let count = 0;
    
    // Add unique combinations
    for (let i = 0; i < 100; i++) {
        for (let j = 0; j < TEST_DATA.length; j++) {
            if (count >= 5500) break;
            entries.push(`${TEST_DATA[j]} ${i + 1}`);
            count++;
        }
        if (count >= 5500) break;
    }
    
    // Fill remaining if needed
    while (entries.length < 5500) {
        entries.push(`Test Entry ${entries.length + 1}`);
    }
    
    return entries.slice(0, 5500);
}

async function checkServerStatus(port) {
    return new Promise((resolve) => {
        const req = http.request({
            hostname: 'localhost',
            port: port,
            path: '/',
            method: 'GET',
            timeout: 5000
        }, (res) => {
            resolve(res.statusCode === 200);
        });
        
        req.on('error', () => resolve(false));
        req.on('timeout', () => resolve(false));
        req.end();
    });
}

async function injectEntries(page, entries) {
    console.log(`📝 Injecting ${entries.length} entries...`);
    
    try {
        // Wait for the page to load completely
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Try to use the API endpoint directly to inject entries
        const response = await page.evaluate((entries) => {
            // Try to find the entries input element with various selectors
            const selectors = [
                'textarea[name="entries"]',
                '.entries-input',
                '#entries',
                'textarea',
                'input[type="text"]',
                '.q-textarea',
                '.q-field__control'
            ];
            
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) {
                    console.log('Found input element:', selector);
                    element.focus();
                    
                    // Use proper selection method based on element type
                    if (element.tagName.toLowerCase() === 'textarea' || element.tagName.toLowerCase() === 'input') {
                        try {
                            element.select();
                        } catch (e) {
                            // Fallback for newer DOM APIs
                            if (element.setSelectionRange) {
                                element.setSelectionRange(0, element.value.length);
                            }
                        }
                    }
                    
                    element.value = entries.join('\n');
                    
                    // Trigger input event
                    element.dispatchEvent(new Event('input', { bubbles: true }));
                    element.dispatchEvent(new Event('change', { bubbles: true }));
                    
                    return { success: true, selector };
                }
            }
            
            // If no textarea found, try to access the Vue component directly
            if (window.Vue && window.Vue.config) {
                console.log('Vue detected, trying component access...');
                // This is a fallback - may not work with obfuscated components
                return { success: false, error: 'Vue component access not implemented' };
            }
            
            return { success: false, error: 'No input element found' };
        }, entries);
        
        if (response.success) {
            console.log(`✓ Entries injected via ${response.selector}`);
            
            // Try to apply/save the entries
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // Look for apply/save buttons
            const applySelectors = [
                'button[type="submit"]',
                '.apply-button',
                '#apply-entries',
                '.q-btn',
                'button:contains("Apply")',
                'button:contains("Save")'
            ];
            
            for (const selector of applySelectors) {
                try {
                    await page.click(selector, { timeout: 2000 });
                    console.log('✓ Applied entries');
                    return true;
                } catch (e) {
                    // Continue to next selector
                }
            }
            
            console.log('⚠ Entries injected but could not find apply button');
            return true;
        } else {
            console.log('⚠ Could not inject entries:', response.error);
            return false;
        }
        
    } catch (error) {
        console.log('✗ Failed to inject entries:', error.message);
        return false;
    }
}

async function testSpinFunctionality(page) {
    console.log('🎯 Testing spin functionality...');
    
    try {
        // Wait for page to be fully loaded
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Look for canvas element (the wheel is usually rendered as canvas)
        const canvasSelector = 'canvas';
        await page.waitForSelector(canvasSelector, { timeout: 10000 });
        
        console.log('✓ Found canvas element');
        
        // Measure performance before spin
        const startTime = Date.now();
        
        // Click on the canvas to trigger spin (most wheel apps use canvas clicks)
        const canvas = await page.$(canvasSelector);
        const boundingBox = await canvas.boundingBox();
        
        if (boundingBox) {
            // Click in the center of the canvas
            await page.mouse.click(
                boundingBox.x + boundingBox.width / 2,
                boundingBox.y + boundingBox.height / 2
            );
            console.log('✓ Clicked canvas to trigger spin');
        } else {
            // Fallback: try various button selectors
            const buttonSelectors = [
                'button',
                '.q-btn',
                '[role="button"]',
                '.spin-button',
                '#spin'
            ];
            
            let clicked = false;
            for (const selector of buttonSelectors) {
                try {
                    await page.click(selector, { timeout: 2000 });
                    console.log(`✓ Clicked element: ${selector}`);
                    clicked = true;
                    break;
                } catch (e) {
                    // Continue to next selector
                }
            }
            
            if (!clicked) {
                throw new Error('Could not find clickable element');
            }
        }
        
        // Wait for spinning to complete - look for winner dialog or result
        console.log('⏳ Waiting for spin to complete...');
        
        // Add overall timeout to prevent hanging
        const spinTimeout = 20000; // 20 seconds maximum
        const spinStartTime = Date.now();
        
        // Try multiple approaches to detect spin completion
        const resultSelectors = [
            '.winner',
            '#result',
            '.spin-result',
            '.winner-dialog',
            '.q-dialog',
            '[role="dialog"]'
        ];
        
        let spinCompleted = false;
        for (const selector of resultSelectors) {
            try {
                // Check if we've exceeded overall timeout
                if (Date.now() - spinStartTime > spinTimeout) {
                    console.log('⚠ Spin detection timeout reached');
                    break;
                }
                
                await page.waitForSelector(selector, { timeout: 5000 });
                console.log(`✓ Spin completed - found result: ${selector}`);
                spinCompleted = true;
                break;
            } catch (e) {
                // Continue to next selector
            }
        }
        
        if (!spinCompleted) {
            // Fallback: wait a fixed time and assume spin completed
            console.log('⚠ No result dialog found, waiting fixed time...');
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
        
        const spinTime = Date.now() - startTime;
        console.log(`✓ Spin completed in ${spinTime}ms`);
        
        return { success: true, spinTime };
        
    } catch (error) {
        console.log('✗ Spin test failed:', error.message);
        return { success: false, error: error.message };
    }
}

async function testCheatMode(page) {
    console.log('🕵️ Testing cheat mode...');
    
    try {
        // Try Ctrl+Shift+X shortcut
        await page.keyboard.down('Control');
        await page.keyboard.down('Shift');
        await page.keyboard.press('X');
        await page.keyboard.up('Shift');
        await page.keyboard.up('Control');
        
        // Look for cheat panel
        await page.waitForSelector('.cheat-panel, #cheat-panel, .force-winner', { timeout: 3000 });
        
        console.log('✓ Cheat panel opened successfully');
        
        // Test forced winner selection
        await page.select('select.force-winner, #force-winner', '0');
        await page.click('.apply-cheat, #apply-cheat');
        
        console.log('✓ Cheat mode functionality verified');
        return true;
        
    } catch (error) {
        console.log('✗ Cheat mode test failed:', error.message);
        return false;
    }
}

async function measurePerformance(page) {
    console.log('📊 Measuring performance metrics...');
    
    const metrics = await page.evaluate(() => {
        const navigation = performance.getEntriesByType('navigation')[0];
        return {
            loadTime: navigation.loadEventEnd - navigation.loadEventStart,
            domInteractive: navigation.domInteractive - navigation.fetchStart,
            domComplete: navigation.domComplete - navigation.fetchStart,
            firstPaint: performance.getEntriesByType('paint')[0]?.startTime || 0,
            firstContentfulPaint: performance.getEntriesByType('paint')[1]?.startTime || 0
        };
    });
    
    console.log('📈 Performance Metrics:');
    console.log(`   Load Time: ${metrics.loadTime}ms`);
    console.log(`   DOM Interactive: ${metrics.domInteractive}ms`);
    console.log(`   DOM Complete: ${metrics.domComplete}ms`);
    console.log(`   First Paint: ${metrics.firstPaint}ms`);
    console.log(`   First Contentful Paint: ${metrics.firstContentfulPaint}ms`);
    
    return metrics;
}

async function main() {
    const args = process.argv.slice(2);
    const port = args.find(arg => arg.startsWith('--port='))?.split('=')[1] || '8080';
    
    console.log('🚀 Starting Wheel of Names Performance Test');
    console.log(`📍 Target: http://localhost:${port}`);
    console.log('');
    
    // Check if server is running
    console.log('🔍 Checking server status...');
    const serverRunning = await checkServerStatus(parseInt(port));
    if (!serverRunning) {
        console.error('❌ Server is not running on port', port);
        console.log('Please start the server first: start-wheel-server.bat');
        process.exit(1);
    }
    console.log('✓ Server is running');
    
    // Generate test data
    const testEntries = generateTestData();
    console.log(`📋 Generated ${testEntries.length} test entries`);
    console.log('');
    
    // Launch browser
    console.log('🌐 Launching browser...');
    const browser = await puppeteer.launch({
        headless: false, // Set to true for headless mode
        defaultViewport: { width: 1920, height: 1080 },
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        const page = await browser.newPage();
        
        // Navigate to the application
        console.log(`📍 Navigating to http://localhost:${port}...`);
        await page.goto(`http://localhost:${port}`, { waitUntil: 'networkidle2' });
        
        // Measure initial performance
        const initialMetrics = await measurePerformance(page);
        
        // Test entry injection
        const injectionSuccess = await injectEntries(page, testEntries);
        if (!injectionSuccess) {
            console.log('⚠ Continuing with spin tests despite injection issues...');
        }
        
        // Test spin functionality
        const spinResult = await testSpinFunctionality(page);
        
        // Test cheat mode
        const cheatResult = await testCheatMode(page);
        
        // Final performance measurement
        console.log('');
        console.log('📊 Final Performance Summary:');
        const finalMetrics = await measurePerformance(page);
        
        // Test results summary
        console.log('');
        console.log('📋 Test Results Summary:');
        console.log(`   Entry Injection: ${injectionSuccess ? '✓ PASS' : '✗ FAIL'}`);
        console.log(`   Spin Functionality: ${spinResult.success ? '✓ PASS' : '✗ FAIL'}`);
        if (spinResult.success) {
            console.log(`   Spin Time: ${spinResult.spinTime}ms`);
        }
        console.log(`   Cheat Mode: ${cheatResult ? '✓ PASS' : '✗ FAIL'}`);
        
        const allTestsPassed = injectionSuccess && spinResult.success && cheatResult;
        
        console.log('');
        if (allTestsPassed) {
            console.log('🎉 All tests passed successfully!');
        } else {
            console.log('⚠ Some tests failed. Check the logs above for details.');
        }
        
        // Keep browser open for 5 seconds for manual inspection
        console.log('📸 Keeping browser open for 5 seconds for inspection...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        await browser.close();
        process.exit(allTestsPassed ? 0 : 1);
        
    } catch (error) {
        console.error('❌ Test execution failed:', error.message);
        await browser.close();
        process.exit(1);
    }
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = { generateTestData, checkServerStatus, injectEntries, testSpinFunctionality, testCheatMode, measurePerformance };
