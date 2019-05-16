#I’m useless without a cup of coffee in the morning.
function Get-MorningCoffee
{
    $VerbosePreference = 'Continue' #throw "Error: string for output does not contain the correct word count!"
    Write-Verbose "Prepping Coffee Machine ..."
    $outputObj = New-Object PSObject #gather output into an object because reasons
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '1' -Value (Get-FirstConjunction)
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '2' -Value (Get-CandidateEffectiveness)
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '3' -Value 'without'
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '4' -Value (Get-Letter)
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '5' -Value 'cup of coffee'
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '6' -Value 'in the'
    Add-Member -InputObject $outputObj -MemberType NoteProperty -Name '7' -Value (Get-TimeOfDay)
    for ($i = 1; $i -le 7; $i++)
    {
        if (-not([string]::IsNullOrEmpty($outputObj.$i)))
        {
            $outputString = ($outputString + ($outputObj.$i + " "))
        }
        else {throw "Error: output object is missing required property '$i'!"}
    }
    "`n$outputString" #host output
}

#I'm
function Get-FirstConjunction
{
    Write-Verbose "Dumping Beans Into Grinder ..."
    $conj = 'I'+"'"+'m'
    return $conj
}

#Useless
function Get-CandidateEffectiveness
{
    Write-Verbose "Grinding Coffee Beans ..."
    $URI = 'https://en.wikipedia.org/wiki/Donald_Trump'
    try {$page = Invoke-WebRequest $URI -UseBasicParsing -TimeoutSec 10}
    catch {throw "Error!"}
    $citeID = 272 #to really do this 'right', i'd check different citeIDs if the intended word wasn't found.. as the URI is rapidly being edited
    $citeIndex = $page.Content.IndexOf("cite_ref-$citeID")
    $word = $page.Content.SubString(($citeIndex - 18), 7) #grab 7 letter word before citation ID
    return $word
}

#A
function Get-Letter
{
    Write-Verbose "Brewing Coffee ..."
    $numGuessed = $false
    $min = 0
    $max = 1000
    while (!$numGuessed)
    {
        #"min: $min, max: $max, num: $num"
        $num = Get-Random -Minimum $min -Maximum $max
        if ($num -le ($min+5)) #increase minimum if guessed
        {
            $min = $num
        }
        if ($num -ge ($max-5)) #decrease maximum if guessed, ridiculously inefficient infinite loop protection
        {
            $max = $num
        } 
        if ($num -eq 97)
        {
            $numGuessed = $true
        }
    }
    return [char]$num
}

#Morning
function Get-TimeOfDay
{
    Write-Verbose "Pouring Coffee ..."
    switch ([int]((Get-Date).TimeOfDay.Hours))
    {
        {($_ -in (6..11))}{$timeWindow = 'morning'}
        {($_ -in (12..17))}{$timeWindow = 'afternoon'}
        {($_ -in (18..23))}{$timeWindow = 'evening'}
    }
    if (($timeWindow -eq 'morning') -or ($timeWindow -eq 'afternoon'))
    {
        return 'morning.'
    }
    else {throw 'Error: coffee only advised in the morning/afternoon!'}
}

Get-MorningCoffee