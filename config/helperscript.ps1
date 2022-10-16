#This file is meant to assist in building out the json files inside this folder.

<#
    Applications.json
    -----------------
    This file holds all the winget commands to install the applications.
    It also has the ablity to expact to other frameworks (IE Choco).
    You can also add multiple winget commands by seperating them with ;

    The structure of the json is as follows

{
"install": {
    "Name of Button": {
    "winget": "Winget command"
    },
}

#>

#Modify the variables and run his code. It will import the current file and add your addition. From there you can create a pull request.

$NameofButton = "Installadobe"
$WingetCommand = "Adobe.Acrobat.Reader.64-bit"

$ButtonToAdd = New-Object psobject
$jsonfile = Get-Content ./config/applications.json | ConvertFrom-Json

Add-Member -InputObject $ButtonToAdd -MemberType NoteProperty -Name "Winget" -Value $WingetCommand
Add-Member -InputObject $jsonfile.install -MemberType NoteProperty -Name $NameofButton -Value $ButtonToAdd

$jsonfile | ConvertTo-Json | Out-File ./config/applications.json

