
<#
Update-Bios.xml

<?xml version="1.0" encoding="iso-8859-1"?>
<Configuration>

	<!--
 	<FlashTool>HPBIOSUPDREC64</FlashTool>
	<BiosFile>L71_0146.bin</BiosFile>
  <BiosType>L71</BiosType>
  <BiosVersion>01.46</BiosVersion>

 	<FlashTool>HpqFlash</FlashTool>
	<BiosFile>rom.cab</BiosFile>
  <BiosType>L01</BiosType>
  <BiosVersion>02.75</BiosVersion>
	-->

 	<FlashTool>HpFirmwareUpdRec64</FlashTool>
	<BiosFile>Q78_010801.bin</BiosFile>
  <BiosType>Q78</BiosType>
  <BiosVersion>01.08.01</BiosVersion>

</Configuration>
#>

Param(

    [Parameter(Mandatory=$false)]
    [String]$Pwd = [String]::Empty
 
)


Function Write-CMLog($LogFilePath, $Value, $Severity) {

    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))

    $Date = (Get-Date -Format "MM-dd-yyyy")

    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)

    $LogText = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f
               $Value, $Time, $Date, [System.IO.Path]::GetFileName($LogFilePath), $Context, $Severity, $PID
	
    Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop

}


Function Get-TSEnvironment() {

    Try { 

        $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        
        Return $TSEnvironment

    } Catch { 
        
        Return $Null
            
    }

}


$WorkingDir = Split-Path $Script:MyInvocation.MyCommand.Path

$TSEnvironment = Get-TSEnvironment

if ($TSEnvironment -ne $Null) {

    $FromTS = $True

    $Pwd = $TSEnvironment.Value("OSDHPBiosPassword")

    $LogFolder = $TSEnvironment.Value("_SMSTSLogPath")

} else {

    $TSEnvironment = $null

    $FromTS = $False
            
    $LogFolder = "$env:Windir\Temp"

}

$LogFilePath = "$LogFolder\Update-Bios.log"

$XmlPath = "$WorkingDir\Update-Bios.xml"

if (!(Test-Path -Path $XmlPath)) {

    Write-CMLog -Log $LogFilePath -Value "$XmlPath was not found" -Severity 3

    [Environment]::Exit(10)

}

if ([Environment]::OSVersion.Version.Major -ne 10) {

    Write-CMLog -Log $LogFilePath -Value "Script supports only Windows 1O computers" -Severity 3

    [Environment]::Exit(20)

}

Try {

    $ComputerSystem = Get-WmiObject -Query "SELECT Manufacturer FROM Win32_ComputerSystem" -Namespace "ROOT\cimv2" -ErrorAction SilentlyContinue

    if (($ComputerSystem.Manufacturer -ne "HP") -and ($ComputerSystem.Manufacturer -ne "Hewlett-Packard")) {

        Write-CMLog -Log $LogFilePath -Value "Script supports only Hewlett-Packard computers" -Severity 3

        [Environment]::Exit(30)

    }

} Catch {

    Write-CMLog -Log $LogFilePath -Value "Something went wrong while fetching Manufacturer" -Severity 3

    Write-CMLog -Log $LogFilePath -Value $_.Exception.Message -Severity 3

    [Environment]::Exit(30)

}

[xml] $Xml = Get-Content -Path $XmlPath -ErrorAction SilentlyContinue

$FlashTool = $Xml.Configuration.FlashTool

$BiosFile = $Xml.Configuration.BiosFile

$BiosType = $Xml.Configuration.BiosType

$BiosVersion = $Xml.Configuration.BiosVersion

if ([String]::IsNullOrEmpty($FlashTool) -or [String]::IsNullOrEmpty($BiosFile) -or [String]::IsNullOrEmpty($BiosType) -or [String]::IsNullOrEmpty($BiosVersion)) {

    Write-CMLog -Log $LogFilePath -Value "Missing $XmlPath file informations" -Severity 3

    [Environment]::Exit(40)

}

$CurrentBios = (Get-WmiObject -Query "SELECT SMBIOSBIOSVERSION FROM Win32_BIOS" -Namespace "ROOT\cimv2" -ErrorAction SilentlyContinue).SMBIOSBIOSVERSION

$CurrentBiosType = $CurrentBios.Substring(0,3)

$CurrentBiosVersion = ([Text.RegularExpressions.Regex]::Match($CurrentBios, '\d+(\.\d+)+')).Value.Trim()

if ([String]::IsNullOrEmpty($CurrentBiosType) -or [String]::IsNullOrEmpty($CurrentBiosVersion)) {

    Write-CMLog -Log $LogFilePath -Value "Failed to fetch current bios informations" -Severity 3

    [Environment]::Exit(50)

}

if ($BiosType.ToUpper() -ne $CurrentBiosType.ToUpper()) {

    Write-CMLog -Log $LogFilePath -Value "Bios type mismatch" -Severity 3

    [Environment]::Exit(60)

}

if ([Version] $CurrentBiosVersion -ge [Version] $BiosVersion) {

    Write-CMLog -Log $LogFilePath -Value "Bios current version is already up to date" -Severity 1

    [Environment]::Exit(0)

}

$BiosFile = "$WorkingDir\$BiosFile"

