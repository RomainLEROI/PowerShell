
<#

.SYNOPSIS

Just a POC that demonstrate Powershell could be run remotely without WinRM & PSSession


.EXAMPLE

Windows PowerShell
Copyright (C) 2016 Microsoft Corporation. All rights reserved.

PS C:\Users\POKEDEX> .\Scripts\Invoke-ScriptBlock.ps1 -ComputerName SALAMESH -ScriptBlock {
>> Get-Service | Where-Object { $_.Name -eq "WinRM" } | Format-Table
>> Get-Process | Where-Object { $_.ProcessName -eq "Powershell" } | Format-Table
>> }

Status   Name               DisplayName
------   ----               -----------
Stopped  WinRM              Gestion à distance de Windows (Gest...



Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    530      36    74988      69712       0,50  16748   0 powershell
    571      38    61488      74200       1,05  22132   2 powershell


PS C:\Users\POKEDEX>.\Scripts\Invoke-ScriptBlock.ps1 -ComputerName SALAMESH -ScriptBlock {
>> Get-Service | Where-Object { $_.Name -eq "WinRM" } | Format-List
>> Get-Process | Where-Object { $_.ProcessName -eq "Powershell" } | Format-List
>> }


Name                : WinRM
DisplayName         : Gestion à distance de Windows (Gestion WSM)
Status              : Stopped
DependentServices   : {}
ServicesDependedOn  : {RPCSS, HTTP}
CanPauseAndContinue : False
CanShutdown         : False
CanStop             : False
ServiceType         : Win32ShareProcess





Id      : 12492
Handles : 533
CPU     : 0,46875
SI      : 0
Name    : powershell

Id      : 22132
Handles : 571
CPU     : 1,046875
SI      : 2
Name    : powershell



PS C:\Users\POKEDEX>

#>




Param(

  [Parameter(Mandatory = $false)] 
  [String] $ComputerName = "localhost",

  [Parameter(Mandatory = $true)] 
  [ScriptBlock] $ScriptBlock

)




Function Invoke-ScriptBlock() {

    Param(

        [Parameter(Mandatory=$true)]
        [IO.Pipes.NamedPipeClientStream] $PipeClient,

        [Parameter(Mandatory = $true)] 
        [ScriptBlock] $ScriptBlock
   
    )

    Try {

        $PipeClient.Connect()

        $PipeReader = New-Object System.IO.StreamReader($PipeClient)

        $PipeWriter = New-Object System.IO.StreamWriter($PipeClient)
        $PipeWriter.AutoFlush = $true

        $PipeWriter.WriteLine($ScriptBlock.ToString())
        $PipeWriter.WriteLine("EOS")

        $Builder = [Text.StringBuilder]::new()

        While ( ($Incoming = $PipeReader.ReadLine()) -ne "EOS") { 

            [Void]$Builder.AppendLine($Incoming) 
    
        }

        [Void] $PipeWriter.Dispose()
        [Void] $PipeReader.Dispose()
        [Void] $PipeClient.Dispose()

        Return $Builder.ToString()

    } Catch {

        Return $null

    }

}




Function Create-PipeClient() {

    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName
   
    )

    Try {

        [IO.Pipes.NamedPipeClientStream] $PipeClient = new-object System.IO.Pipes.NamedPipeClientStream($ComputerName, 'ScriptBlock', [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::None, [System.Security.Principal.TokenImpersonationLevel]::Anonymous)

        Return $PipeClient

    } Catch {

        Return $null
        
    }

}




Function Create-PipeServer() {

    Param(

        [Parameter(Mandatory=$true)]
        [Management.ManagementClass] $ManagementClass
   
    )


    Try {

        [ScriptBlock] $ScriptBlock = {$PipeServer = New-Object System.IO.Pipes.NamedPipeServerStream('ScriptBlock', [System.IO.Pipes.PipeDirection]::InOut) ; $PipeServer.WaitForConnection() ; $PipeReader = New-Object System.IO.StreamReader($PipeServer) ; $PipeWriter = New-Object System.IO.StreamWriter($PipeServer) ; $PipeWriter.AutoFlush = $true ; $Builder = [Text.StringBuilder]::new() ; While ( ($Incoming = $PipeReader.ReadLine()) -ne 'EOS') {  [Void]$Builder.AppendLine($Incoming) } ; $NewPowerShell = [PowerShell]::Create().AddScript([Scriptblock]::Create($Builder.ToString())) ; $NewRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace() ; $NewRunspace.ApartmentState = [System.Threading.ApartmentState]::STA ; $NewPowerShell.Runspace = $NewRunspace ; $NewPowerShell.Runspace.Open() ; $Invoke = $NewPowerShell.BeginInvoke() ; $Result = $NewPowerShell.EndInvoke($Invoke) ; $Ser = [System.Management.Automation.PSSerializer]::Serialize($result) ; $PipeWriter.WriteLine($Ser) ; $PipeWriter.WriteLine('EOS') ; $PipeWriter.dispose() ; $PipeReader.Dispose() ; $PipeServer.Close() ; $PipeServer.Dispose()}

        [String] $Command = "&{ $($ScriptBlock.ToString()) }"

        [String] $CmdLine = "PowerShell.exe -command $Command"

        [Management.ManagementBaseObject] $Process = Create-Process -ManagementClass $ManagementClass -CmdLine $CmdLine

        Return $Process

    } Catch {

        Return $null
        
    }

}




Function Create-ManagementEventWatcher() {


    Param(

        [Parameter(Mandatory=$true)]
        [Management.ManagementScope] $ManagementScope,

        [Parameter(Mandatory=$true)]
        [Management.ManagementBaseObject] $Process
   
    )

    Try {

        [Management.WQLEventQuery] $WqlEventQuery = New-Object System.Management.WQLEventQuery("SELECT * From WIN32_ProcessStopTrace WHERE ProcessID=$($Process.ProcessID)")

        [Management.ManagementEventWatcher] $ManagementEventWatcher = New-Object System.Management.ManagementEventWatcher($ManagementScope, $WqlEventQuery)

        [Management.EventWatcherOptions] $Options = New-Object System.Management.EventWatcherOptions

        $Options.TimeOut = [TimeSpan]"0.1:0:0"

        $ManagementEventWatcher.Options = $Options

        Return $ManagementEventWatcher

    } Catch {

        Return $null

    }

}




Function Create-Process() {


    Param(

        [Parameter(Mandatory=$true)]
        [Management.ManagementClass] $ManagementClass,

        [Parameter(Mandatory=$true)]
        [String] $CmdLine
   
    )

    Try {

        [Management.ManagementBaseObject] $Process = $ManagementClass.Create($CmdLine)
        
        Return $Process

    } Catch {

        Return $null

    }

}




Function Create-ManagementClass() {


    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName,

        [Parameter(Mandatory=$true)]
        [Management.ManagementScope] $ManagementScope
   
    )


    Try {

        [Management.ObjectGetOptions] $ObjectGetOptions = New-Object System.Management.ObjectGetOptions($null, [System.TimeSpan]::MaxValue, $true)

        [Management.ManagementClass] $ManagementClass = New-Object System.Management.ManagementClass($ManagementScope, "\\$ComputerName\root\cimV2:Win32_Process", $ObjectGetOptions)

        Return $ManagementClass

    } Catch {

        Return $null

    }

}




