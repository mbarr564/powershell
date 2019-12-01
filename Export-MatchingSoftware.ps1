<#
.SYNOPSIS
    Consumes CSV regex pattern table, performs regex matches against registry uninstall entries for installed software.
    When there are matching software packages, generates CSV output for both current and downlevel versions.
    Generated columns: ComputerName, ProductName, ProductVersion, Publisher, KeyPSPath, UninstallString, ProductPattern, MSLicenseStatus, MSLicenseName, MSLicenseDescription
.DESCRIPTION
    Intended to be executed as a SCCM configuration baseline or AD GPO, against site endpoints/workstations.
    The resulting MSSQL table of licensed software per device is then used to generate licensed software reports.
    This script is intended for sites that do not have Asset Intelligence enabled for security/policy reasons.
    Required components to make this script function as intended:
    - CSV pattern table: https://github.com/mbarr425/powershell/blob/master/software_patterns-template.csv ("software_patterns.csv")
    - New SCCM config baseline or group policy object, that runs this script.
    - Network share for clients/workstations/endpoints to write their CSV formatted software matches.
    - Unsupplied PowerShell script and/or runbook that combines the CSV files and uploads the table into MSSQL, once per week.
.EXAMPLE
    .\Export-MatchingSoftware.ps1
.NOTES
    Last update: mike.barr@esd.wa.gov - Tuesday, September 25, 2018 11:50:18 AM
#>

## Init
#$VerbosePreference = 'Continue'
$computerName = $env:COMPUTERNAME
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exportSharePath = '\\server\share\_ClientSoftwareInventory'

## Get Software Patterns From CSV
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Loading Software Regex Patterns ..."
try {$patternsTable = Import-CSV "$scriptPath\software_patterns.csv" -ErrorAction Stop}
catch
{
    try {$patternsTable = Import-CSV "$exportSharePath\software_patterns.csv" -ErrorAction Stop}
    catch {return $false}
}
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Loaded $($patternsTable.count) Software Regex Patterns ..."