Write-CMLog -Log $LogFilePath -Value "Script is configured to use $BiosFile" -Severity 1

Switch ($FlashTool.ToUpper()) {

    "HPFIRMWAREUPDREC64" {

        $Args = "-s -b -r"

    } "HPBIOSUPDREC64" {

        $Args = "-f$BiosFile -s -b -r"

    } "HPQFLASH" {

        $Args = "-f$BiosFile -s"

    }

}

$Log = "$WorkingDir\$FlashTool.log"

$FlashTool = "$WorkingDir\$FlashTool.exe"

if (!(Test-Path -Path $FlashTool)) {

    Write-CMLog -Log $LogFilePath -Value "$FlashTool was not found" -Severity 3

    [Environment]::Exit(70)
}

Write-CMLog -Log $LogFilePath -Value "Script is configured to use $FlashTool" -Severity 1

if (![String]::IsNullOrEmpty($Pwd)) {

    $HPQPswd64 = "$WorkingDir\HPQPswd64.exe"

    if (!(Test-Path -Path $HPQPswd64)) {

        Write-CMLog -Log $LogFilePath -Value "$HPQPswd64 was not found" -Severity 3

        [Environment]::Exit(80)
    }
          
    $BiosPwdFile = "$WorkingDir\Pwd.bin"

    $Args = "$Args -p$BiosPwdFile"

    Start-Process -FilePath $HPQPswd64 -ArgumentList "/s /f$([char]34)$BiosPwdFile$([char]34) /p$([char]34)$Pwd$([char]34)" -WorkingDirectory $WorkingDir -Wait -PassThru

    if (!(Test-Path $BiosPwdFile)) {

        Write-CMLog -Log $LogFilePath -Value "$BiosPwdFile was not found" -Severity 3

        [Environment]::Exit(90)
        
    } 

    Write-CMLog -Log $LogFilePath -Value "Script is configured to use $BiosPwdFile" -Severity 1
               
}
    
Try {

    $BitlockerVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue

    if ($null -ne $BitlockerVolume) {

        if ($BitlockerVolume.ProtectionStatus -eq "On") {

            Write-CMLog -Log $LogFilePath -Value "Bitlocker protection is currently enabled on $env:SystemDrive" -Severity 2

            Write-CMLog -Log $LogFilePath -Value "Disabling Bitlocker protectors on $env:SystemDrive" -Severity 1
                   
            Try {

                Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1 -ErrorAction SilentlyContinue

                Start-Sleep -Seconds 5

                if ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).ProtectionStatus -eq "Off") {

                    Write-CMLog -Log $LogFilePath -Value "Bitlocker protectors was successfully disabled on $env:SystemDrive for one reboot" -Severity 1

                } else {

                    Write-CMLog -Log $LogFilePath -Value "Failed to disable Bitlocker protectors on $env:SystemDrive" -Severity 3

                    [Environment]::Exit(90)

                }

            } Catch {

                Write-CMLog -Log $LogFilePath -Value "Something went wrong while disabling Bitlocker protectors on $env:SystemDrive" -Severity 3

                Write-CMLog -Log $LogFilePath -Value $_.Exception.Message -Severity 3

                [Environment]::Exit(90) 

            }


        } else {

            Write-CMLog -Log $LogFilePath -Value "Bitlocker protection is currently disabled on $env:SystemDrive" -Severity 1

        }

    } else {

        Write-CMLog -Log $LogFilePath -Value "Failed to fetch Bitlocker volume protection status on $env:SystemDrive" -Severity 3

        [Environment]::Exit(100) 

    }

} Catch {

    Write-CMLog -Log $LogFilePath -Value "Something went wrong while fetching Bitlocker volume protection status on $env:SystemDrive" -Severity 3

    Write-CMLog -Log $LogFilePath -Value $_.Exception.Message -Severity 3

    [Environment]::Exit(100) 

}
   
$ExitCode = (Start-Process -FilePath $FlashTool -ArgumentList $Args -WorkingDirectory $WorkingDir -Wait -PassThru).ExitCode

if (Test-Path -Path $Log) {

    Move-Item -Path $Log -Destination "$LogFolder\HPBIOSUPDATE.log" -Force

    Write-CMLog -Log $LogFilePath -Value "Bios update tool log was moved to $LogFolder\HPBIOSUPDATE.log" -Severity 1

}

Switch ([Convert]::ToInt32($ExitCode)) {

    0 { 

        Write-CMLog -Log $LogFilePath -Value "Bios was successfully updated" -Severity 1

        if ($FromTS) { $TSEnvironment.Value("OSDBiosUpdated") = "True" }
                                                  
    } 3010 { 

        Write-CMLog -Log $LogFilePath -Value "Bios was successfully updated, reboot required" -Severity 1

        if ($FromTS) { 
        
            $TSEnvironment.Value("OSDBiosUpdated") = "True" 

            $ExitCode = 0

        }
                             
    } default { 
            
        Write-CMLog -Log $LogFilePath -Value "Bios update failed with error $ExitCode" -Severity 3

        if ($FromTS) { $TSEnvironment.Value("OSDBiosUpdated") = "False" }
                
    }

}

[Environment]::Exit($ExitCode)
