
# Running online on the current machine or offline via MDT or external drive

if (Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT) {
   
    $Online = $False
}
else
{
  
    $Online = $True

}


#get variables
if ($Online) {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
    exit;
}
    $make = Get-WMIObject -class Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer
    $model = Get-WMIObject -class Win32_ComputerSystem | Select-Object -ExpandProperty Model

} else {
    
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    # $tsenv.GetVariables() | % { Write-Host "$_ = $($tsenv.Value($_))" } #prints variables
    $make = $tsenv.Value('make')
    $model = $tsenv.Value('model')
    $deployRoot = $tsenv.Value('deployRoot')
    $SMSTSLOCALDATADRIVE = $tsenv.Value('SMSTSLOCALDATADRIVE')

}

# set destination folder

if ($Online) {

    $initDestination = "$env:USERPROFILE\Desktop\Drivers\$make\$model"


} else {
    
    $initDestination = "$deployRoot\Drivers\$make\$model"
}

# test path

if (Test-Path "$initDestination") {
   
    Write-Host "Folder Exists"
}
else
{
  
    New-Item "$initDestination" -ItemType Directory
    Write-Host "Folder Created successfully"

}

# pull drivers

if ($Online) {
    dism /online /Export-Driver /Destination:"$initDestination" | Out-Null
    $DriverList = Get-WindowsDriver -Online
    
} else {
    
    dism /Image:$SMSTSLOCALDATADRIVE /Export-Driver /Destination:"$initDestination" | Out-Null
    $DriverList = Get-WindowsDriver -Path $SMSTSLOCALDATADRIVE 

}

#sort drivers
 Write-Host "creating array..."
$DriverArray = @()

ForEach($Driver in $DriverList) {
    
    $Folder = Split-Path (Split-Path $Driver.OriginalFileName -Parent) -Leaf

    $DriverInfo = New-Object PSCustomObject -Property @{
        Folder = $Folder
        Class = $Driver.ClassName
        Provider = $Driver.ProviderName
        Version = $Driver.Version
    }

    $DriverArray += $DriverInfo
}

 Write-Host "sorting..."
ForEach($Driver in $DriverArray) {
    
    $Destination = ("{0}\{1}\{2}\{3}" -f "$initDestination", $Driver.Class, $Driver.Provider, $Driver.Version)
    
    New-Item -ItemType Directory -Force -Path "$Destination" | Out-Null
    #move-Item -Path "$initDestination\$($Driver.Folder)" -Destination "$Destination" -Force # not working??
    Copy-Item -Path "$initDestination\$($Driver.Folder)" -Destination "$Destination" -Force
    Remove-Item "$initDestination\$($Driver.Folder)" -Recurse
}