Function Create-ManagementScope() {


    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName,

        [Parameter(Mandatory=$true)]
        [Management.ManagementOptions] $ConnectionOptions
   
    )

    Try {

        [Management.ManagementScope] $ManagementScope = New-Object System.Management.ManagementScope("\\$ComputerName\root\cimV2", $ConnectionOptions)

        Return $ManagementScope

    } Catch {

        Return $null

    }

}




Function Is-Online() {


    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName
   
    )

    Try {
     
        [Bool] $Result = Test-Connection -computername $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue

        Return $Result

    } Catch {

        Return $false

    }

}




Function Create-ConnectionOptions() {


    Try {

        [Management.ManagementOptions] $ConnectionOptions = New-Object System.Management.ConnectionOptions

        $ConnectionOptions.Authentication = [System.Management.AuthenticationLevel]::Packet

        $ConnectionOptions.Impersonation = [System.Management.ImpersonationLevel]::Impersonate

        $ConnectionOptions.EnablePrivileges = $true

        Return $ConnectionOptions

    } Catch {

        Return $null

    }

}




[Management.ManagementOptions] $ConnectionOptions = Create-ConnectionOptions

if ($null -ne $ConnectionOptions) {


    if (Is-Online -ComputerName $ComputerName) {


        [Management.ManagementScope] $ManagementScope = Create-ManagementScope -ComputerName $ComputerName -ConnectionOptions $ConnectionOptions


        if ($null -ne $ManagementScope) {


            [Management.ManagementClass] $ManagementClass = Create-ManagementClass -ComputerName $ComputerName -ManagementScope $ManagementScope


            if ($null -ne $ManagementClass) {

                 
                if ((Create-PipeServer -ManagementClass $ManagementClass) -ne $null) {


                    [IO.Pipes.NamedPipeClientStream] $PipeClient = Create-PipeClient -ComputerName $ComputerName


                    if ($null -ne $PipeClient) {


                        $Return = [Management.Automation.PSSerializer]::Deserialize((Invoke-ScriptBlock -PipeClient $PipeClient -ScriptBlock $ScriptBlock))

                        Return $Return


                    } else {


                        Write-Error "Failed to create named pipe client"

                        Return $null


                    }


                } else {


                    Write-Error "Failed to create named pipe server on $ComputerName"

                    Return $null


                }


            } else {


                Write-Error "ManagementClass creation error for $ComputerName"

                Return $null


            }


        } else {


            Write-Error "ManagementScope creation error on $ComputerName"

            Return $null


        }


    } else {


        Write-Output "$ComputerName not online"

        Return $null


    }


} else {


    Write-Error "ConnectionOptions creation error"

    Return $null


}



