

<#

.SYNOPSIS

Invoke WMI Process on remote computer and get execution exit code back


.NOTES

Account used to execute this script must have administrator privilege on targeted machine
Remote process can't execute things from network  


.EXAMPLE

Windows PowerShell
Copyright (C) 2016 Microsoft Corporation. All rights reserved.

PS C:\Users\POKEDEX> .\Scripts\Invoke-PsCommand.ps1 -ComputerName SALAMESH -CmdLine C:\Test\Test.vbs
Process finished with return code 0 on SALAMESH
PS C:\Users\POKEDEX>

#>


Param(

  [Parameter(Mandatory = $true)] 
  [String] $ComputerName,

  [Parameter(Mandatory = $true)] 
  [ValidateScript({ !($_ -match "^\\\\([a-zA-Z0-9`~!@#$%^&(){}\'._-]+)\\") })]
  [String] $CmdLine

)




Function Is-Online() {


    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName
   
    )

    Try {
     
        [Bool] $Result = Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue

        Return $Result

    } Catch {

        Return $false

    }

}




if (Is-Online -ComputerName $ComputerName) {


    Try {


        [Management.ManagementOptions] $ConnectionOptions = New-Object System.Management.ConnectionOptions

        $ConnectionOptions.Authentication = [System.Management.AuthenticationLevel]::Packet

        $ConnectionOptions.Impersonation = [System.Management.ImpersonationLevel]::Impersonate

        $ConnectionOptions.EnablePrivileges = $true

        [Management.ManagementScope] $ManagementScope = New-Object System.Management.ManagementScope("\\$ComputerName\root\cimV2", $ConnectionOptions)

        [Management.ObjectGetOptions] $ObjectGetOptions = New-Object System.Management.ObjectGetOptions($null, [System.TimeSpan]::MaxValue, $true)

        [Management.ManagementClass] $ManagementClass = New-Object System.Management.ManagementClass($ManagementScope, "\\$ComputerName\root\cimV2:Win32_Process", $ObjectGetOptions)

        [Management.ManagementBaseObject] $Process = $ManagementClass.Create($CmdLine)

        [Management.WQLEventQuery] $WqlEventQuery = New-Object System.Management.WQLEventQuery("SELECT * From WIN32_ProcessStopTrace WHERE ProcessID=$($Process.ProcessID)")

        [Management.ManagementEventWatcher] $ManagementEventWatcher = New-Object System.Management.ManagementEventWatcher($ManagementScope, $WqlEventQuery)

        [Management.EventWatcherOptions] $Options = New-Object System.Management.EventWatcherOptions

        $Options.TimeOut = [TimeSpan]"0.1:0:0"

        $ManagementEventWatcher.Options = $Options

        $ManagementEventWatcher.Start()

        [Management.ManagementBaseObject] $ProcessStopTrace = $ManagementEventWatcher.WaitForNextEvent()

        [Int] $ExitCode = $ProcessStopTrace.ExitStatus

        Write-Host "Process finished with return code $ExitCode on $ComputerName"

        #Return $ExitCode


    } Catch {


        Write-Host "$($_.Exception.GetType())`n$($_.Exception.Message)" -ForegroundColor Red

        #Return $_.Exception.HResult


    } Finally {


        foreach ($Disposable in @($ProcessStopTrace, $ManagementEventWatcher, $Process, $ManagementClass)) {

            if ($null -ne $Disposable) {

                [Void] $Disposable.Dispose()

            }

        }


    }


} else {

    Write-Host "$ComputerName is not online" -ForegroundColor Yellow

}











