<#
.SYNOPSIS
    Checks for prerequisites, then uses BDFR and BDFR-HTML to generate a subreddit HTML archive.
.DESCRIPTION
    If this script is being run for the first time, please ensure that it is being run with administrator privileges, so the Python modules install correctly. This is only needed once.
    This script uses the following Python modules, which are installed automatically:
        BDFR: https://pypi.org/project/bdfr/
        BDFR-HTML: https://github.com/BlipRanger/bdfr-html
            - When running setup.py to install BDFR-HTML (via script or manually), you may get an install error from Pillow about zlib being missing. You may need to run 'pip install pillow' from an elevated command prompt, so that Pillow installs correctly.
            - For manual BDFR-HTML install in case of Pillow install error: From an elevated CMD window, type these two quoted commands: 1) "cd %USERPROFILE%\Documents\BDFR\module_clone\bdfr-html", 2) "python.exe setup.py install"
            - https://stackoverflow.com/questions/64302065/pillow-installation-pypy3-missing-zlib
    Prerequisite tools that must be installed before running this script:
        1. Git: https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.2/Git-2.33.0.2-64-bit.exe
        2. GitHub CLI: https://github.com/cli/cli/releases/download/v2.3.0/gh_2.3.0_windows_amd64.msi
            - You'll need to launch Git CMD and authenticate with 'gh auth login', and follow the prompts, pasting the OTP into your browser.
        3. Python 3.x (includes pip): https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe
            - At beginning of install, YOU MUST CHECK 'Add Python 3.x to PATH'. (So PowerShell can call python.exe from anywhere)
            - At end of install, YOU MUST CLICK 'Disable path length limit'. (So long reddit post titles don't exceed max path length)
.PARAMETER Subreddit
    The name of the subreddit (as it appears after the /r/ in the URL) that will be archived.
.EXAMPLE
    .\New-SubredditHTMLArchive.ps1 -Subreddit PowerShell
.NOTES
    The reddit API returns a maximum of 1000 posts per BDFR, so only the newest 1000 posts will be included:
    https://github.com/reddit-archive/reddit/blob/master/r2/r2/lib/db/queries.py
.NOTES
    Script URL: https://github.com/mbarr564/powershell/blob/master/New-SubredditHTMLArchive.ps1
.NOTES
    Last update: Saturday, December 4, 2021 5:24:56 PM
#>

param([string]$Subreddit)

## Init
if (-not($Subreddit)){$Subreddit = Read-Host -Prompt 'Enter subreddit to archive'}
if (-not($Subreddit)){throw 'Error: Subreddit name is blank!'}
$stopWatch = New-Object System.Diagnostics.Stopwatch
$stopWatch.Start()

## Check for Command Line Utilities
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Checking for Command Line Utilities ..."
foreach ($exeName in @('git','gh','python','pip')){if (-not(Get-Command "$($exeName).exe" -ErrorAction SilentlyContinue)){throw "Error: Missing command line utility prerequisite: $($exeName).exe. See script comment header description for installers."}}
if ((&{git --version}) -notlike "*version 2.*"){throw 'Error: Git version 2 is required!'}
if ((&{gh --version})[0] -notlike "*version 2.*"){throw 'Error: GitHub CLI version 2 is required!'}
if ((&{python -V}) -notlike "*Python 3*"){throw 'Error: Python version 3 is required!'}
if ((&{pip -V}) -notlike "*pip 2*"){throw 'Error: Pip version 2 is required!'}

## Check/Create BDFR Output Folders
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Checking and cleaning BDFR output folders ..."
[string]$bdfrFolderRoot = "$($env:HOMEDRIVE)$($env:HOMEPATH)\Documents\BDFR"
[string]$bdfrJSONFolder = "$bdfrFolderRoot\JSON"; [string]$bdfrHTMLFolder = "$bdfrFolderRoot\HTML"
if (-not(Test-Path "$bdfrJSONFolder\$Subreddit\log" -PathType Container))
{
    Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Creating BDFR output folders at $bdfrFolderRoot ..."
    New-Item -Path "$bdfrFolderRoot\module_clone" -ItemType Directory -Force | Out-Null
    New-Item -Path "$bdfrJSONFolder\$Subreddit\log" -ItemType Directory -Force | Out-Null
    New-Item -Path "$bdfrHTMLFolder\$Subreddit" -ItemType Directory -Force | Out-Null
}

## Remove Existing Files in Output Folders
if (Get-ChildItem -Path "$bdfrJSONFolder\$Subreddit\*" -File -ErrorAction SilentlyContinue){Remove-Item -Path "$bdfrJSONFolder\$Subreddit\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null; New-Item -Path "$bdfrJSONFolder\$Subreddit\log" -ItemType Directory | Out-Null}
if (Get-ChildItem -Path "$bdfrHTMLFolder\$Subreddit\*" -File -ErrorAction SilentlyContinue){Remove-Item -Path "$bdfrHTMLFolder\$Subreddit\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null}

## Check for Python modules BDFR and BDFR-HTML
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Checking for BDFR and BDFR-HTML Python modules ..."
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
    Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Installing BDFR Python module ..."
    $bdfrInstallProcess = Start-Process "python.exe" -ArgumentList "-m pip install bdfr --upgrade" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrInstallProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m pip install bdfr --upgrade' returned exit code '$($bdfrInstallProcess.ExitCode)'!"}
    Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Updating BDFR Python module ..."
    $bdfrUpdateProcess = Start-Process "python.exe" -ArgumentList "-m pip install bdfr --upgrade" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrUpdateProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m pip install bdfr --upgrade' returned exit code '$($bdfrUpdateProcess.ExitCode)'!"}
}
if (-not($bdfrhtmlInstalled))
{
    Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Installing BDFR-HTML Python module ..."
    Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Cloning GitHub repository for BDFR-HTML module ..."
    $bdfrhtmlCloneProcess = Start-Process "gh.exe" -ArgumentList "repo clone BlipRanger/bdfr-html" -WorkingDirectory "$bdfrFolderRoot\module_clone" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrhtmlCloneProcess.ExitCode -ne 0){throw "Error: Command: 'gh.exe repo clone BlipRanger/bdfr-html' returned exit code '$($bdfrhtmlCloneProcess.ExitCode)'!"}
    Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Running BDFR-HTML module setup script ..."
    $bdfrhtmlScriptProcess = Start-Process "python.exe" -ArgumentList "setup.py install" -WorkingDirectory "$bdfrFolderRoot\module_clone\bdfr-html" -WindowStyle Hidden -PassThru -Wait
    if ($bdfrhtmlScriptProcess.ExitCode -ne 0)
    {
        Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Error during BDFR-HTML module setup script!"
        Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Attempting alternate Pillow module install via pip ..."
        $pipProcess = Start-Process "pip.exe" -ArgumentList "install pillow" -WorkingDirectory "$bdfrFolderRoot\module_clone\bdfr-html" -WindowStyle Hidden -PassThru -Wait
        if ($pipProcess.ExitCode -ne 0){throw "Error: Command: 'pip.exe install pillow' returned exit code '$($pipProcess.ExitCode)'!"}
        Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Rerunning BDFR-HTML module setup script ..."
        $bdfrhtmlScriptRetryProcess = Start-Process "python.exe" -ArgumentList "setup.py install" -WorkingDirectory "$bdfrFolderRoot\module_clone\bdfr-html" -WindowStyle Hidden -PassThru -Wait
        if ($bdfrhtmlScriptRetryProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe $bdfrFolderRoot\module_clone\setup.py install' returned exit code '$($bdfrhtmlScriptRetryProcess.ExitCode)'!"}
    }
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
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Using BDFR to clone subreddit '$Subreddit' to disk ..."
$logPath = "$bdfrJSONFolder\$Subreddit\log\bdfr_$($Subreddit)_$(Get-Date -f yyyyMMdd_HHmmss).log.txt"
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Status: $logPath"
$bdfrProcess = Start-Process "python.exe" -ArgumentList "-m bdfr clone $bdfrJSONFolder --subreddit $Subreddit --disable-module Youtube --disable-module YoutubeDlFallback --log $logPath" -WindowStyle Hidden -PassThru -Wait
if (-not((Get-Content $logPath -Tail 1) -like "*INFO] - Program complete")){throw "Error: Command: 'python.exe -m bdfr clone $bdfrJSONFolder --subreddit $Subreddit --disable-module Youtube --disable-module YoutubeDlFallback --log $logPath' returned exit code '$($bdfrProcess.ExitCode)'!"} #this process often throws errors, so check for the program completion string in the tail of the log file

## BDFR-HTML: Process Cloned Subreddit to HTML
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Using BDFR-HTML to generate subreddit HTML pages ..."
$bdfrhtmlProcess = Start-Process "python.exe" -ArgumentList "-m bdfrtohtml --input_folder $bdfrJSONFolder\$Subreddit --output_folder $bdfrHTMLFolder\$Subreddit" -WindowStyle Hidden -PassThru -Wait
if ($bdfrhtmlProcess.ExitCode -ne 0){throw "Error: Command: 'python.exe -m bdfrtohtml --input_folder $bdfrJSONFolder\$Subreddit --output_folder $bdfrHTMLFolder\$Subreddit' returned exit code '$($bdfrhtmlProcess.ExitCode)'!"}

## Replace generated index.html <title> with subreddit name
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Updating generated index.html, adding subreddit to title ..."
$indexLineFound = $false #skip -like operator
$indexFile = Get-Item "$bdfrHTMLFolder\$Subreddit\index.html"
$indexReader = New-Object -TypeName 'System.IO.StreamReader' -ArgumentList $indexFile
$indexOutput = New-Object -TypeName 'System.Collections.ArrayList'
while (-not($indexReader.EndOfStream))
{
    $indexLine = $indexReader.ReadLine()
    if ($indexLineFound){[void]$indexOutput.Add("$indexLine"); continue}
    if ($indexLine -like "*<title>*")
    {
        [void]$indexOutput.Add("        <title>/r/$Subreddit Archive</title>")
        $indexLineFound = $true
    }
    else {[void]$indexOutput.Add("$indexLine")}
}
$indexReader.Close(); $indexOutput | Set-Content $indexFile -Encoding 'UTF8' -Force

## Delete media files over 2MB threshold
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Deleting media folder files over 2MB in HTML output folder ..."
(Get-ChildItem -Path "$bdfrHTMLFolder\$Subreddit\media" | Where-Object {(($_.Length)/1MB) -gt 2}).FullName | ForEach-Object {Remove-Item -Path $_ -Force -ErrorAction SilentlyContinue}

## End
$stopWatch.Stop()
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Finished! Run time was $($stopWatch.Elapsed.Hours) hour(s) $($stopWatch.Elapsed.Minutes) minute(s) $($stopWatch.Elapsed.Seconds) second(s)."

## Open Completed HTML Folder
Write-Output "[$(Get-Date -f HH:mm:ss.fff)] Opening subreddit HTML output folder ..."
Start-Process "$bdfrHTMLFolder\$Subreddit\"
exit 0