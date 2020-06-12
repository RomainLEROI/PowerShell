param (

    [Parameter(Mandatory = $false)]
    [String] $DriverPackagePath = [String]::Empty,

    [Parameter(Mandatory = $false)]
    [ValidateScript({[IO.Path]::GetExtension($_) -eq '.log'})]
    [String] $LogName = "Install-Drivers.log"

)


function Write-CMLog() {

    param (

        [Parameter(Mandatory = $true)]
        [String] $LogFilePath,

        [Parameter(Mandatory = $true)]
        [String] $Value,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1,3)]
        [Int] $Severity


    )

    if (!(Test-Path -Path $LogFilePath)) {

        $FileStream = [IO.FileStream]::new($LogFilePath, [IO.FileMode]::CreateNew)

    } else {

        $FileStream = [IO.FileStream]::new($LogFilePath, [IO.FileMode]::Append)

    }

    $StreamWriter = [IO.StreamWriter]::new($FileStream)

    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))

    $Date = (Get-Date -Format "MM-dd-yyyy")

	$Context = $([Security.Principal.WindowsIdentity]::GetCurrent().Name)

    $LogText = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f $Value, $Time, $Date, [IO.Path]::GetFileName($LogFilePath), $Context, $Severity, $PID
	
    $StreamWriter.WriteLine($LogText)

    $StreamWriter.Close()
    $StreamWriter.Dispose()

    $FileStream.Close()
    $FileStream.Dispose()

}


function Get-TSEnvironment() {

    try { 

        $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        
        Return $TSEnvironment

    } catch { 
        
        Return $null
            
    }

}


function Get-IniContent () {

    param (

        [Parameter(Mandatory = $true)]
        [String] $FilePath

    )

    $Ini = @{}

    switch -regex -file $FilePath {

        “^\[(.+)\]” {

            # Section

            $Section = $Matches[1]
            $Ini[$Section] = @{}
            $CommentCount = 0

        } “^(;.*)$” {

            # Comment

            $Value = $Matches[1]
            $CommentCount = $CommentCount + 1
            $Name = “Comment” + $CommentCount

            if ($null -ne $Section) {

                $Ini[$Section][$Name] = $Value

            }          

        } “(.+?)\s*=(.*)” {

            # Key

            $Name,$Value = $Matches[1..2]

            if ($null -ne $Section) {

                $Ini[$Section][$Name] = $Value

            }

        } default {

            continue

        }

    }

    return $Ini
}


function Write-AllLines() {

    param (

        [Parameter(Mandatory = $true)]
        [String] $Output,

        [Parameter(Mandatory = $true)]
        [String] $LogFilePath

    )

    if (![String]::IsNullOrEmpty($Output)) {

        if ($Output.Contains([Environment]::NewLine)) {

            foreach ($Line in $Output.Split([Environment]::NewLine)) {

                if (![String]::IsNullOrEmpty($Line)) {

                    Write-CMLog -Log $LogFilePath -Value $Line -Severity 1 
                }

            }

        } else {

            Write-CMLog -Log $LogFilePath -Value $Output -Severity 1

        }

    }

}


function Create-Process() {

    param (

        [Parameter(Mandatory = $true)]
        [String] $File,

        [Parameter(Mandatory = $true)]
        [String] $Arguments,

        [Parameter(Mandatory = $false)]
        [String] $WorkingDir = [String]::Empty,

        [Parameter(Mandatory = $true)]
        [String] $Log

    )

    $Process = New-Object -TypeName Diagnostics.Process

    $Process.StartInfo.UseShellExecute = $false

    $Process.StartInfo.RedirectStandardOutput = $true

    $Process.StartInfo.FileName = $File

    if (![String]::IsNullOrEmpty($Arguments)) {

        $Process.StartInfo.Arguments = $Arguments

    }

    if (![String]::IsNullOrEmpty($WorkingDir)) {

        $Process.StartInfo.WorkingDirectory = $WorkingDir

    }   

    $Process.Start() | Out-Null

    $Output = $Process.StandardOutput.ReadToEnd()

    $Process.WaitForExit()

    $ExitCode = $Process.ExitCode

    Write-AllLines -Output $Output -LogFilePath $Log

    return $ExitCode

}


function Get-DriverCatalog {

    param (

        [Parameter(Mandatory = $true)]
        [Hashtable] $IniContent

    )

    try {

        $DriverCatalog = $IniContent["Version"]["CatalogFile"].ToString().Trim()

        if (![String]::ISNullOrEmpty($DriverCatalog)) {

            if ($DriverCatalog.Contains(';')) {

                $DriverCatalog = $DriverCatalog.Split(';')[0].ToString().Trim()

            } 

            if (($DriverCatalog.Contains('%')) -and (($DriverCatalog.ToCharArray() | Where-Object {$_ -eq '%'} | Measure-Object).Count -eq 2)) {

                foreach ($Alias in $DriverCatalog) {

                    if (![String]::IsNullOrEmpty($iniContent["Strings"][$Alias.Matches.Value].ToString())) {

                        $Regex = '(?<=\%).*?(?=\%)'

                        $Match = [Text.RegularExpressions.Regex]::Match($Alias, $Regex)

                        $DriverCatalog = $Match.Value

                        if ($DriverCatalog.Contains('"')) {
                    
                            $DriverCatalog = $DriverCatalog.Replace('"', [System.String]::Empty)

                        }

                        $Extension = [IO.Path]::GetExtension($DriverCatalog)

                        if ([String]::IsNullOrEmpty($Extension)) {

                            $DriverCatalog = "$DriverCatalog.cat"

                        } else {

                            $DriverCatalog = $DriverCatalog.Replace($Extension, ".cat")

                        }

                        break

                    }

                }

            }

            return $DriverCatalog.Trim()

        } else {

            return [String]::Empty

        }

    } catch {

        return [String]::Empty

    }

}