## Get Installed Software - HKEY_USER
$installedProducts = @()
$uninstallKeyPSPathsHKU = @()
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Retrieving HKU Uninstall Key Values ..."
[string[]]$userSIDs = (Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList").Name | Split-Path -Leaf | ? {$_ -like "S-1-5-21-*"}
foreach ($userSID in $userSIDs)
{
    $fullKeyPath = "HKU:\$userSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    if (Test-Path $fullKeyPath){$uninstallKeyPSPathsHKU += (Get-ChildItem -Path $fullKeyPath).PSPath}
}
foreach ($path in $uninstallKeyPSPathsHKU)
{
    $keyValues = Get-ItemProperty $path | Select DisplayVersion,DisplayName,Publisher,UninstallString
    if (-not($keyValues.DisplayVersion -and $keyValues.DisplayName -and $keyValues.Publisher)){continue}
    $installedProducts += [PSCustomObject]@{
        ComputerName = $computerName
        ProductVersion = $keyValues.DisplayVersion
        ProductName = $keyValues.DisplayName
        Publisher = $keyValues.Publisher
        KeyPSPath = $path
        Uninstall = $keyValues.UninstallString
    }
}

## Get Installed Software - HKEY_LOCAL_MACHINE
$uninstallKeyPSPathsHKLM = @()
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Retrieving HKLM Uninstall Key Values ..."
$uninstallKeyPSPathsHKLM = (Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall").PSPath
$uninstallKeyPSPathsHKLM += (Get-ChildItem -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall").PSPath
foreach ($path in $uninstallKeyPSPathsHKLM)
{
    $keyValues = Get-ItemProperty $path | Select DisplayVersion,DisplayName,Publisher,UninstallString
    if (-not($keyValues.DisplayVersion -and $keyValues.DisplayName -and $keyValues.Publisher)){continue}
    $installedProducts += [PSCustomObject]@{
        ComputerName = $computerName
        ProductVersion = $keyValues.DisplayVersion
        ProductName = $keyValues.DisplayName
        Publisher = $keyValues.Publisher
        KeyPSPath = $path
        Uninstall = $keyValues.UninstallString
    }
}

## Match Downlevel Software Packages
$currentProducts = @()
$downlevelProducts = @()
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Matching Installed Software Packages ..."
foreach ($installedProduct in $installedProducts)
{
    foreach ($regexPattern in $patternsTable)
    {
        if ($regexPattern.DownlevelPattern -ne 'NULL') #match both if downlevel pattern exists
        {
            if ($installedProduct.ProductName -match $regexPattern.DownlevelPattern)
            {
                $installedProduct | Add-Member -MemberType NoteProperty -Name 'ProductPattern' -Value $regexPattern.DownlevelPattern
                $downlevelProducts += $installedProduct #props: ProductName,ProductVersion,Publisher,KeyPSPath,Uninstall
            }
            elseif ($installedProduct.ProductName -match $regexPattern.LatestVersionPattern)
            {
                $installedProduct | Add-Member -MemberType NoteProperty -Name 'ProductPattern' -Value $regexPattern.LatestVersionPattern
                $currentProducts += $installedProduct
            }
        }
        elseif ($installedProduct.ProductName -match $regexPattern.LatestVersionPattern) #match only latest version if not
        {
            $installedProduct | Add-Member -MemberType NoteProperty -Name 'ProductPattern' -Value $regexPattern.LatestVersionPattern
            $currentProducts += $installedProduct
        }
    }
}

## Retrieve Activated Software
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Retrieving MS Licensed Software ..."
$msLicensedSoftwares = Get-CimInstance SoftwareLicensingProduct -Filter "LicenseStatus = '1'" -Verbose:$false | ? {$_.Name -notlike "Windows*"} | Select Name,ApplicationID,Description
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Adding Members: SearchString ..."
foreach ($msLicensedSoftware in $msLicensedSoftwares)
{
    switch -wildcard ($msLicensedSoftware.Name)
    {
        ## Mapping CIM Strings to ProductName Strings (Match MS Licensed to Registry/Uninstall)
        "*Office15VisioPro*" {$msLicensedSoftware | Add-Member -MemberType NoteProperty -Name SearchString -Value 'Visio Professional 2013'; break}
        "*Office16VisioPro*" {$msLicensedSoftware | Add-Member -MemberType NoteProperty -Name SearchString -Value 'Visio Professional 2016'; break}
        "*Office15Project*" {$msLicensedSoftware | Add-Member -MemberType NoteProperty -Name SearchString -Value 'Project Professional 2013'; break}
        "*Office16Project*" {$msLicensedSoftware | Add-Member -MemberType NoteProperty -Name SearchString -Value 'Project Professional 2016'; break}
        "*O365ProPlus*" {$msLicensedSoftware | Add-Member -MemberType NoteProperty -Name SearchString -Value 'Office 365 ProPlus'; break}
    }
}

## Add MSLicense NoteProperties (SQL Columns)
Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Adding Members: MSLicenseStatus, MSLicenseName, MSLicenseDescription ..."
foreach ($product in @($downlevelProducts+$currentProducts))
{
    $msLicensedSoftwares | % {

        if ($_.SearchString)
        {
            if ($product.ProductName -like "*$($_.SearchString)*")
            {
                $product | Add-Member -MemberType NoteProperty -Name MSLicenseStatus -Value $true
                $product | Add-Member -MemberType NoteProperty -Name MSLicenseName -Value $_.Name
                $product | Add-Member -MemberType NoteProperty -Name MSLicenseDescription -Value $_.Description
            }
        }
    }
}
foreach ($product in @($downlevelProducts+$currentProducts))
{
    if (-not($product.MSLicenseStatus)) #if not note'd during previous loop, software is not Microsoft licensed, and needs null values
    {
        $product | Add-Member -MemberType NoteProperty -Name MSLicenseStatus -Value $false
        $product | Add-Member -MemberType NoteProperty -Name MSLicenseName -Value 'NULL'
        $product | Add-Member -MemberType NoteProperty -Name MSLicenseDescription -Value 'NULL'
    }
}

## Export Downlevel
if ($downlevelProducts.count -gt 0)
{
    Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Exporting Downlevel CSV ($($downlevelProducts.count) rows) ..."
    try {$downlevelProducts | Export-CSV "$exportSharePath\Downlevel\$computerName`.csv" -NoTypeInformation -ErrorAction Stop} catch {return $false}
}
else
{
    Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] No matching downlevel products."
    try {"None" | Out-File "$exportSharePath\Downlevel\$computerName`.txt" -ErrorAction Stop} catch {return $false}
}

## Export Current Versions
if ($currentProducts.count -gt 0)
{
    Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] Exporting LicensedCurrent CSV ($($currentProducts.count) rows) ..."
    try {$currentProducts | Export-CSV "$exportSharePath\LicensedCurrent\$computerName`.csv" -NoTypeInformation -ErrorAction Stop} catch {return $false}
}
else
{
    Write-Verbose "[$(Get-Date -f hh:mm:ss.fff)] No matching licensed current version products."
    try {"None" | Out-File "$exportSharePath\LicensedCurrent\$computerName`.txt" -ErrorAction Stop} catch {return $false}
}

return $true
