Param (

    [Parameter(Mandatory = $false)]
    [ValidateScript({[IO.Path]::GetExtension($_) -eq '.log'})]
    [String] $LogName = "Drivers-Update.log"

)


Function Write-CMLog() {

    Param (

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


    [String] $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))

    [String] $Date = (Get-Date -Format "MM-dd-yyyy")

	[String] $Context = $([Security.Principal.WindowsIdentity]::GetCurrent().Name)

    [String] $LogText = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f
                         $Value, $Time, $Date, [IO.Path]::GetFileName($LogFilePath), $Context, $Severity, $PID
	
    $StreamWriter.WriteLine($LogText)

    $StreamWriter.Close()
    $StreamWriter.Dispose()

    $FileStream.Close()
    $FileStream.Dispose()

}


Function Get-TSEnvironment() {

    Try { 

        [__ComObject] $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        
        Return $TSEnvironment

    } Catch { 
        
        Return $null
            
    }

}


Function Get-IniContent () {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $FilePath

    )


    $Ini = @{}

    switch -regex -file $FilePath {

        “^\[(.+)\]” {

            $Section = $Matches[1]
            $Ini[$Section] = @{}
            $CommentCount = 0

        } “^(;.*)$” {

            $Value = $Matches[1]
            $CommentCount = $CommentCount + 1
            $Name = “Comment” + $CommentCount

            if ($null -ne $Section) {

                $Ini[$Section][$Name] = $Value

            }          

        } “(.+?)\s*=(.*)” {

            $Name,$Value = $Matches[1..2]

            if ($null -ne $Section) {

                $Ini[$Section][$Name] = $Value

            }

        } default {

            continue

        }

    }

    Return $Ini
}


