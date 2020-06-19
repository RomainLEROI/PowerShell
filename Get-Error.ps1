Param (

    [Parameter(Mandatory=$true)]
    [Int] $Code
)


$BinaryCode = [Convert]::ToString($Code, 2)

$HexCode = "0x$([Convert]::ToString($Code, 16))"

$WindowsMsg = ([ComponentModel.Win32Exception]$Code).Message

$KeyPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\ConfigMgr10\Setup"

$ValueName = "UI Installation Directory"

$ConsolePath = (Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue).$ValueName

if ($null -ne $ConsolePath) {

    if (!([Management.Automation.PSTypeName]'SrsResources.Localization').Type) {

        Add-Type -Path "$ConsolePath\bin\SrsResources.dll"

    }

    $CmMsg = [SrsResources.Localization]::GetErrorMessage($Code, "fr-FR")

    if ($null -eq $Message) {

        $CmMsg = "Unknown Error ($HexCode)"

    }

} else {

    $CmMsg = "CM console path not found"

}

$Ordered = @{

    "IntCode" = $Code
    "HexCode" = $HexCode
    "BinCode"  = $BinaryCode
    "WindowsMsg" = $WindowsMsg
    "CmMsg" = $CmMsg                           

}

Return New-Object -TypeName PSObject -Property $Ordered
