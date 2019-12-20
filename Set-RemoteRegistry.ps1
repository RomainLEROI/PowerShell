
Param ( 

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,
   
    [Parameter(ParameterSetName = "Enable", Mandatory = $true)]
    [Switch] $Enable,

    [Parameter(ParameterSetName = "Enable", Mandatory = $false)]
    [Switch] $Start,

    [Parameter(ParameterSetName = "Disable", Mandatory = $true)]
    [Switch] $Stop,

    [Parameter(ParameterSetName = "Disable", Mandatory = $false)]
    [Switch] $Disable

)


$IsElevated = ([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if ($IsElevated) {

    $IsLocalHost = if (($ComputerName -eq $env:COMPUTERNAME) -or ($ComputerName -eq 'localhost') -or ($ComputerName -eq '.') -or (((Get-NetIPAddress).IPAddress).Contains($ComputerName))) { Write-Output $true } else { Write-Output $false }

    if ($IsLocalHost) {

        $IsOnline = $true

    } else {

        $IsOnline = Try { Write-Output (Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

    }

    if ($IsOnline) {

        Try {

            $Service = Get-WmiObject -Class "Win32_Service" -Namespace "root\cimv2" -Computername $ComputerName -Filter "name='remoteregistry'" 

            Write-Output -InputObject "`n$ComputerName`n"
            Write-Output -InputObject "Start state :`n-------------"
            Write-Output -InputObject $($Service | Format-List)

            $SomethingDone = $false

            switch ($true) {

                $Enable {

                    if ($Service.StartMode -eq "Disabled") {

                        if (($Service.ChangeStartMode("Automatic")).returnvalue -eq 0) { 

                            $SomethingDone = $true

                        } else {

                            Throw "Failed to change service StartMode"
                        }

                    }

                } $Start {

                    if ($Service.State -eq "Stopped") {

                        if (($Service.StartService()).returnvalue -eq 0) { 

                            $SomethingDone = $true

                        } else {

                            Throw "Failed to start service"
                        }

                    }

                } $Stop {

                    if ($Service.State -eq "Running") {

                        if (($Service.StopService()).returnvalue -eq 0) { 

                            $SomethingDone = $true

                        } else {

                            Throw "Failed to change service StartMode"
                        }

                    }

                } $Disabled {
                                
                    if ($Service.StartMode -ne "Disabled") {

                        if (($Service.ChangeStartMode("Disabled")).returnvalue -eq 0) { 
                            
                            $SomethingDone = $true

                        } else {

                            Throw "Failed to change service StartMode"
                        }

                    }

                }
            }

            if ($SomethingDone) {

                $Service = Get-WmiObject -Class Win32_Service -Namespace root\cimv2 -Computername $ComputerName -Filter "name='remoteregistry'" 

                Write-Output -InputObject "Current state :`n---------------"
                Write-Output -InputObject $($Service | Format-List)

            }

        } Catch {

            Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"

        }

    }  else {

        Write-Warning -Message "$ComputerName is not online"

    }

} else {

    Write-Warning -Message "The requested operation requires elevation"

}
