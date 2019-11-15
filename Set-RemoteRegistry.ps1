
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



Function Is-Online {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName

    )

    Try {


        [Bool] $Result = Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue

        Return $Result


    } Catch {


        Return $false


    }


}


Function Is-LocalHost {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName

    
    )

    switch ($true) {

        ($ComputerName -eq $env:COMPUTERNAME) {

            Return $true

        } ($ComputerName -eq 'localhost') {

            Return $true

        } ($ComputerName -eq '.') {

            Return $true

        } Default {

            Return $false

        }

    }

}


if (([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    if ((Is-LocalHost -ComputerName $ComputerName) -or (Is-Online -ComputerName $ComputerName)) {


        Try {

            [Management.ManagementBaseObject] $Service = Get-WmiObject -Class "Win32_Service" -Namespace "root\cimv2" -Computername $ComputerName -Filter "name='remoteregistry'" 

            Write-Output -InputObject "`n$ComputerName`n"
            Write-Output -InputObject "Start state :`n-------------"
            Write-Output -InputObject $($Service | Format-List)

            [Bool] $SomethingDone = $false

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

            Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

        }


    }  else {

        Write-Output -InputObject "$ComputerName is not online"

    }

} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
