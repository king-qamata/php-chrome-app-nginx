<?php
require __DIR__ . '/vendor/autoload.php';

use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;

function checkChromeDriver() {
    echo "Checking ChromeDriver status...\n";
    
    // Check if process is running
    $processCheck = shell_exec("pgrep -f chromedriver");
    if (empty($processCheck)) {
        echo "❌ ChromeDriver process is not running\n";
        return false;
    }
    echo "✓ ChromeDriver process is running (PID: " . trim($processCheck) . ")\n";
    
    // Check if port is listening
    $portCheck = shell_exec("netstat -tuln 2>/dev/null | grep :9515 || ss -tuln 2>/dev/null | grep :9515");
    if (empty($portCheck)) {
        echo "❌ Port 9515 is not listening\n";
        return false;
    }
    echo "✓ Port 9515 is listening\n";
    
    // Check HTTP endpoint
    $ch = curl_init('http://localhost:9515/status');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode !== 200) {
        echo "❌ ChromeDriver HTTP status endpoint returned code: $httpCode\n";
        return false;
    }
    
    echo "✓ ChromeDriver HTTP endpoint is accessible\n";
    
    if ($response) {
        $data = json_decode($response, true);
        if (isset($data['value']['ready'])) {
            echo "✓ ChromeDriver is ready: " . ($data['value']['ready'] ? 'true' : 'false') . "\n";
        }
    }
    
    return true;
}

// Main execution
echo "Starting Chrome WebDriver test...\n";

// First, check if ChromeDriver is running
if (!checkChromeDriver()) {
    die("ChromeDriver is not properly running. Please check the container logs.\n");
}

// Create unique profile directory
$userDataDir = '/tmp/chrome-profiles/profile-' . uniqid();
if (!is_dir($userDataDir)) {
    mkdir($userDataDir, 0755, true);
}

echo "Using profile directory: $userDataDir\n";

$options = new ChromeOptions();
$options->addArguments([
    '--headless=new',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--disable-software-rasterizer',
    '--remote-debugging-port=0',
    '--user-data-dir=' . $userDataDir,
    '--disable-blink-features=AutomationControlled',
    '--no-first-run',
    '--disable-extensions',
    '--disable-plugins'
]);

$capabilities = DesiredCapabilities::chrome();
$capabilities->setCapability(ChromeOptions::CAPABILITY, $options);

$driver = null;

try {
    echo "Connecting to ChromeDriver...\n";
    
    // Try to connect with retry logic
    $maxRetries = 3;
    $retryCount = 0;
    
    while ($retryCount < $maxRetries) {
        try {
            $driver = RemoteWebDriver::create('http://localhost:9515', $capabilities, 30000, 30000);
            echo "✓ Successfully connected to ChromeDriver\n";
            break;
        } catch (Exception $e) {
            $retryCount++;
            if ($retryCount === $maxRetries) {
                throw $e;
            }
            echo "Connection attempt $retryCount failed, retrying...\n";
            sleep(2);
        }
    }
    
    echo "Navigating to example.com...\n";
    $driver->get('https://example.com');
    
    $title = $driver->getTitle();
    echo "✓ Page title: " . $title . "\n";
    
    echo "Closing browser...\n";
    $driver->quit();
    $driver = null;
    
    echo "✓ Test completed successfully!\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    
    // Additional debug info
    echo "Error type: " . get_class($e) . "\n";
    
    if (strpos($e->getMessage(), 'Failed to connect') !== false) {
        echo "This is a connection error. Checking ChromeDriver status again...\n";
        checkChromeDriver();
        
        // Show recent logs
        echo "Last 10 lines of ChromeDriver log:\n";
        $logLines = shell_exec("tail -10 /home/LogFiles/chromedriver.log 2>/dev/null") ?: "No log file found\n";
        echo $logLines;
    }
    
} finally {
    // Clean up driver
    if ($driver instanceof RemoteWebDriver) {
        try {
            $driver->quit();
        } catch (Exception $e) {
            // Ignore quit errors
        }
    }
    
    // Clean up profile directory
    if (isset($userDataDir) && is_dir($userDataDir)) {
        shell_exec("rm -rf " . escapeshellarg($userDataDir) . " 2>/dev/null");
        echo "Cleaned up profile directory\n";
    }
}