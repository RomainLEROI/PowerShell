Param ( 

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [string] $ServiceName,
   
    [Parameter(ParameterSetName = "Enable", Mandatory = $true)]
    [Switch] $Enable,
    
    [Parameter(ParameterSetName = "Disable", Mandatory = $false)]
    [Switch] $Disable,

    [Parameter(ParameterSetName = "Enable", Mandatory = $false)]
    [Switch] $Start,

    [Parameter(ParameterSetName = "Disable", Mandatory = $true)]
    [Switch] $Stop,

    [Parameter(ParameterSetName = "Create", Mandatory = $true)]
    [Switch] $Create,

    [Parameter(ParameterSetName = "Create", Mandatory = $true)]
    [String] $ServiceBinaryPath,

    [Parameter(ParameterSetName = "Create", Mandatory = $false)]
    [String] $ServiceDisplayName,

    [Parameter(ParameterSetName = "Create", Mandatory = $false)]
    [ValidateSet("Ignore", "Normal", "Severe", "Critical")]
    [String] $ServiceErrorControl = "Normal",

    [Parameter(ParameterSetName = "Create")]
    [ValidateSet("Automatic", "Manual", "Disabled")]
    [String] $StartMode = "Automatic",

    [Parameter(ParameterSetName = "Create")]
    [ValidateSet("KernelDriver", "FileSystemDriver", "Adapter", "RecognizerDriver", "Win32OwnProcess", "Win32ShareProcess", "InteractiveProcess")]
    [String] $ServiceType = "Win32OwnProcess",

    [Parameter(ParameterSetName = "Remove", Mandatory = $true)]
    [Switch] $Remove

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

                                Throw "Failed to enable $ServiceName on $ComputerName"
                            }

                        }

                    } $Start {

                        if ($Service.State -eq "Stopped") {

                            if (($Service.StartService()).returnvalue -ne 0) { 

                                Throw "Failed to start service $ServiceName on $ComputerName"
                            }

                        }

                    } $Stop {

                        if ($Service.State -eq "Running") {

                            if (($Service.StopService()).returnvalue -ne 0) { 

                                Throw "Failed to stop service $ServiceName on $ComputerName"
                            }

                        }

                    } $Disable {
                                
                        if ($Service.StartMode -ne "Disabled") {

                            if (($Service.ChangeStartMode("Disabled")).returnvalue -ne 0) { 
                            
                                Throw "Failed to disable service $ServiceName on $ComputerName"
                            }

                        }

                    } $Remove {
                                
                        if ($Service.State -eq "Running") {

                            if (($Service.StopService()).returnvalue -ne 0) { 

                                Throw "Failed to stop service $ServiceName on $ComputerName"
                            }

                            if (($Service.Delete()).returnvalue -ne 0) { 

                                Throw "Failed to delete service $ServiceName on $ComputerName"

                            }

                        }

                    } 

                }

                $Service = Get-WmiObject -Class Win32_Service -Namespace root\cimv2 -Computername $ComputerName -Filter "name='$ServiceName'" 

                Return $Service

            } else {

                if ($Enable -or $Start -or $Stop -or $Disable -or $Remove) {

                    Write-Warning -Message "No $ServiceName service was found on $ComputerName"

                } elseif ($Create) {

                    if ([String]::IsNullOrEmpty($ServiceDisplayName)) {

                        $ServiceDisplayName = $ServiceName

                    }

                    $ServiceTypeTable = @{
        
                        KernelDriver = 1
                        FileSystemDriver = 2
                        Adapter = 4
                        RecognizerDriver = 8
                        Win32OwnProcess = 16
                        Win32ShareProcess = 32

                    }

                    $ServiceErrorControlTable = @{

                        Ignore = 0
                        Normal = 1
                        Severe = 2
                        Critical = 3

                    }

                    $MasterClass = [wmiclass]"\\$ComputerName\ROOT\CIMV2:Win32_Service"

                    $InParams = $MasterClass.PSBase.GetMethodParameters("Create")
                    $InParams.Name = $ServiceName
                    $InParams.DisplayName = $ServiceDisplayName
                    $InParams.PathName = $ServiceBinaryPath
                    $InParams.ServiceType = $ServiceTypeTable.$ServiceType
                    $InParams.ErrorControl = $ServiceErrorControlTable.$ServiceErrorControl
                    $InParams.StartMode = $StartMode
                    $InParams.DesktopInteract = $false
                    $InParams.StartName = $null
                    $InParams.StartPassword = $null
                    $InParams.LoadOrderGroup = $null
                    $InParams.LoadOrderGroupDependencies = $null
                    $InParams.ServiceDependencies = $null

                    $Result = $MasterClass.PSBase.InvokeMethod("Create", $InParams, $null) 

                    if (($MasterClass.PSBase.InvokeMethod("Create", $InParams, $null)).returnvalue -ne 0) {

                        Throw "Failed to create service $ServiceName on $ComputerName"

                    }

                }

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