function Get-DriverVersion {

    param (

        [Parameter(Mandatory = $true)]
        [Hashtable] $IniContent

    )

    try {

        $DriverVersion = $IniContent["Version"]["DriverVer"].ToString().Trim()

        if (![String]::ISNullOrEmpty($DriverVersion)) {

            $Regex = '\d+(\.\d+)+'

            $Match = [Text.RegularExpressions.Regex]::Match($DriverVersion, $Regex)

            $DriverVersion = $Match.Value.Trim()

            return $DriverVersion

        } else {

            return [String]::Empty

        }

    } catch {

        return [String]::Empty

    }

}


$TSEnvironment = Get-TSEnvironment

if ($null -ne $TSEnvironment) {

    $LogFolder = $TSEnvironment.Value("_SMSTSLogPath")

} else {
            
    $LogFolder = "$env:Windir\Temp"

}

$LogFilePath = Join-Path -Path $LogFolder -ChildPath $LogName

if ([String]::IsNullOrEmpty($DriverPackagePath)) {

    $DriverPackagePath = $PSScriptRoot

}

$Drivers = Get-ChildItem -Path $PSScriptRoot -Filter *.inf -Recurse

$BitlockerVolume = Get-BitLockerVolume -ErrorAction SilentlyContinue

if ($null -ne $BitlockerVolume) {

    foreach ($Volume in $BitlockerVolume) {

        if ($Volume.ProtectionStatus -eq "On") {
 
            Try {

                Suspend-BitLocker -MountPoint $Volume.MountPoint -RebootCount 1 -ErrorAction SilentlyContinue

                Write-CMLog -Log $LogFilePath -Value "Bitlocker protection was successfully suspended for $($Volume.MountPoint)" -Severity 1

            } Catch {

                Write-CMLog -Log $LogFilePath -Value "Something went wrong while suspending Bitlocker protection for $($Volume.MountPoint)" -Severity 3

                [Environment]::Exit(1)

            }

        }

    }

}

Write-CMLog -Log $LogFilePath -Value "------------------- Starting Driver Install -----------------" -Severity 1

$_Success = 0
$_Error = 0

foreach ($Driver in $Drivers) {
         
    $DriverClass = [String]::Empty
    $DriverCatalog = [String]::Empty
    $DriverVersion = [String]::Empty

    $IniContent = Get-IniContent -FilePath $Driver.FullName

    $DriverClass = ($IniContent["Version"]["Class"]).ToString().Trim()
    $DriverCatalog = Get-DriverCatalog -IniContent $IniContent
    $DriverVersion = Get-DriverVersion -IniContent $IniContent

    if ((![String]::ISNullOrEmpty($DriverClass)) -and (![String]::ISNullOrEmpty($DriverCatalog)) -and (![String]::ISNullOrEmpty($DriverVersion))) {

        Write-CMLog -Log $LogFilePath -Value "Working with $($Driver.FullName)" -Severity 1

        $ReturnCode = Create-Process -File "pnputil.exe" -Arguments "-i -a $([char]34)$($Driver.FullName)$([char]34)" -Log $LogFilePath

        if ($ReturnCode -eq 0) {

            Write-CMLog -Log $LogFilePath -Value "`t`t$($Driver.Name) $($DriverVersion) was successfully installed" -Severity 1
            $_Success += 1

        } elseif (($ReturnCode -eq 259) -or ($ReturnCode -eq 3010)) {

            Write-CMLog -Log $LogFilePath -Value "`t`t$($Driver.Name) $($DriverVersion) was successfully installed a reboot is pending" -Severity 2
            $_Success += 1

        } else {

            Write-CMLog -Log $LogFilePath -Value "`t`tFailed to install driver $($Driver.Name) $DriverVersion return code is : $ReturnCode" -Severity 3                                  
            Write-CMLog -Log $LogFilePath -Value "`t`tDriver informations :" -Severity 3
            Write-CMLog -Log $LogFilePath -Value "`t`t`t$($TargetedDriver.Driver)" -Severity 3
            Write-CMLog -Log $LogFilePath -Value "`t`t`t$($TargetedDriver.Version)" -Severity 3
            Write-CMLog -Log $LogFilePath -Value "`t`t`t$($TargetedDriver.ClassName)" -Severity 3
            Write-CMLog -Log $LogFilePath -Value "`t`t`t$($TargetedDriver.CatalogFile)" -Severity 3
            $_Error += 1

        }

    }

}

Write-CMLog -Log $LogFilePath -Value "------------------- Driver update Finished -----------------" -Severity 1
Write-CMLog -Log $LogFilePath -Value "|         already up to date | $_AlreadyUpToDate           |" -Severity 1
Write-CMLog -Log $LogFilePath -Value "|                    success | $_Success                   |" -Severity 1
Write-CMLog -Log $LogFilePath -Value "|                      error | $_Error                     |" -Severity 1
Write-CMLog -Log $LogFilePath -Value "------------------------------------------------------------" -Severity 1
