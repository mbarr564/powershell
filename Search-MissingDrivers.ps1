<#
.SYNOPSIS
    Searches SCCM driver repository for matching device drivers, from an input string hashtable.
    The input string expected is output from this command (with single quotes added around names and values): Get-WmiObject Win32_PNPEntity | Where-Object {$_.ConfigManagerErrorCode -ne 0} | Select Name, DeviceID
    This script was requested by a coworker to expedite the process of detecting and correcting missing drivers during workstation SCCM imaging.
    Essentially this script performs the Windows OS task of searching for matching drivers, but uses a faster cached lookup, from an email body copy and paste.
.DESCRIPTION
    Intended to be run via supplied link from the Report-MissingDrivers script's email body, sent when missing drivers are detected.
    The string must be formatted as a pseudo here-string, with single quoted names and values, with "`n" linebreaks between table elements.
.PARAMETER RefreshCache
    If param -RefreshCache:$true is supplied, the local INF cache file will be updated from the DriverPackages share path.
.EXAMPLE
    .\Search-MissingDriver.ps1 -Devices "'deviceName1'='deviceValue1'`n'deviceName2'='deviceValue2'`n'deviceName3'='deviceValue3'`n"
.EXAMPLE
    .\Search-MissingDriver.ps1 -Devices "'PCI Memory Controller'='PCI\\VEN_8086&DEV_A2A1&SUBSYS_829A103C&REV_00\\3&11583659&0&FA'`n'Unknown 1'='USB\\VID_8087&PID_0A2B\\5&1272F2AF&0&14'`n'SM Bus Controller'='PCI\\VEN_8086&DEV_A2A3&SUBSYS_829A103C&REV_00\\3&11583659&0&FC'`n'PCI Serial Port'='PCI\\VEN_8086&DEV_A2BD&SUBSYS_829A103C&REV_00\\3&11583659&0&B3'`n'PCI Data Acquisition and Signal Processing Controller'='PCI\\VEN_8086&DEV_A2B1&SUBSYS_829A103C&REV_00\\3&11583659&0&A2'`n'PCI Simple Communications Controller'='PCI\\VEN_8086&DEV_A2BA&SUBSYS_829A103C&REV_00\\3&11583659&0&B0'`n"
.NOTES
    Last update: mike.barr@esd.wa.gov - Thursday, August 2, 2018 12:49:44 PM
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Devices,
    [switch]$RefreshCache = $false
)

## Init
$VerbosePreference = 'Continue'
$driverSearchRoot = '\\server\share\driver_folder\driver_packages'
$localCachePath = 'C:\logs\inf_cache'

## Convert From Input String to Hashtable, Remove Single Quotes
$devicesHash = @{}
$devicesHashWithQuotes = @{} #$Devices = "'PCI Memory Controller'='PCI\\VEN_8086&DEV_A2A1&SUBSYS_829A103C&REV_00\\3&11583659&0&FA'`n'Unknown 1'='USB\\VID_8087&PID_0A2B\\5&1272F2AF&0&14'`n'SM Bus Controller'='PCI\\VEN_8086&DEV_A2A3&SUBSYS_829A103C&REV_00\\3&11583659&0&FC'`n'PCI Serial Port'='PCI\\VEN_8086&DEV_A2BD&SUBSYS_829A103C&REV_00\\3&11583659&0&B3'`n'PCI Data Acquisition and Signal Processing Controller'='PCI\\VEN_8086&DEV_A2B1&SUBSYS_829A103C&REV_00\\3&11583659&0&A2'`n'PCI Simple Communications Controller'='PCI\\VEN_8086&DEV_A2BA&SUBSYS_829A103C&REV_00\\3&11583659&0&B0'`n"
$devicesHashWithQuotes = ConvertFrom-StringData $Devices
$devicesHashWithQuotes.GetEnumerator() | % {$devicesHash.Add($_.Name.TrimStart("'").TrimEnd("'"),$_.Value.TrimStart("'").TrimEnd("'"))} #trim single quotes from start/end of names/values
if (-not($devicesHash.count -gt 0)){throw 'Error: Unable to parse device input param!'}

