﻿<#
.SYNOPSIS
    Checks for prerequisites, then uses BDFR and BDFR-HTML to generate a subreddit HTML archive.
.DESCRIPTION
    This script uses the following Python modules, which are installed automatically:
        BDFR: https://pypi.org/project/bdfr/
        BDFR-HTML: https://github.com/BlipRanger/bdfr-html
    Prerequisite tools that must be installed before running this script:
        1. Git: https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.2/Git-2.33.0.2-64-bit.exe
        2. GitHub CLI: https://github.com/cli/cli/releases/download/v2.0.0/gh_2.0.0_windows_amd64.msi
        3. Python 3.9 (includes pip)(MUST CHECK 'Add Python 3.9 to PATH'): https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe
.PARAMETER Subreddit
    The name of the subreddit (as it appears after the /r/ in the URL) that will be archived.
.EXAMPLE
    .\New-SubredditHTMLArchive.ps1 -Subreddit PowerShell
.NOTES
    Last update: Wednesday, September 30, 2021 2:31:12 AM
#>

param([string]$Subreddit)

## Init
if (-not($Subreddit)){$Subreddit = Read-Host -Prompt 'Enter subreddit to archive:'}
if (-not($Subreddit)){throw 'Error: Subreddit name is blank!'}
$stopWatch = New-Object System.Diagnostics.Stopwatch
$stopWatch.Start()

## Check for Command Line Utilities
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Checking for Command Line Utilities ..."
foreach ($exeName in @('git','gh','python','pip')){if (-not(Get-Command "$($exeName).exe" -ErrorAction SilentlyContinue)){throw "Error: Missing command line utility prerequisite: $($exeName).exe. See script comment header description for installers."}}
if ((&{git --version}) -notlike "*version 2.*"){throw 'Error: Git version 2 is required!'}
if ((&{gh --version})[0] -notlike "*version 2.*"){throw 'Error: GitHub CLI version 2 is required!'}
if ((&{python -V}) -notlike "*Python 3.9*"){throw 'Error: Python version 3.9 is required!'}
if ((&{pip -V}) -notlike "*pip 2*"){throw 'Error: Pip version 2 is required!'}

## Check/Create BDFR Output Folders
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Checking and cleaning BDFR output folders ..."
[string]$bdfrFolderRoot = "$($env:HOMEDRIVE)$($env:HOMEPATH)\Documents\BDFR"
[string]$bdfrJSONFolder = "$bdfrFolderRoot\JSON"; [string]$bdfrHTMLFolder = "$bdfrFolderRoot\HTML"
if (-not(Test-Path "$bdfrJSONFolder\$Subreddit" -PathType Container))
{
    Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Creating BDFR output folders at $bdfrFolderRoot ..."
    New-Item -Path "$bdfrFolderRoot\module_clone" -ItemType Directory -Force | Out-Null
    New-Item -Path "$bdfrJSONFolder\$Subreddit" -ItemType Directory -Force | Out-Null
    New-Item -Path "$bdfrHTMLFolder\$Subreddit" -ItemType Directory -Force | Out-Null
}

