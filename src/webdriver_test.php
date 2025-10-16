<?php
require __DIR__ . '/vendor/autoload.php';

use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Chrome\ChromeDriver;
use Facebook\WebDriver\Remote\DesiredCapabilities;

$options = new ChromeOptions();
$options->addArguments(['--headless', '--no-sandbox', '--disable-dev-shm-usage']);

$capabilities = DesiredCapabilities::chrome();
$capabilities->setCapability(ChromeOptions::CAPABILITY, $options);

$driver = ChromeDriver::start($capabilities);
$driver->get('https://example.com');

echo "Title: " . $driver->getTitle() . "\n";
$driver->quit();
