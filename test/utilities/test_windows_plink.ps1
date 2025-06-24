# PowerShell test script for train-juniper Windows support
# Run this as: .\test_windows_plink.ps1

# Load .env file if it exists
if (Test-Path ".env") {
    Write-Host "Loading .env file..." -ForegroundColor Yellow
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove quotes if present
            $value = $value -replace '^["'']|["'']$', ''
            [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
}

Write-Host "=== Train-Juniper Windows Plink Test (PowerShell) ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "Ruby Version: $(ruby -v)"
Write-Host ""

# Test 1: Check for plink.exe
Write-Host "Test 1: Checking for plink.exe..." -ForegroundColor Yellow
$plinkPath = Get-Command plink.exe -ErrorAction SilentlyContinue

if ($plinkPath) {
    Write-Host "✓ plink.exe found at: $($plinkPath.Source)" -ForegroundColor Green
    & plink -V
} else {
    Write-Host "✗ plink.exe not found in PATH" -ForegroundColor Red
    Write-Host "  Please install PuTTY and add it to PATH"
}
Write-Host ""

# Test 2: Check gem installation
Write-Host "Test 2: Checking train-juniper installation..." -ForegroundColor Yellow
$gemList = gem list train-juniper

if ($gemList -match "train-juniper") {
    Write-Host "✓ train-juniper gem is installed" -ForegroundColor Green
    Write-Host "  $gemList"
} else {
    Write-Host "✗ train-juniper gem not found" -ForegroundColor Red
    Write-Host "  Run: gem install train-juniper"
}
Write-Host ""

# Test 3: Quick InSpec test
Write-Host "Test 3: Testing InSpec plugin..." -ForegroundColor Yellow
$inspecPlugins = inspec plugin list 2>$null | Select-String "train-juniper"

if ($inspecPlugins) {
    Write-Host "✓ train-juniper plugin loaded in InSpec" -ForegroundColor Green
} else {
    Write-Host "⚠ train-juniper not in InSpec plugin list" -ForegroundColor Yellow
    Write-Host "  This is OK - the gem install method works fine"
}
Write-Host ""

# Test 4: Mock connection test
Write-Host "Test 4: Testing mock connection..." -ForegroundColor Yellow
$mockTest = inspec detect -t juniper://admin@mock?mock=true 2>&1

if ($mockTest -match "juniper") {
    Write-Host "✓ Mock connection successful" -ForegroundColor Green
    Write-Host "  Platform detected: juniper"
} else {
    Write-Host "✗ Mock connection failed" -ForegroundColor Red
}
Write-Host ""

# Test 5: Show example commands
Write-Host "Example Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Direct connection:"
Write-Host '  inspec detect -t juniper://admin@device.example.com --password "secret"' -ForegroundColor Gray
Write-Host ""
Write-Host "Bastion with SSH key:"
Write-Host '  inspec detect -t juniper://admin@device `' -ForegroundColor Gray
Write-Host '    --bastion-host jump.example.com `' -ForegroundColor Gray
Write-Host '    --bastion-user jumpuser' -ForegroundColor Gray
Write-Host ""
Write-Host "Bastion with password (NEW - uses plink.exe):"
Write-Host '  inspec detect -t juniper://admin@device `' -ForegroundColor Gray
Write-Host '    --bastion-host jump.example.com `' -ForegroundColor Gray
Write-Host '    --bastion-user jumpuser `' -ForegroundColor Gray
Write-Host '    --bastion-password "jump_pass" `' -ForegroundColor Gray
Write-Host '    --password "device_pass"' -ForegroundColor Gray
Write-Host ""

# Check if environment variables are set for real testing
if ($env:JUNIPER_HOST -and $env:BASTION_HOST) {
    Write-Host ""
    Write-Host "Environment variables detected:" -ForegroundColor Cyan
    Write-Host "  JUNIPER_HOST: $env:JUNIPER_HOST" -ForegroundColor Gray
    Write-Host "  BASTION_HOST: $env:BASTION_HOST" -ForegroundColor Gray
    Write-Host "  Ready for real device testing!" -ForegroundColor Green
}

# Summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($plinkPath -and ($gemList -match "train-juniper")) {
    Write-Host "✓ Your system is ready for Windows bastion testing!" -ForegroundColor Green
} else {
    Write-Host "⚠ Please install missing components before testing" -ForegroundColor Yellow
}