## Format Device Strings
foreach ($deviceName in @($devicesHash.Keys))
{
    $deviceID = ($devicesHash.GetEnumerator() | Where-Object {$_.Name -eq $deviceName}).Value #match key name to return ID
    $splitDeviceID = $deviceID.Split('\') #$Device = @{'PCI Video Adapter'='PCI\VEN_8086&DEV_1912&SUBSYS_8056103C&REV_06\3&11583659&0&10'}
    $cleanDeviceID = "$($splitDeviceID[0])\$($splitDeviceID[1])" #trim after second backslash
    if ($cleanDeviceID -like "*&REV_??"){$cleanDeviceID = $cleanDeviceID -replace "&REV_.?.?$",''} #trim revision suffix
    $cleanDeviceID = $cleanDeviceID -replace '\\','\\' #add escape to slashes to make device ID string regex compatible
    foreach ($Key in @($devicesHash.Keys)){if ($deviceName -eq $Key){$devicesHash[$Key] = $cleanDeviceID}} #update hashtable value with cleaned deviceID string
}

## Cache Check / Warning
if ((Test-Path "$localCachePath\_INFDeviceIDs.cache") -and (-not($RefreshCache)))
{
    $cacheAgeDays = ([datetime](gci "$localCachePath\_INFDeviceIDs.cache").LastWriteTime - [datetime](Get-Date)).Days
    if ($cacheAgeDays -lt -7){Write-Warning "[$(Get-Date -f hh:mm:ss)] Local Cache File is $($cacheAgeDays * -1) days old! Consider re-running with param -RefreshCache:`$true"}
}

## Cache Switch / Refresh
Write-Verbose "[$(Get-Date -f hh:mm:ss)] Gathering INF file paths ..."
try {$cacheCount = (gci $localCachePath -ErrorAction Stop).count} catch {}
if (-not($cacheCount)){$cacheCount = 0}
if ($RefreshCache -or ($cacheCount -eq 0))
{
    ## Gather Remote INF Files
    $INFs = (Get-ChildItem $driverSearchRoot -Include "*.inf" -Recurse).FullName

    ## Copy INF Files to Local Drive Cache
    Write-Verbose "[$(Get-Date -f hh:mm:ss)] Caching $($INFs.count) INF files at '$localCachePath' ..."
    if (-not(Test-Path $localCachePath)){New-Item $localCachePath -ItemType Directory -Force | Out-Null}
    try {if ($refreshCache){Remove-Item "$localCachePath\*" -ErrorAction Stop | Out-Null}} catch {}
    foreach ($INF in $INFs)
    {
        $uniqueID = Get-Date -f ffffff
        $INFfileName = Split-Path $INF -Leaf
        Copy-Item -Path $INF -Destination "$localCachePath\$($uniqueID)_$INFfileName" #copy locally with seconds fraction unique prefix
        $INF | Out-File "$localCachePath\$($uniqueID)_$INFfileName.remote" #file showing original share path - to return instead of local cache path
    }

    ## Gather Local INF Files
    $INFs = (Get-ChildItem $localCachePath -Include "*.inf" -Recurse).FullName
}
else {$INFs = (Get-ChildItem $localCachePath -Include "*.inf" -Recurse).FullName}

## Parse/Load INF DeviceIDs
$INFContents = New-Object -TypeName 'System.Collections.ArrayList'; $INFloadCount = 0 #using an ArrayList and the .Add() method (over $INFContents = @() and the '+=' operator) is a 20x performance improvement
if ((Test-Path "$localCachePath\_INFDeviceIDs.cache") -and (-not($RefreshCache)))
{
    Write-Verbose "[$(Get-Date -f hh:mm:ss)] Loading DeviceIDs from cache file ..."
    $INFContents = Get-Content "$localCachePath\_INFDeviceIDs.cache" #load existing
}
else
{
    ## Recreate DeviceID Cache
    Write-Verbose "[$(Get-Date -f hh:mm:ss)] Caching DeviceIDs from $($INFs.count) INF files ..."
    foreach ($INF in $INFs)
    {
        ## Cache Lines with DeviceIDs
        $stream = New-Object -TypeName 'System.IO.StreamReader' -ArgumentList $INF
        while (-not($stream.EndOfStream))
        {
            $line = $stream.ReadLine()
            if ($line -match "[A-Z]{3}\\[A-Z]{3}_[0-9]{4}&[A-Z]{3}_[0-9A-Z]{4}") #ABC\DEF_1234&GHI_A1B2
            {
                [void]$INFContents.Add("$line<>$INF") #<> = seperator for splitting later, [void] because the .Add() method outputs the current array ubound otherwise
            }
        }
        $stream.Close()
        $INFloadCount++
    }

    ## Write Cache File
    Write-Verbose "[$(Get-Date -f hh:mm:ss)] Writing DeviceIDs to cache file ..."
    $INFContents | Out-File "$localCachePath\_INFDeviceIDs.cache"
}

## Match Devices to INF Contents
Write-Verbose "[$(Get-Date -f hh:mm:ss)] Searching INF cache for $($devicesHash.count) deviceID(s) ..."
$driverSearchRoot = $driverSearchRoot -replace '\\','\\' #make path string regex compatible
[string[]]$matchingINFs = @()
$matchingNameCache = @{}
foreach ($INFContent in $INFContents)
{
    ## Init
    $matchFound = $false
    $INFline = ($INFContent -split '<>')[0]
    $INFfilePath = ($INFContent -split '<>')[1]

    ## Skip Cache Lines
    if ($INFfilePath -eq $lastMatchingINFfilePath){continue} #since there are multiple lines in the cache file for each INF file (different deviceIDs, same file), store the previous matching INF file, to skip lines from the same file if a match was found in a previous loop

    ## Match DeviceID(s)
    foreach ($deviceName in @($devicesHash.Keys))
    {
        if ($matchingNameCache[$deviceName] -ge 3){continue} #if we already have x hits in the INF files, stop processing more matches for this device
        $deviceID = ($devicesHash.GetEnumerator() | Where-Object {$_.Name -eq $deviceName}).Value #match key name to return ID
        if ($INFline -match $deviceID) #future: use PS jobs to parallelize the search
        {
            ## Store Found Match
            $matchFound = $true; $lastMatchingINFfilePath = $INFfilePath
            $INFoutputPath = (Get-Content "$INFfilePath.remote") -replace $driverSearchRoot,'$' #shorten returned path
            $matchingINFs += "$deviceName >>> $INFoutputPath" #add to return array
            if ($deviceName -in @($matchingNameCache.Keys)){$matchingNameCache[$deviceName]++} #increment hashtable element
            else {$matchingNameCache.Add($deviceName,1)} #add name to cache hashtable
        }
        if ($matchFound){break}
    }
}

## Return Matching INF FullPaths
if ($matchingINFs.count -gt 0)
{
    $matchingINFs = $matchingINFs | Sort-Object #alphabetical sort
    Write-Verbose "[$(Get-Date -f hh:mm:ss)] Device Name >>> INF Path:"
    $matchingINFs | % {Write-Verbose "$_"}
}
else {Write-Verbose "[$(Get-Date -f hh:mm:ss)] No matches found."}
