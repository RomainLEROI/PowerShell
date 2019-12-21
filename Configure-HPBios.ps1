
Function Get-BiosConfig($Setting) {

    Try {

        $Config = (Get-WmiObject -Query ("Select CurrentValue,PossibleValues From HP_BIOSEnumeration Where Name='{0}'" -f $Setting) -Namespace ROOT/HP/InstrumentedBIOS -ErrorAction SilentlyContinue) 

        Return $Config

    } Catch {

        Return $null

    }

}


Function Apply-BiosConfig($BiosConfig) {

    Write-CMLog -Log $LogFilePath -Value "[+] Applying bios configuration" -Severity 1

    foreach ($Item in $BiosConfig.GetEnumerator() | Sort Key) {

        $ItemIndex = $Item.Key

        $Setting = (($Item.Value).Split(":")[0]).TrimEnd()

        $DesiredValue = ($Item.Value).Split(":")[1].TrimStart()

        $Config = Get-BiosConfig -Setting $Setting

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

                    $ResultCode = Set-BiosValue -Setting $Setting -Value $DesiredValue

                    if ($ReturnCode -eq 0) {

                        $BiosConfig.Remove($ItemIndex)

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

    }

    Return $BiosConfig

}


Function Set-BiosValue($Setting, $Value) {

    Try {

        Write-CMLog -Log $LogFilePath -Value "Trying to configure $Setting without password" -Severity 1

        $ReturnCode = $($Bios.SetBIOSSetting($Setting, $Value, "<utf-16/>")).return

        if ($ReturnCode -eq 0) {

            Write-CMLog -Log $LogFilePath -Value "$Setting was successfully configured" -Severity 1

        } else {

            Write-CMLog -Log $LogFilePath -Value "Failed to configure $Setting" -Severity 3

            $ReturnCode = $null

        }

        Return $ReturnCode

    } Catch {

        Write-CMLog -Log $LogFilePath -Value "Something went wrong while setting bios password" -Severity 3

        Return $ErrorList.FailedToSetBiosValue

    }

}


Function Write-CMLog($LogFilePath, $Value, $Severity) {

    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))

    $Date = (Get-Date -Format "MM-dd-yyyy")

    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)

    $LogText = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f
               $Value, $Time, $Date, [System.IO.Path]::GetFileName($LogFilePath), $Context, $Severity, $PID
	
    Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop

}


Function Get-HPBios() {

    Try { 

        $Bios = Get-WmiObject -Namespace ROOT/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface -ErrorAction SilentlyContinue
        
        Return $Bios

    } Catch { 
        
        Return $null
            
    }

}


Function Get-TSEnvironment() {

    Try { 

        $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        
        Return $TSEnvironment

    } Catch { 
        
        Return $null
            
    }

}


$BiosConfig = @{
   
    1  = "Configure Legacy Support and Secure Boot : Legacy Support Disable and Secure Boot Enable"
    2  = "Virtualization Technology (VTx) : Disable"
    3  = "Virtualization Technology for Directed I/O (VTd) : Disable"
    4  = "LAN/WLAN Switching : Enable"
    5  = "LAN / WLAN Auto Switching : Enabled"
    6  = "LAN / WLAN Auto Switching : Enable"
    7  = "UEFI Boot Options : Enable"
    8  = "Always Prompt for HP SpareKey Enrollment : Disable"
    9  = "HP SpareKey : Disable"
    10 = "TPM Device : Available"
    11 = "Embedded Security Device : Device available"
    12 = "TPM State : Enable"
    13 = "Clear TPM : No"
    14 = "TPM Activation Policy : No prompts"
    15 = "Embedded Security Activation Policy : No prompts"
    16 = "Reset of TPM from OS : Enable"
    17 = "Reset of Embedded Security Device through OS : Enable"
    18 = "OS Management of TPM : Enable"
    19 = "OS management of Embedded Security Device : Enable"
    20 = "Activate TPM On Next Boot : Enable"
    21 = "Activate Embedded Security On Next Boot : Enable"
    22 = "Boot Mode : UEFI Native (Without CSM)"
    23 = "SecureBoot : Enable"
    24 = "Secure Boot : Enable"
    25 = "Setup Password : Password"

}

$TSEnvironment = Get-TSEnvironment

$LogName = "ConfigureBios.log"

$LogFolder = [System.String]::Empty
     
if ($TSEnvironment -ne $Null) {

    $LogFolder = $TSEnvironment.Value("_SMSTSLogPath")

} else {

    $LogFolder = Join-Path -Path $env:Windir -ChildPath "Temp"

}

$LogFilePath = Join-Path -Path $LogFolder -ChildPath $LogName

$Bios = Get-HPBios

if ($null -eq $Bios) {

    [Environment]::Exit(10)

}

$AppliedConfig = Apply-BiosConfig -BiosConfig $BiosConfig

if ($AppliedConfig.Count -ne 0) {

    [Environment]::Exit(20)

}
