## Init
Add-Type -AssemblyName System.Windows.Forms

## Main Window
$UI = New-Object Windows.Forms.Form
$UI.Text = 'Milliman'
$UI.MinimizeBox = $False
$UI.MaximizeBox = $False
$UI.Width = 512
$UI.Height = 210
$UI.StartPosition = "CenterScreen"
$UI.Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Regular) #Regular, Bold, Italic, Underline, Strikeout
$UI.Icon = New-Object System.Drawing.Icon("$PSScriptRoot\milliman.ico")

## Action Functions
function Get-NewestTweetSnips
{
    $URL = 'https://twitter.com/millimaneb'
    try {$page = Invoke-WebRequest $URL -UseBasicParsing -TimeoutSec 8}
    catch {throw "Error: failed to retrieve twitter feed page!"}
    $sepString = 'data-aria-label-part="0">' #this <p> class string preceeds the ascii text portion of each tweet
    $snip = $page.Content.SubString($page.Content.IndexOf("$sepString"), 140)
    $cleanSnip = $snip.SubString(($sepString.length),($snip.IndexOf("<a href")-($sepString.length)))
    return $cleanSnip
}

$nearbyScripts = (gci $PSScriptRoot\..\..\ -Recurse -Include '*.ps1').FullName
function Start-LaunchSelection
{
    if ($launchCombobox.SelectedIndex -lt 0){$selectedItem = $null}
    else{$selectedItem = $nearbyScripts[$launchCombobox.SelectedIndex]}
    Update-Status "Launching $(Split-Path $selectedItem -Leaf) ..."
    Invoke-Expression $selectedItem
}

function Start-UpdateConfig {Update-Status 'NYI'}

function Update-Status
{
    param([string]$updateString)
    $StatusBarPanel.Text = $updateString  
    $StatusBarPanel.ToolTiptext = $StatusBarPanel.Text
}

## Status Button
$statusButton = New-Object Windows.Forms.Button
$statusButton.Text = "Status"
$statusButton.add_click({ Update-Status ('StatusBar Update: '+(Get-Date -f 'y:MM:dd:HH:mm:ss.ffffff')) })
$statusButton.Location = New-Object Drawing.Point 10,13
$statusButton.Size = New-Object Drawing.Point 85,35
$UI.Controls.Add($statusButton)

## Tweet Snip Button
$tweetButton = New-Object Windows.Forms.Button
$tweetButton.Text = "Tweets"
$tweetButton.add_click({ Update-Status (Get-NewestTweetSnips) })
$tweetButton.Location = New-Object Drawing.Point 100,13
$tweetButton.Size = New-Object Drawing.Point 90,35
$UI.Controls.Add($tweetButton)

## Launch Button
$launchButton = New-Object Windows.Forms.Button
$launchButton.Text = "Launch"
$launchButton.add_click({ Start-LaunchSelection })
$launchButton.Location = New-Object Drawing.Point 10,64
$launchButton.Size = New-Object Drawing.Point 90,26
$UI.Controls.Add($launchButton)

## Launch Combobox
$launchCombobox = New-Object System.Windows.Forms.Combobox
$launchCombobox.Text = 'Select Script ...'
$launchCombobox.Name = "launchList"
$launchCombobox.Width = 380
$launchCombobox.Height = 32
$launchCombobox.Location = New-Object Drawing.Point 99,65
Split-Path $nearbyScripts -Leaf | % {$launchCombobox.Items.Add($_) | Out-Null} #populate
$UI.Controls.Add($launchCombobox)

## Update Button
$updateButton = New-Object Windows.Forms.Button
$updateButton.Text = "Update"
$updateButton.add_click({ Start-UpdateConfig })
$updateButton.Location = New-Object Drawing.Point 10,94
$updateButton.Size = New-Object Drawing.Point 90,26
$UI.Controls.Add($updateButton)

## Update Combobox
$updateCombobox = New-Object System.Windows.Forms.Combobox
$updateCombobox.Text = 'NYI'
$updateCombobox.Name = "updateList" 
$updateCombobox.Width = 380
$updateCombobox.Height = 32
$updateCombobox.Location = New-Object Drawing.Point 99,95
$updateCombobox.Items.Add('NYI')
$UI.Controls.Add($updateCombobox)

## Status Group Box
$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Left = 5
$statusGroup.Top = 0
$statusGroup.Width = 190
$statusGroup.Height = 54
$UI.Controls.Add($statusGroup)

## Launch Group Box
$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Left = 5
$statusGroup.Top = 51
$statusGroup.Width = 480
$statusGroup.Height = 75
$UI.Controls.Add($statusGroup)

## Status Bar
$StatusBar = New-Object System.Windows.Forms.StatusBar
$StatusBarPanel = New-Object System.Windows.Forms.StatusBarPanel
$StatusBarPanel.AutoSize = [System.Windows.Forms.StatusBarPanelAutoSize]::Contents
$StatusBarPanel.Text = "Ready ..."
$StatusBarPanel.ToolTipText = $StatusBarPanel.Text
$StatusBar.ShowPanels = $True 
$StatusBar.Panels.Add($StatusBarPanel)
$UI.Controls.Add($StatusBar)

## Display
$UI.ShowDialog()