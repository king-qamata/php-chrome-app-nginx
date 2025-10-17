<?php
require __DIR__ . '/vendor/autoload.php';

use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;

// Use the shared volume path for Chrome profiles
$userDataDir = '/tmp/chrome-profiles/profile-' . uniqid();

$options = new ChromeOptions();
$options->addArguments([
    '--headless=new',  // New headless mode in newer Chrome versions
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--disable-software-rasterizer',
    '--remote-debugging-port=0',
    '--user-data-dir=' . $userDataDir,
    '--disable-blink-features=AutomationControlled',
    '--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
]);

$capabilities = DesiredCapabilities::chrome();
$capabilities->setCapability(ChromeOptions::CAPABILITY, $options);

try {
    // Connect to the ChromeDriver service managed by supervisor
    $driver = RemoteWebDriver::create('http://localhost:9515', $capabilities, 15000, 15000);
    
    $driver->get('https://example.com');
    echo "Title: " . $driver->getTitle() . "\n";
    
    $driver->quit();
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    
    // Clean up on error
    if (isset($driver)) {
        try {
            $driver->quit();
        } catch (Exception $quitException) {
            // Ignore quit errors
        }
    }
} finally {
    // Always clean up the user data directory
    if (isset($userDataDir)) {
        exec("rm -rf " . escapeshellarg($userDataDir) . " 2>/dev/null");
    }
}