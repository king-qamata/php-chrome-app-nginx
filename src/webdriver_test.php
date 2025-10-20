<?php
require __DIR__ . '/vendor/autoload.php';

use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;

// Use a unique user data directory for each session
$userDataDir = '/tmp/chrome-profiles/profile-' . uniqid();

$options = new ChromeOptions();
$options->addArguments([
    '--headless=new',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--disable-software-rasterizer',
    '--remote-debugging-port=0',
    '--user-data-dir=' . $userDataDir,
    '--disable-blink-features=AutomationControlled'
]);

$capabilities = DesiredCapabilities::chrome();
$capabilities->setCapability(ChromeOptions::CAPABILITY, $options);

try {
    // Connect to the existing ChromeDriver service running on port 9515
    $driver = RemoteWebDriver::create('http://localhost:9515', $capabilities, 30000, 30000);
    
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

