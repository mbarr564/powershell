## ArenaNet Take Home - Mike Barr
## PS> Get-Help .\Remove-FilesAndDirectories.ps1 -Full

<#
    .SYNOPSIS
        Selectively remove files and folders under the supplied path(s).
    .DESCRIPTION
        Selectively remove files and folders under the supplied path(s).
    .PARAMETER Paths
        String array containing root paths to process.
    .PARAMETER AgeDays
        Process only items greater than this many days old.
    .PARAMETER SizeMB
        Process only items over this size in megabytes.
    .PARAMETER Extension
        Process only items with this file extension. Must be a three letter string. (future: complex extensions)
    .PARAMETER IncludeFolders
        Switch to include folders. Default is to process only files.
    .EXAMPLE
        .\Remove-FilesAndDirectories.ps1 -Paths 'F:\Share\Folder\SubFolder','F:\Share\Folder\SubFolder2\' -AgeDays 8 -IncludeFolders:$true
    .EXAMPLE
        .\Remove-FilesAndDirectories.ps1 -Paths 'D:\WebRoot\Logs' -SizeMB 2 -AgeDays 14 -Extension 'log'
    .EXAMPLE
        .\Remove-FilesAndDirectories.ps1 -Paths '\\server\share\folder1','\\server\share\folder2','\\server\share\folder3' -SizeMB 50
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateCount(1,20)]
    [string[]]$Paths,
    
    [ValidatePattern('^[A-Za-z]{3}$')]
    [string]$Extension,

    [ValidateRange(1,365)]
    [int]$AgeDays,

    [ValidateRange(1,1048576)]
    [int]$SizeMB,

    [switch]$IncludeFolders = $false
)

## Init
$removeErrors = 0
$VerbosePreference = 'Continue'
if ($Extension -and $IncludeFolders){throw 'NYI: The -Extension and -IncludeFolders parameters cannot be used in conjunction.'}
$Paths | % {$_ = $_.TrimEnd('\')} #strip all trailing slashes

## Logging
$logFolder = "$env:temp\Script_Logs\Remove-FilesAndDirectories"
$logPath = "$logFolder\$(Get-Date -f 'yyyy-MM-dd_hh-mm-ss').txt"
if (-not(Test-Path -Path $logFolder)){New-Item -Path $logFolder -ItemType Directory -Force | Out-Null}
try {Start-Transcript -Path $logPath -ErrorAction Stop}
catch {"Start-Transcript error: $_" | Out-File -FilePath $logPath; exit 1}

## Main
foreach ($Path in $Paths)
{
    ## GCI Retrieve Splatting
    $retrieveArgs = @{}
    if ($Extension)
    {
        $retrieveArgs.Add('Path',"$Path\*") #add path wildcard for extensions
        $retrieveArgs.Add('Include',"*.$Extension")
    }
    else {$retrieveArgs.Add('Path',$Path)}
    $retrieveArgs.Add('ErrorAction','Stop')

    ## GCI Retrieve Path Items
    $pathItems = @()
    Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Processing path: $Path ..."
    try {$pathItems = Get-ChildItem @retrieveArgs}
    catch [System.UnauthorizedAccessException]{Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Access Denied: $Path"; $removeErrors++; continue}
    if (-not($pathItems.count -ge 1)){continue} #empty

    ## Filter Path Items
    Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Filtering $($pathItems.count) items ..."
    if ($AgeDays){$pathItems = $pathItems | ? {$_.CreationTime -lt ((Get-Date).AddDays("-$AgeDays"))}}
    if ($IncludeFolders){$folderItems = $pathItems | ? {$_.PSIsContainer -eq $true}} #save the folders to $folderItems, since the next step
    if ($SizeMB){$sizeItems = $pathItems | ? {(($_.Length/1MB) -gt $SizeMB)}} #potentially filters zero length folders
    if ($SizeMB -and $IncludeFolders){$pathItems = $sizeItems + $folderItems} #then concat the arrays if both params are used
    if ($SizeMB -and (-not($IncludeFolders))){$pathItems = $sizeItems} #if only sizeMB, the size filter doesn't include folders anyway
    if ($IncludeFolders -and (-not($SizeMB))){$pathItems = $folderItems + $pathItems} #if only including folders, concat folder array to path items

    ## Remove Items
    Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Removing $($pathItems.count) items ..."
    foreach ($pathItem in $pathItems)
    {
        ## Remove Splatting
        $removeArgs = @{}
        $removeArgs.Add('Path',$pathItem.FullName)
        if ($pathItem.PSIsContainer){$removeArgs.Add('Recurse',$true)} #delete all subdirectories/files from directories
        $removeArgs.Add('ErrorAction','Stop')

        ## Remove
        Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Removing: $($pathItem.FullName)"
        try {Remove-Item @removeArgs}
        catch {Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Error Removing: $($pathItem.FullName)"; $removeErrors++}
    }
}

## End
Write-Verbose "[$(Get-Date -f 'hh:mm:ss.fff')][$($MyInvocation.MyCommand.Name)] Processing Complete"
Stop-Transcript
if ($removeErrors -gt 0){exit 1} else {exit 0}