Function Write-AllLines() {

    Param (

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


Function Create-Process() {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $File,

        [Parameter(Mandatory = $true)]
        [String] $Arguments,

        [Parameter(Mandatory = $false)]
        [String] $WorkingDir = [String]::Empty,

        [Parameter(Mandatory = $true)]
        [String] $Log

    )


    [Diagnostics.Process] $Process = [Diagnostics.Process]::new()

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

    [String] $Output = $Process.StandardOutput.ReadToEnd()

    $Process.WaitForExit()

    [Int] $ExitCode = $Process.ExitCode

    Write-AllLines -Output $Output -LogFilePath $Log

    Return $ExitCode

}


Function Get-DriverCatalog {

    Param (

        [Parameter(Mandatory = $true)]
        [Hashtable] $IniContent

    )


    Try {


        [String] $DriverCatalog = $IniContent["Version"]["CatalogFile"].ToString().Trim()

        if (![String]::ISNullOrEmpty($DriverCatalog)) {

            if ($DriverCatalog.Contains(';')) {

                $DriverCatalog = $DriverCatalog.Split(';')[0].ToString().Trim()

            } 

            if (($DriverCatalog.Contains('%')) -and (($DriverCatalog.ToCharArray() | Where-Object {$_ -eq '%'} | Measure-Object).Count -eq 2)) {

                foreach ($Alias in $DriverCatalog) {

                    if (![String]::IsNullOrEmpty($iniContent["Strings"][$Alias.Matches.Value].ToString())) {

                        [String] $Regex = '(?<=\%).*?(?=\%)'

                        [Text.RegularExpressions.Group] $Match = [Text.RegularExpressions.Regex]::Match($Alias, $Regex)

                        $DriverCatalog = $Match.Value

                        if ($DriverCatalog.Contains('"')) {
                    
                            $DriverCatalog = $DriverCatalog.Replace('"', [String]::Empty)

                        }

                        [String] $Extension = [IO.Path]::GetExtension($DriverCatalog)

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


    } Catch {

        return [String]::Empty

    }

}


Function Get-DriverVersion {

    Param (

        [Parameter(Mandatory = $true)]
        [Hashtable] $IniContent

    )


    Try {


        [String] $DriverVersion = $IniContent["Version"]["DriverVer"].ToString().Trim()


        if (![String]::ISNullOrEmpty($DriverVersion)) {

            [String] $Regex = '\d+(\.\d+)+'

            [Text.RegularExpressions.Group] $Match = [Text.RegularExpressions.Regex]::Match($DriverVersion, $Regex)

            $DriverVersion = $Match.Value.Trim()

            return $DriverVersion


        } else {

            return [String]::Empty

        }


    } Catch {

        return [String]::Empty

    }

}



[__ComObject] $TSEnvironment = Get-TSEnvironment

[String] $LogFolder = [String]::Empty

if ($null -ne $TSEnvironment) {

    $LogFolder = $TSEnvironment.Value("_SMSTSLogPath")

} else {
            
    $LogFolder = "$env:Windir\Temp"

}

[String] $LogFilePath = Join-Path -Path $LogFolder -ChildPath $LogName

[IO.FileSystemInfo[]] $Drivers = Get-ChildItem $PSScriptRoot -Filter *.inf -Recurse

[Microsoft.Dism.Commands.ImageObject[]] $CurrentDrivers = Get-WindowsDriver -Online


[Management.ManagementBaseObject] $BitlockerVolume = Get-WmiObject -Query "SELECT ProtectionStatus,ConversionStatus FROM Win32_EncryptableVolume WHERE DriveLetter='$($env:SystemDrive)'" -Namespace "ROOT\cimv2\Security\MicrosoftVolumeEncryption"

if ($null -ne $BitlockerVolume) {

    if ($BitlockerVolume.ProtectionStatus -eq 1) {

        Create-Process -File "manage-bde.exe" -Arguments "-rc 1" -Log $LogFilePath

    }

}


Write-CMLog -Log $LogFilePath -Value "------------------- Starting Driver update -----------------" -Severity 1


[Int] $_AlreadyUpToDate = 0
[Int] $_Success = 0
[Int] $_Error = 0


foreach ($Driver in $Drivers) {

           
    [String] $DriverClass = [String]::Empty
    [String] $DriverCatalog = [String]::Empty
    [String] $DriverVersion = [String]::Empty

    [Hashtable] $IniContent = Get-IniContent -FilePath $Driver.FullName

    $DriverClass = ($IniContent["Version"]["Class"]).ToString().Trim()
    $DriverCatalog = Get-DriverCatalog -IniContent $IniContent
    $DriverVersion = Get-DriverVersion -IniContent $IniContent


    if ((![System.String]::ISNullOrEmpty($DriverClass)) -and (![String]::ISNullOrEmpty($DriverCatalog)) -and (![String]::ISNullOrEmpty($DriverVersion))) {

        Write-CMLog -Log $LogFilePath -Value "Working with $($Driver.FullName)" -Severity 1

        $TargetedDrivers = $CurrentDrivers | Where-Object { (($_.ClassName -eq $DriverClass) -and ($_.CatalogFile -eq $DriverCatalog)) }

        [Nullable[Boolean]] $IsUpToDate = $null

        if (($TargetedDrivers | Measure-Object).Count -gt 0) {

            foreach ($TargetedDriver in $TargetedDrivers) {


                if ([Version]$TargetedDriver.Version -ge $DriverVersion) {

                    Write-CMLog -Log $LogFilePath -Value "`tDriver $($Driver.Name) ($($TargetedDriver.Driver)) is already up to date, current version is : $($TargetedDriver.Version)" -Severity 1

                    $_AlreadyUpToDate += 1

                } else {

                    Write-CMLog -Log $LogFilePath -Value "`tDriver $($Driver.Name) ($($TargetedDriver.Driver)) is not up to date, current version is : $($TargetedDriver.Version), new version is : $DriverVersion" -Severity 2

                    Write-CMLog -Log $LogFilePath -Value "`t`0Removing older driver : $($TargetedDriver.Version)" -Severity 1
                    
                    $ReturnCode = Create-Process -File "pnputil.exe" -Arguments "-f -d $($TargetedDriver.Driver)" -Log $LogFilePath


                    if ($ReturnCode -eq 0) {

                        Write-CMLog -Log $LogFilePath -Value "`tDriver $($Driver.Name) $($TargetedDriver.Version) ($($TargetedDriver.Driver)) was successfully uninstalled" -Severity 1

                        Write-CMLog -Log $LogFilePath -Value "`t`0Installing newer driver : $DriverVersion" -Severity 1

                        $ReturnCode = Create-Process -File "pnputil.exe" -Arguments "-i -a $([char]34)$($Driver.FullName)$([char]34)" -Log $LogFilePath

                        if ($ReturnCode -eq 0) {

                            Write-CMLog -Log $LogFilePath -Value "`t`0`0$($Driver.Name) $($TargetedDriver.Version) was successfully updated to $DriverVersion" -Severity 1

                            $_Success += 1

                        } elseif (($ReturnCode -eq 259) -or ($ReturnCode -eq 3010)) {

                            Write-CMLog -Log $LogFilePath -Value "`t`0`0$($Driver.Name) $($TargetedDriver.Version)  was successfully updated to $DriverVersion a reboot is pending" -Severity 2

                            $_Success += 1

                        } else {

                            Write-CMLog -Log $LogFilePath -Value "`tFailed to install driver $($Driver.Name) $DriverVersion exiting with code : $ReturnCode" -Severity 3
                                    
                            Write-CMLog -Log $LogFilePath -Value "`t`0Driver informations :" -Severity 3

                            Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.Driver)" -Severity 3

                            Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.Version)" -Severity 3

                            Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.ClassName)" -Severity 3

                            Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.CatalogFile)" -Severity 3

                            $_Error += 1

                        }

                    } elseif ($ReturnCode -eq 2) {

                        Write-CMLog -Log $LogFilePath -Value "    $($Driver.Name) $($TargetedDriver.Version) ($($TargetedDriver.Driver)) is not removable" -Severity 2

                    } else {
                
                        Write-CMLog -Log $LogFilePath -Value "`tFailed to uninstall driver $($Driver.Name) $($TargetedDriver.Version) ($($TargetedDriver.Driver)) exiting with code : $ReturnCode" -Severity 3

                        Write-CMLog -Log $LogFilePath -Value "`t`0Driver informations :" -Severity 3

                        Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.Driver)" -Severity 3

                        Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.Version)" -Severity 3

                        Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.ClassName)" -Severity 3

                        Write-CMLog -Log $LogFilePath -Value "`t`0`0$($TargetedDriver.CatalogFile)" -Severity 3

                        $_Error += 1

                    }

                }

            }

        }

    }

}

Write-CMLog -Log $LogFilePath -Value "------------------- Driver update Finished -----------------" -Severity 1
Write-CMLog -Log $LogFilePath -Value "|         already up to date | $_AlreadyUpToDate           |" -Severity 1
Write-CMLog -Log $LogFilePath -Value "|                    success | $_Success                   |" -Severity 1
Write-CMLog -Log $LogFilePath -Value "|                      error | $_Error                     |" -Severity 1
Write-CMLog -Log $LogFilePath -Value "------------------------------------------------------------" -Severity 1
