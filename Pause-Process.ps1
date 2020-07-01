
Param (

    [Parameter(Mandatory = $true)]
    [Int] $ProcessID,

    [Parameter(Mandatory = $false)]
    [Switch] $Resume

)


if (!([Management.Automation.PSTypeName]'ProcessDebug').Type) {

    Add-Type -TypeDefinition @"

        using System;
        using System.Diagnostics;
        using System.Security.Principal;
        using System.Runtime.InteropServices;

        public static class ProcessDebug
        {
            [DllImport("kernel32.dll")]
            public static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, out bool pbDebuggerPresent);

            [DllImport("kernel32.dll")]
            public static extern int DebugActiveProcess(int PID);

            [DllImport("kernel32.dll")]
            public static extern int DebugActiveProcessStop(int PID);

        }
"@

}


$ProcessHandle = (Get-Process -Id $ProcessID).Handle
$DebuggerPresent = [IntPtr]::Zero

[Void] [ProcessDebug]::CheckRemoteDebuggerPresent($ProcessHandle,[Ref] $DebuggerPresent)

if ($Resume.IsPresent) {

    if ($DebuggerPresent) {
              
        $Result = [ProcessDebug]::DebugActiveProcessStop($Process.Id)
             
    } else {

        $Result = $true

    }

} else {

    if (!$DebuggerPresent) {
   
        $Result = [ProcessDebug]::DebugActiveProcess($ProcessID) 
                    
    } else {

        $Result = $true

    }

}

Return $Result
