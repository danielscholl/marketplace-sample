# Import the required module
Write-Host "Importing ARM TTK module..."
Import-Module /opt/arm-ttk/arm-ttk/arm-ttk/arm-ttk.psd1

# Create output directory if it doesn't exist
Write-Host "Creating output directory..."
if (!(Test-Path "/workspace/output")) {
    New-Item -Path "/workspace/output" -ItemType Directory -Force
}

# Get all JSON files in the templates directory
Write-Host "Searching for JSON files in /workspace/src..."
$jsonFiles = Get-ChildItem -Path /workspace/src -Filter *.json -Recurse
Write-Host "Found $($jsonFiles.Count) JSON files"

# Initialize test result
$testsPassed = $true
$testResults = @()

# Loop through each JSON file and execute the command
foreach ($file in $jsonFiles) {
    Write-Host "`nTesting file: $($file.FullName)"
    # Execute the command on the current JSON file
    $results = Test-AzTemplate -TemplatePath $file.FullName
    Write-Host "Test Results:"
    $results | Format-Table

    # Store simplified results for this file
    $simplifiedResults = $results | ForEach-Object {
        @{
            Name = $_.Name
            Passed = $_.Passed
            Message = if ($_.Errors.Message) { $_.Errors.Message -join "; " } else { "" }
            File = if ($_.File.FullPath) { $_.File.FullPath } else { "" }
            Line = if ($_.File.Line) { $_.File.Line } else { 0 }
            Column = if ($_.File.Column) { $_.File.Column } else { 0 }
        }
    }

    $fileResults = @{
        FileName = $file.Name
        Path = $file.FullName
        Results = $simplifiedResults
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $testResults += $fileResults

    if ($results -contains $false) {
        Write-Host "Tests failed for $($file.Name)" -ForegroundColor Red
        $testsPassed = $false
        break
    }
}

# Save test results to a JSON file
$testResults | ConvertTo-Json -Depth 4 | Out-File "/workspace/output/test-results.json"

# Also save a more readable format
$testSummary = foreach ($result in $testResults) {
    "File: $($result.FileName)"
    "Path: $($result.Path)"
    "Timestamp: $($result.Timestamp)"
    "Results:"
    foreach ($testResult in $result.Results) {
        "  Test: $($testResult.Name)"
        "  Passed: $($testResult.Passed)"
        if ($testResult.Message) {
            "  Message: $($testResult.Message)"
        }
        if ($testResult.File) {
            "  Location: $($testResult.File):$($testResult.Line):$($testResult.Column)"
        }
        "  ----------------"
    }
    "----------------------------------------`n"
}
$testSummary | Out-File "/workspace/output/test-results.txt"

if ($testsPassed) {
    Write-Host "`nAll tests passed." -ForegroundColor Green
    # Create a file to indicate success
    New-Item -Path "/workspace/output/test-passed" -ItemType File -Force
    Get-ChildItem "/workspace/output"
    exit 0
} else {
    Write-Host "`nTests failed." -ForegroundColor Red
    exit 1
}
