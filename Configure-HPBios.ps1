<#
$Password = "password"

$BiosConfig = @{
   
    1  = "Configure Legacy Support and Secure Boot : Legacy Support Disable and Secure Boot Enable"
    2  = "Virtualization Technology (VTx) : Disable"
    3  = "Virtualization Technology for Directed I/O (VTd) : Disable"
    4  = "LAN/WLAN Switching : Enable"
    5  = "LAN / WLAN Auto Switching : Enabled"
    6  = "LAN / WLAN Auto Switching : Enable"
    7  = "UEFI Boot Options : Enable"
    8  = "Boot Mode : UEFI Native (Without CSM)"
    9  = "SecureBoot : Enable"
    10 = "Secure Boot : Enable"
    11 = "Setup Password : $Password"

}

Configure-HPBios.ps1 -BiosConfig $BiosConfig

$BiosConfig = @{
   
    1  = "UEFI Boot Options : Enable"
    2  = "Always Prompt for HP SpareKey Enrollment : Disable"
    3  = "HP SpareKey : Disable"
    4  = "TPM Device : Available"
    5  = "Embedded Security Device : Device available"
    6  = "TPM State : Enable"
    7  = "Clear TPM : No"
    8  = "TPM Activation Policy : No prompts"
    9  = "Embedded Security Activation Policy : No prompts"
    10 = "Reset of TPM from OS : Enable"
    11 = "Reset of Embedded Security Device through OS : Enable"
    12 = "OS Management of TPM : Enable"
    13 = "OS management of Embedded Security Device : Enable"
    14 = "Activate TPM On Next Boot : Enable"
    15 = "Activate Embedded Security On Next Boot : Enable"

}

Configure-HPBios.ps1 -BiosConfig $BiosConfig -Password $Password
#>

Param (

    [Parameter(Mandatory = $true)]
    [HashTable] $BiosConfig,

    [Parameter(Mandatory = $false)]
    [String] $Password = [String]::Empty,
    
    [Parameter(Mandatory = $false)]
    [String] $LogName = "ConfigureBios.log"

)

Function Write-CMLog {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $LogFilePath,

        [Parameter(Mandatory = $true)]
        [String] $Value,

        [Parameter(Mandatory = $true)]
        [Int] $Severity

    )

    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))

    $Date = (Get-Date -Format "MM-dd-yyyy")

    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)

    $LogText = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f
               $Value, $Time, $Date, [System.IO.Path]::GetFileName($LogFilePath), $Context, $Severity, $PID
	
    Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop

}


Try { 

    $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        
} Catch { 
        
    $TSEnvironment = $null
            
}
  
if ($null -ne $TSEnvironment) {

    $LogFolder = $TSEnvironment.Value("_SMSTSLogPath")

} else {

    $LogFolder = Join-Path -Path $env:Windir -ChildPath "Temp"

}

$LogFilePath = Join-Path -Path $LogFolder -ChildPath $LogName

Try { 

    $Bios = Get-WmiObject -Namespace ROOT/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface -ErrorAction SilentlyContinue
        
} Catch { 
        
    $Bios = $null
            
}

if ($null -eq $Bios) {

    [Environment]::Exit(10)

}

Write-CMLog -Log $LogFilePath -Value "[+] Applying bios configuration" -Severity 1

foreach ($Item in $BiosConfig.GetEnumerator() | Sort Key) {

    $ItemIndex = $Item.Key

    $Setting = (($Item.Value).Split(":")[0]).TrimEnd()

    $DesiredValue = ($Item.Value).Split(":")[1].TrimStart()

    Try {

        $Config = (Get-WmiObject -Query ("Select CurrentValue,PossibleValues From HP_BIOSEnumeration Where Name='$Setting'") -Namespace ROOT/HP/InstrumentedBIOS -ErrorAction SilentlyContinue) 

    } Catch {

        $Config = $null

    }

    if ($null -ne $Config) {

        $CurrentValue = $Config.CurrentValue

        Write-CMLog -Log $LogFilePath -Value "Testing [$Setting], current value is [$CurrentValue], desired value is [$DesiredValue]" -Severity 1

        if ($CurrentValue -ne $DesiredValue) {

            $PossibleValues = @()

            foreach ($Item in $($Config.PossibleValues -replace '[{}]', [String]::Empty)) {

                $PossibleValues += , $Item.TrimStart()

            }

            if ($PossibleValues.Contains($DesiredValue)) {

                Write-CMLog -Log $LogFilePath -Value "Desired value [$DesiredValue] is correct" -Severity 1

                Try {

                    Write-CMLog -Log $LogFilePath -Value "Trying to configure $Setting without password" -Severity 1

                    if (![String]::IsNullOrEmpty($Password)) {

                        $ReturnCode = $($Bios.SetBIOSSetting($Setting, $DesiredValue, "<utf-16/>" + $Password)).return

                    } else {

                        $ReturnCode = $($Bios.SetBIOSSetting($Setting, $DesiredValue, "<utf-16/>")).return

                    }

                } Catch {

                    Write-CMLog -Log $LogFilePath -Value "Something went wrong while setting bios password" -Severity 3

                    $ReturnCode = 10

                } Finally {

                    if ($ReturnCode -eq 0) {

                        $BiosConfig.Remove($ItemIndex)

                        Write-CMLog -Log $LogFilePath -Value "$Setting was successfully configured" -Severity 1

                    } else {

                        Write-CMLog -Log $LogFilePath -Value "Failed to configure $Setting" -Severity 3

                    }

                }

            } else {

                Write-CMLog -Log $LogFilePath -Value "No match for desired value [$DesiredValue]" -Severity 2
      
                $BiosConfig.Remove($ItemIndex)

            }

        } else {

            Write-CMLog -Log $LogFilePath -Value "Desired value [$DesiredValue] is already set" -Severity 1

            $BiosConfig.Remove($ItemIndex)

        }

    } else {

        Write-CMLog -Log $LogFilePath -Value "No match for setting [$Setting]" -Severity 2

        $BiosConfig.Remove($ItemIndex)

    }

}

if ($BiosConfig.Count -eq 0) {

    Write-CMLog -Log $LogFilePath -Value "Bios configuration was successfully applied" -Severity 1

} else {

    Write-CMLog -Log $LogFilePath -Value "$($BiosConfig.Count) bios configuration was not applied" -Severity 3

    foreach ($Item in $BiosConfig) {

        $Setting = (($Item.Value).Split(":")[0]).TrimEnd()

        Write-CMLog -Log $LogFilePath -Value "$Setting was not applied" -Severity 3

    }
    
    [Environment]::Exit(20)

}