## Remove Existing Files in Output Folders
if (Get-ChildItem "$bdfrJSONFolder\$Subreddit\*" -File -ErrorAction SilentlyContinue){Remove-Item -Path "$bdfrJSONFolder\$Subreddit\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null}
if (Get-ChildItem "$bdfrHTMLFolder\$Subreddit\*" -File -ErrorAction SilentlyContinue){Remove-Item -Path "$bdfrHTMLFolder\$Subreddit\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null}

## Check for Python modules BDFR and BDFR-HTML
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Checking for BDFR and BDFR-HTML Python modules ..."
[boolean]$bdfrInstalled = $false
[boolean]$bdfrhtmlInstalled = $false
$installedPythonModules = @(pip list --disable-pip-version-check)
foreach ($installedPythonModule in $installedPythonModules)
{
    if ($installedPythonModule -like "bdfr *"){$bdfrInstalled = $true}
    if ($installedPythonModule -like "bdfrtohtml*"){$bdfrhtmlInstalled = $true}
}

## Install Python modules BDFR and BDFR-HTML
if (-not($bdfrInstalled))
{
    Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Installing BDFR Python module ..."
    $bdfrInstallProcess = Start-Process "python.exe" -ArgumentList "-m pip install bdfr --upgrade" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrInstallProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m pip install bdfr --upgrade' returned exit code $($bdfrInstallProcess.ExitCode)!"}
    Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Updating BDFR Python module ..."
    $bdfrUpdateProcess = Start-Process "python.exe" -ArgumentList "-m pip install bdfr --upgrade" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrUpdateProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m pip install bdfr --upgrade' returned exit code $($bdfrUpdateProcess.ExitCode)!"}
}
if (-not($bdfrhtmlInstalled))
{
    Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Installing BDFR-HTML Python module ..."
    Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Cloning GitHub repository for BDFR-HTML module ..."
    $bdfrhtmlCloneProcess = Start-Process "gh.exe" -ArgumentList "repo clone BlipRanger/bdfr-html" -WorkingDirectory "$bdfrFolderRoot\module_clone" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrhtmlCloneProcess.ExitCode -ne 0){throw "Error: Command: 'gh.exe repo clone BlipRanger/bdfr-html' returned exit code $($bdfrhtmlCloneProcess.ExitCode)!"}
    Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Running BDFR-HTML module setup script ..."
    $bdfrhtmlScriptProcess = Start-Process "python.exe" -ArgumentList "setup.py install" -WorkingDirectory "$bdfrFolderRoot\module_clone\bdfr-html" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrhtmlScriptProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe $bdfrFolderRoot\module_clone\setup.py install' returned exit code $($bdfrhtmlScriptProcess.ExitCode)!"}
}

## Recheck for Python modules BDFR and BDFR-HTML
$installedPythonModules = @(pip list --disable-pip-version-check)
foreach ($installedPythonModule in $installedPythonModules)
{
    if ($installedPythonModule -like "bdfr *"){$bdfrInstalled = $true}
    if ($installedPythonModule -like "bdfrtohtml*"){$bdfrhtmlInstalled = $true}
}
if (-not($bdfrInstalled -and $bdfrhtmlInstalled)){throw "Error: Python modules BDFR and/or BDFR-HTML are still not present!"}

## BDFR: Clone Subreddit to JSON
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Using BDFR to clone subreddit '$Subreddit' to disk ..."
$bdfrProcess = Start-Process "python.exe" -ArgumentList "-m bdfr clone $bdfrJSONFolder --subreddit $Subreddit --max-wait-time 300" -WindowStyle Hidden -PassThru -Wait
if ($bdfrProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m bdfr clone $bdfrJSONFolder --subreddit $Subreddit --max-wait-time 300' returned exit code '$($bdfrProcess.ExitCode)'!"}

## BDFR-HTML: Process Cloned Subreddit to HTML
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Using BDFR-HTML to generate subreddit HTML pages ..."
$bdfrhtmlProcess = Start-Process "python.exe" -ArgumentList "-m bdfrtohtml --input_folder $bdfrJSONFolder\$Subreddit --output_folder $bdfrHTMLFolder\$Subreddit" -WindowStyle Hidden -PassThru -Wait
if ($bdfrhtmlProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m bdfrtohtml --input_folder $bdfrJSONFolder\$Subreddit --output_folder $bdfrHTMLFolder\$Subreddit' returned exit code '$($bdfrhtmlProcess.ExitCode)'!"}

## Open Completed HTML Folder
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Opening subreddit HTML output folder ..."
start "$bdfrHTMLFolder\$Subreddit\"

## End
$stopWatch.Stop()
Write-Output "[$(Get-Date -f HH:MM:ss.fff)] Finished! Run time was $($stopWatch.Elapsed.Seconds) seconds."
pause
exit