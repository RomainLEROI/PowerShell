
Param(

    [Parameter(Mandatory = $true)] 
    [String] $ComputerName,

    [Parameter(Mandatory = $true)] 
    [ValidateScript({ !($_ -match "^\\\\([a-zA-Z0-9`~!@#$%^&(){}\'._-]+)\\") })]
    [String] $CmdLine,

    [Parameter(Mandatory = $false)]
    [Switch]$Wait

)


Function Is-Online {

    Param(

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


            [Management.ManagementOptions] $ConnectionOptions = [Management.ConnectionOptions]::new()

            $ConnectionOptions.Authentication = [System.Management.AuthenticationLevel]::Packet

            $ConnectionOptions.Impersonation = [System.Management.ImpersonationLevel]::Impersonate

            $ConnectionOptions.EnablePrivileges = $true

            [Management.ManagementScope] $ManagementScope = [Management.ManagementScope]::new()

            $ManagementScope.Path = "\\$ComputerName\root\cimV2"

            $ManagementScope.Options = $ConnectionOptions

            [Management.ObjectGetOptions] $ObjectGetOptions = [Management.ObjectGetOptions]::new()

            $ObjectGetOptions.Timeout = [TimeSpan]::MaxValue

            $ObjectGetOptions.UseAmendedQualifiers = $true

            [Management.ManagementClass] $ManagementClass = [Management.ManagementClass]::new()

            $ManagementClass.Scope = $ManagementScope

            $ManagementClass.Path = "\\$ComputerName\root\cimV2:Win32_Process"

            $ManagementClass.Options = $ObjectGetOptions

            [Management.ManagementBaseObject] $Process = $ManagementClass.Create($CmdLine)

            if ($Process.returnvalue -eq 0) {

                Write-Output -InputObject "Process was successfully created on $ComputerName"

                if ($Wait) {

                    [Management.WQLEventQuery] $WqlEventQuery = [Management.WQLEventQuery]::new()

                    $WqlEventQuery.QueryString = "SELECT * From WIN32_ProcessStopTrace WHERE ProcessID=$($Process.ProcessID)"

                    [Management.ManagementEventWatcher] $ManagementEventWatcher = [Management.ManagementEventWatcher]::new()

                    $ManagementEventWatcher.Scope = $ManagementScope

                    $ManagementEventWatcher.Query = $WqlEventQuery

                    [Management.EventWatcherOptions] $Options = [Management.EventWatcherOptions]::new()

                    $Options.TimeOut = [TimeSpan]"0.1:0:0"

                    $ManagementEventWatcher.Options = $Options

                    $ManagementEventWatcher.Start()

                    [Management.ManagementBaseObject] $ProcessStopTrace = $ManagementEventWatcher.WaitForNextEvent()

                    [Int] $ExitCode = $ProcessStopTrace.ExitStatus

                    Write-Output -InputObject "Process finished with return code $ExitCode on $ComputerName"

                } else {

                    [Management.ManagementEventWatcher] $ManagementEventWatcher = $null

                    [Management.ManagementBaseObject] $ProcessStopTrace = $null

                    $ExitCode = 0

                }

                Return $ExitCode

            } else {

                Write-Output -InputObject "Failed to create process on $ComputerName"

                Return $Process.returnvalue

            }

        } Catch {


            Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

            Return $_.Exception.HResult


        } Finally {


            foreach ($Disposable in @($ProcessStopTrace, $ManagementEventWatcher, $Process, $ManagementClass)) {

                if ($null -ne $Disposable) {

                    [Void] $Disposable.Dispose()

                }

            }


        }

    } else {

        Write-Output -InputObject "$ComputerName is not online"

    } 

} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
