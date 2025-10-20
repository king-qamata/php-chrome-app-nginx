<?php
// diagnostic.php - Comprehensive diagnostic script

echo "<pre>";
echo "=== Chrome & ChromeDriver Diagnostic ===\n\n";

// 1. Check Chrome
echo "1. Google Chrome:\n";
$chromePath = shell_exec("which google-chrome");
if ($chromePath) {
    echo "   ✓ Found: " . trim($chromePath) . "\n";
    $chromeVersion = shell_exec("google-chrome --version");
    echo "   Version: " . ($chromeVersion ? trim($chromeVersion) : "Unknown") . "\n";
} else {
    echo "   ❌ NOT FOUND\n";
}

// 2. Check ChromeDriver
echo "\n2. ChromeDriver:\n";
$driverPath = shell_exec("which chromedriver");
if ($driverPath) {
    echo "   ✓ Found: " . trim($driverPath) . "\n";
    $driverVersion = shell_exec("chromedriver --version");
    echo "   Version: " . ($driverVersion ? trim($driverVersion) : "Unknown") . "\n";
} else {
    echo "   ❌ NOT FOUND\n";
}

// 3. Check processes
echo "\n3. Running Processes:\n";
$processes = shell_exec("ps aux | grep -E '(chrome|chromedriver)' | grep -v grep");
if ($processes) {
    echo "   Running processes:\n";
    echo $processes;
} else {
    echo "   ❌ No Chrome/ChromeDriver processes found\n";
}

// 4. Check network ports
echo "\n4. Network Ports:\n";
$ports = shell_exec("netstat -tuln 2>/dev/null | grep :9515 || ss -tuln 2>/dev/null | grep :9515");
if ($ports) {
    echo "   Port 9515 is listening:\n";
    echo $ports;
} else {
    echo "   ❌ Port 9515 is NOT listening\n";
}

// 5. Check HTTP endpoint
echo "\n5. ChromeDriver HTTP Status:\n";
$ch = curl_init('http://localhost:9515/status');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 5);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    echo "   ✓ HTTP 200 OK\n";
    if ($response) {
        $data = json_decode($response, true);
        echo "   Response: " . json_encode($data, JSON_PRETTY_PRINT) . "\n";
    }
} else {
    echo "   ❌ HTTP Error: $httpCode\n";
    if ($response) {
        echo "   Response: $response\n";
    }
}

// 6. Check log files
echo "\n6. Log Files:\n";
$logs = [
    '/home/LogFiles/chromedriver.log',
    '/home/LogFiles/chromedriver-stdout.log',
    '/home/LogFiles/xvfb.log'
];

foreach ($logs as $log) {
    if (file_exists($log)) {
        $size = filesize($log);
        $lines = shell_exec("wc -l " . escapeshellarg($log) . " 2>/dev/null");
        echo "   $log: " . ($size > 0 ? "$size bytes" : "empty") . 
             ($lines ? " ($lines lines)" : "") . "\n";
        
        // Show last 5 lines if file has content
        if ($size > 0) {
            $lastLines = shell_exec("tail -5 " . escapeshellarg($log) . " 2>/dev/null");
            echo "   Last 5 lines:\n";
            echo "   " . str_replace("\n", "\n   ", $lastLines) . "\n";
        }
    } else {
        echo "   $log: ❌ File not found\n";
    }
}

echo "\n=== Diagnostic Complete ===\n";
echo "</pre>";