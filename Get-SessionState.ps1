
if (!([Management.Automation.PSTypeName]'SessionInfo').Type) {

    Add-Type -TypeDefinition @"

        using System;
        using System.Runtime.InteropServices;

        public static class SessionInfo
        {
            [DllImport("kernel32.dll")]
            public static extern uint WTSGetActiveConsoleSessionId();
        }

"@

}

$Explorer = Get-Process -Name "Explorer" -IncludeUserName -ErrorAction SilentlyContinue

$Result = @()
                   
if ($null -ne $Explorer) {

    if (($Explorer | Measure-Object).Count -gt 0) {

        $WTSActiveSessionID = [SessionInfo]::WTSGetActiveConsoleSessionId()

        $LogonUI = Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue

        $Sessions = qwinsta | Select-Object -Skip 1 | ForEach-Object {

            [PSCustomObject]@{

                SessionName = $_.Substring(1,18).Trim()
                ID = $_.Substring(41,5).Trim()
                State = $_.Substring(48,8).Trim()

            }

        }

        $Explorer | ForEach-Object {

            $SessionId = $_.SessionId
            $UserName = $_.UserName
            $StartTime = $_.StartTime

            $Session = $Sessions | Where-Object { $_.ID -eq $SessionId }

            $Ordered = @{

                "SessionName" = $Session.SessionName 
                "SessionId" = $SessionId
                "UserName"  = $UserName
                "StartTime" = $StartTime
                "State" = $Session.State            
                "Locked" = $false
                "WTSActiveSession" = $false

            }

            if ($null -ne $LogonUI) {

                $Ordered.Locked = ($null -ne ($LogonUI | Where-Object { $_.SessionId -eq $SessionId }))

            }

            $Ordered.WTSActiveSession = ($SessionId -eq $WTSActiveSessionID)

            $Result += New-Object -TypeName PSObject -Property $Ordered

        }

    }

}

Return $Result
