<#

Use this script to run ARM TTK with supressions. 

#>

Param(
    [string]$templateIdentifier = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#',

    [string]$pathOfTemplates = 'src\InfrastructureProvisioning', 

    [ValidateSet("true", "false")]
    [string]$installArmTtk = "true"
)

$Currentlocation = Get-Location
Write-Host "Currentlocation: $Currentlocation" 
if ($installArmTtk -eq "true") {
    Invoke-WebRequest -uri "https://aka.ms/arm-ttk-marketplace" -OutFile $Currentlocation\arm-ttk.zip
    Expand-Archive -Path  $Currentlocation\arm-ttk.zip -DestinationPath $Currentlocation
    Get-ChildItem *.ps1, *.psd1, *.ps1xml, *.psm1 -Recurse | Unblock-File
    Import-Module  $Currentlocation\arm-ttk\arm-ttk.psd1
} 

cd $pathOfTemplates
$armSupressions = Get-Content .\arm_supressions.json | ConvertFrom-Json
$globalSupressions = $armsupressions.global_supressions
$localSupressions = $armsupressions.local_supressions
            
$filepaths = Get-ChildItem -Recurse | Select-String $templateIdentifier -List | Select Path
cd $Currentlocation
$errorfound = "false"
for ($i = 0; $i -lt $filepaths.Count; $i++) {
    Write-Host $filepaths[$i].Path
                                            
    $output = Test-AzTemplate -TemplatePath $filepaths[$i].Path
                  
    for ($testcase = 0; $testcase -lt $output.Count; $testcase++) {
        if (!$output[$testcase].Passed) {              
            $supressed = "false"
            for ($j = 0; $j -lt $globalSupressions.Count; $j++) {    
                if (($output[$testcase].Name).Contains($globalSupressions[$j])) {
                    Write-Host "Supression: $globalSupressions[$j]"
                    $supressed = "true"
                }
            }
            $localSupressions | foreach {
                if ($filepaths[$i].Path.Contains($_.file)) {
                    $supressions = $_.supressions
                    for ($k = 0; $k -lt $supressions.Count; $k++) {
                        if (($output[$testcase].Name).Contains($supressions[$k])) {
                            Write-Host "Supression: $supressions[$k]"
                            $supressed = "true"
                        }
                    }
                }
            }
            if ($supressed -eq "false") {
                echo "**********FAILED TEST**********"
                echo $output[$testcase]
                $errorfound = "true"
            }
        }  
        else {
            echo $output[$testcase]
        } 
    }
}
              
                                
if ($errorfound -eq "true") {
    exit 1
}