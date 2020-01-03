



Param ( 

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [string] $ServiceName,
   
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

    $IsLocalHost = (($ComputerName -eq $env:COMPUTERNAME) -or ($ComputerName -eq 'localhost') -or ($ComputerName -eq '.') -or (((Get-NetIPAddress).IPAddress).Contains($ComputerName)))
    
    if ($IsLocalHost) {

        $IsOnline = $true

    } else {

        $IsOnline = Try { Write-Output (Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

    }

    if ($IsOnline) {

        Try {

            $Service = Get-WmiObject -Class "Win32_Service" -Namespace "root\cimv2" -Computername $ComputerName -Filter "name='$ServiceName'" 

            if ($null -ne $Service) {

                switch ($true) {

                    $Enable {

                        if ($Service.StartMode -eq "Disabled") {

                            if (($Service.ChangeStartMode("Automatic")).returnvalue -ne 0) { 

                                Throw "Failed to enable service"
                            }

                        }

                    } $Start {

                        if ($Service.State -eq "Stopped") {

                            if (($Service.StartService()).returnvalue -ne 0) { 

                                Throw "Failed to start service"
                            }

                        }

                    } $Stop {

                        if ($Service.State -eq "Running") {

                            if (($Service.StopService()).returnvalue -ne 0) { 

                                Throw "Failed to stop service"
                            }

                        }

                    } $Disabled {
                                
                        if ($Service.StartMode -ne "Disabled") {

                            if (($Service.ChangeStartMode("Disabled")).returnvalue -ne 0) { 
                            
                                Throw "Failed to disable service"
                            }

                        }

                    }
                }

                $Service = Get-WmiObject -Class Win32_Service -Namespace root\cimv2 -Computername $ComputerName -Filter "name='$ServiceName'" 

                Return $Service

            } else {

                Write-Warning -Message "No $ServiceName service was found on $ComputerName"

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
