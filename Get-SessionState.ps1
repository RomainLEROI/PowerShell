Param (

    [Parameter(Mandatory = $false)]
    [String] $ComputerName = $env:COMPUTERNAME

)


$Explorer = Get-WmiObject -ComputerName $ComputerName -Query "SELECT SessionId, CreationDate FROM Win32_Process WHERE Name = 'explorer.exe'" -ErrorAction SilentlyContinue

$Result = @()
                   
if ($null -ne $Explorer) {

    if (($Explorer | Measure-Object).Count -gt 0) {

        $Sessions = @()

        ForEach ($Session in (qwinsta /server:$ComputerName | Select-Object -Skip 1)) {

            $Ordered = @{

                SessionName = $Session.Substring(1,18).Trim()
                UserName = $Session.Substring(19,22).Trim()
                ID = $Session.Substring(41,5).Trim()
                State = $Session.Substring(48,8).Trim()

            }

            $Sessions += New-Object -TypeName PSObject -Property $Ordered

        }

        ForEach ($Process in $Explorer) {

            $Locked = ($null -ne (Get-WmiObject -ComputerName $ComputerName -Query "SELECT SessionId FROM Win32_Process WHERE Name = 'logonUI.exe' AND SessionID = '$($Process.SessionId)'" -ErrorAction SilentlyContinue))

            $Session = $Sessions | Where-Object { $_.ID -eq $Process.SessionId }

            $Ordered = @{

                "SessionName" = $Session.SessionName 
                "SessionId" = $Process.SessionId
                "UserName"  = $Session.UserName
                "StartTime" = [Management.ManagementDateTimeConverter]::ToDateTime($Process.CreationDate)
                "State" = $Session.State                             
                "Locked" = $Locked

            }

            $Result += New-Object -TypeName PSObject -Property $Ordered

        }

    }

}
