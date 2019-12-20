
Param(

    [Parameter(Mandatory = $true)] 
    [String] $ComputerName,

    [Parameter(Mandatory = $true)] 
    [ValidateScript({ !($_ -match "^\\\\([a-zA-Z0-9`~!@#$%^&(){}\'._-]+)\\") })]
    [String] $CmdLine,

    [Parameter(Mandatory = $false)]
    [Switch] $Wait

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

            $ConnectionOptions = New-Object -TypeName Management.ConnectionOptions

            $ConnectionOptions.Authentication = [Management.AuthenticationLevel]::Packet

            $ConnectionOptions.Impersonation = [Management.ImpersonationLevel]::Impersonate

            $ConnectionOptions.EnablePrivileges = $true

            $ManagementScope = New-Object -TypeName Management.ManagementScope

            $ManagementScope.Path = "\\$ComputerName\root\cimV2"

            $ManagementScope.Options = $ConnectionOptions

            $ObjectGetOptions = New-Object -TypeName Management.ObjectGetOptions

            $ObjectGetOptions.Timeout = [TimeSpan]::MaxValue

            $ObjectGetOptions.UseAmendedQualifiers = $true

            $ManagementClass = New-Object -TypeName Management.ManagementClass

            $ManagementClass.Scope = $ManagementScope

            $ManagementClass.Path = "\\$ComputerName\root\cimV2:Win32_Process"

            $ManagementClass.Options = $ObjectGetOptions

            $Process = $ManagementClass.Create($CmdLine)

            if ($Process.returnvalue -eq 0) {

                Write-Output -InputObject "Process was successfully created on $ComputerName"

                if ($Wait) {

                    $WqlEventQuery = New-Object -TypeName Management.WQLEventQuery

                    $WqlEventQuery.QueryString = "SELECT * FROM WIN32_ProcessStopTrace WHERE ProcessID=$($Process.ProcessID)"

                    $ManagementEventWatcher = New-Object -TypeName Management.ManagementEventWatcher

                    $ManagementEventWatcher.Scope = $ManagementScope

                    $ManagementEventWatcher.Query = $WqlEventQuery

                    $Options = New-Object -TypeName Management.EventWatcherOptions

                    $Options.TimeOut = [TimeSpan]"0.1:0:0"

                    $ManagementEventWatcher.Options = $Options

                    $ManagementEventWatcher.Start()

                    $ProcessStopTrace = $ManagementEventWatcher.WaitForNextEvent()

                    $ExitCode = $ProcessStopTrace.ExitStatus

                } else {

                    $ExitCode = 0

                }

                Return $ExitCode

            } else {

                Return $Process.returnvalue

            }

        } Catch {

            Return $_.Exception.HResult

        } Finally {


            foreach ($Disposable in @($ProcessStopTrace, $ManagementEventWatcher, $Process, $ManagementClass)) {

                if ($null -ne $Disposable) {

                    [Void] $Disposable.Dispose()

                }

            }
            
        }

    } else {

        Write-Warning -Message  "$ComputerName is not online"

    } 

} else {

    Write-Warning -Message "The requested operation requires elevation"

}
