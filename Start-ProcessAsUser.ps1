<#

.SYNOPSIS

This script creates an interactive process from the system account


.NOTES


If the script is executed from WinPE or from another account than the system account a standard process is created


.EXAMPLE

Powershell.exe -ExecutionPolicy Bypass -File "%Scripts%\Start-ProcessAsUser.ps1" -CmdLine .\Test.exe

Powershell.exe -ExecutionPolicy Bypass -File "%Scripts%\Start-ProcessAsUser.ps1" -CmdLine "wscript.exe .\Test.vbs"

Powershell.exe -ExecutionPolicy Bypass -File "%Scripts%\Start-ProcessAsUser.ps1" -CmdLine "wscript.exe ".\Foo Bar\Test.vbs""

#>


Param(

    [Parameter(Mandatory = $true)]
    [string] $CmdLine,

    [Parameter(Mandatory = $false)]
    [String] $WorkingDir = [Environment]::SystemDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$Wait

)


Add-Type -TypeDefinition @"

    using System;
    using System.Runtime.InteropServices;

    [StructLayout(LayoutKind.Sequential)]
    public struct SECURITY_ATTRIBUTES
    {
        public int Length;
        public IntPtr lpSecurityDescriptor;
        public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO
    {
        public int cb;
        public String lpReserved;
        public String lpDesktop;
        public String lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint dwProcessId;
        public uint dwThreadId;
    }

    [Flags]
    public enum DESIRED_ACCESS : int
    {
        Low = 0x0,
        TokenDuplicate = 0x0002,
        TokenImpersonation = 0x0004,
	    TokenQuery = 0x0008,
        High = 0x10000000,
        AllAccess = 0x001F0FFF
    }

    [Flags]
    public enum PROCESS_ACCESS_FLAGS : uint
    {
        All = 0x001F0FFF,
        Terminate = 0x00000001,
        CreateThread = 0x00000002,
        VirtualMemoryOperation = 0x00000008,
        VirtualMemoryRead = 0x00000010,
        VirtualMemoryWrite = 0x00000020,
        DuplicateHandle = 0x00000040,
        CreateProcess = 0x000000080,
        SetQuota = 0x00000100,
        SetInformation = 0x00000200,
        QueryInformation = 0x00000400,
        QueryLimitedInformation = 0x00001000,
        Synchronize = 0x00100000
    }

    [Flags]
    public enum PROCESS_CREATION_FLAGS : int
    {
        CreateNewConsole = 0x00000010,
        CreateUnicodeEnvironment = 0x00000400,
        CreateBreakawayFromJob = 0x01000000,
        CreateNoWindow = 0x08000000, 	
        HighPriorityClass = 0x80
    }

    public enum TOKEN_TYPE : int
    {
        TokenPrimary = 1,
        TokenImpersonation = 2
    }


    public enum SECURITY_IMPERSONATION_LEVEL : int
    {
        SecurityAnonymous = 0,
        SecurityIdentification = 1,
        SecurityImpersonation = 2,
        SecurityDelegation = 3,
    }
  
    public static class ProcessLoader
    {

        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

        [DllImport("advapi32")]
        public static extern bool OpenProcessToken(IntPtr ProcessHandle, int DesiredAccess, ref IntPtr TokenHandle);

        [DllImport("kernel32.dll")]
        public static extern bool CloseHandle(IntPtr hSnapshot);
   
        [DllImport("advapi32.dll")]
        public static extern bool DuplicateTokenEx(IntPtr hExistingToken, uint dwDesiredAccess, ref SECURITY_ATTRIBUTES lpTokenAttributes, SECURITY_IMPERSONATION_LEVEL ImpersonationLevel, TOKEN_TYPE TokenType, out IntPtr phNewToken);

        [DllImport("advapi32.dll")]
        public static extern bool CreateProcessAsUser(IntPtr hToken, string lpApplicationName, string lpCommandLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes, bool bInheritHandles, 
                                                      uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);  

        [DllImport("kernel32.dll")]
        public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine,  ref SECURITY_ATTRIBUTES lpProcessAttributes,  ref SECURITY_ATTRIBUTES lpThreadAttributes, bool bInheritHandles, 
                                                uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll")]
        public static extern IntPtr WaitForSingleObject(IntPtr hHandle, long dwMilliseconds);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GetExitCodeProcess(IntPtr HANDLE, ref uint LPDWORD);



        public static bool StartProcessAsUser(IntPtr DuplicateUserTokenHandle, string CmdLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes, uint dwCreationFlags, string WorkingDir, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION ProcessInformations)
        {

            bool Started = CreateProcessAsUser(DuplicateUserTokenHandle, null, CmdLine, ref lpProcessAttributes, ref lpThreadAttributes, false, dwCreationFlags, IntPtr.Zero, WorkingDir, ref lpStartupInfo, out ProcessInformations);

            return Started;
        }


        public static bool StartProcess(string CmdLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes, uint dwCreationFlags, string WorkingDir, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION ProcessInformations)
        {

            bool Started = CreateProcess(null, CmdLine, ref lpProcessAttributes, ref lpThreadAttributes, false, dwCreationFlags, IntPtr.Zero, WorkingDir, ref lpStartupInfo, out ProcessInformations);

            return Started;
        }

    }
  
"@




Function Is-InWinPE() {


    Try { 

        $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue

        Return [System.Convert]::ToBoolean($TSEnvironment.Value("_SMSTSinWinPE"))

    } Catch { 
        
        Return $false
            
    } Finally {
    
        if ($null -ne $TSEnvironment) {

            [Void] [Runtime.InteropServices.Marshal]::ReleaseComObject($Onenote)
            [GC]::Collect()

        }
    
    }   

}



[HashTable] $KnownReturn = @{

    Success = 0
    OpenProcessFailure = 0x3E8
    OpenUserTokenFailure = 0x7D0
    DuplicateTokenFailure = 0xBB8
    EnvironmentBlockCreationFailure = 0xFA0
    ProcessCreationFailure = 0x1388

}


[SECURITY_ATTRIBUTES] $SecurityAttributes = [SECURITY_ATTRIBUTES]::New()
$SecurityAttributes.lpSecurityDescriptor = [IntPtr]::Zero
$SecurityAttributes.bInheritHandle = $false
$SecurityAttributes.Length = [Runtime.InteropServices.Marshal]::SizeOf($SecurityAttributes)


[STARTUPINFO] $StartupInformations = [STARTUPINFO]::New()
$StartupInformations.dwFlags = 0
$StartupInformations.lpDesktop = [String]::Empty
$StartupInformations.cb = [Runtime.InteropServices.Marshal]::SizeOf($StartupInformations)


[PROCESS_INFORMATION] $ProcessInformations = [PROCESS_INFORMATION]::New()


[String] $CurrentSID = (New-Object System.Security.Principal.NTAccount([Security.Principal.WindowsIdentity]::GetCurrent().Name)).Translate([Security.Principal.SecurityIdentifier]).Value

[Bool] $ProcessAsUser = $true

if ((Is-InWinPE) -or ($CurrentSID -ne "S-1-5-18")) {

    $ProcessAsUser = $false
}


if ($CmdLine.Contains(".\")) { 

    $CmdLine = $CmdLine.Replace(".\", "$PSScriptRoot\")

}

if ($WorkingDir.StartsWith(".\")) { 

    $WorkingDir = $CmdLine.Replace(".\", "$PSScriptRoot\")

}


if ($ProcessAsUser) {


    [Int] $WinLogonId = (Get-Process -Name winlogon -ErrorAction SilentlyContinue).Id


    [IntPtr] $ProcessHandle = [ProcessLoader]::OpenProcess([PROCESS_ACCESS_FLAGS]::All, $false, $WinLogonId) 

    if ($ProcessHandle -eq [IntPtr]::Zero) { 

        Return $KnownReturn.OpenProcessFailure

    } 


    [IntPtr] $ProcessTokenHandle = [IntPtr]::Zero

    [ProcessLoader]::OpenProcessToken($ProcessHandle, [DESIRED_ACCESS]::TokenDuplicate + [DESIRED_ACCESS]::TokenQuery + [DESIRED_ACCESS]::TokenImpersonate, [Ref] $ProcessTokenHandle) | Out-Null

    if ($ProcessTokenHandle -eq [IntPtr]::Zero) {

        [ProcessLoader]::CloseHandle($ProcessHandle) | Out-Null

        Return $KnownReturn.OpenUserTokenFailure

    }


    [IntPtr] $DuplicatedUserTokenHandle = [IntPtr]::Zero

    [ProcessLoader]::DuplicateTokenEx($ProcessTokenHandle, [DESIRED_ACCESS]::High, [Ref] $SecurityAttributes, [SECURITY_IMPERSONATION_LEVEL]::SecurityImpersonation, [TOKEN_TYPE]::TokenImpersonation, [Ref] $DuplicatedUserTokenHandle) | Out-Null

    if ($DuplicatedUserTokenHandle -eq [IntPtr]::Zero) {    

        [ProcessLoader]::CloseHandle($ProcessHandle) | Out-Null
        [ProcessLoader]::CloseHandle($ProcessTokenHandle) | Out-Null

        Return $KnownReturn.DuplicateTokenFailure

    }


    [Int] $CreationFlag = [PROCESS_CREATION_FLAGS]::CreateUnicodeEnvironment + [PROCESS_CREATION_FLAGS]::CreateNewConsole + [PROCESS_CREATION_FLAGS]::CreateBreakawayFromJob + [PROCESS_CREATION_FLAGS]::HighPriorityClass 

    $ProcessCreated = [ProcessLoader]::StartProcessAsUser($DuplicatedUserTokenHandle, $CmdLine, [Ref] $SecurityAttributes, [Ref] $SecurityAttributes, $CreationFlag, $WorkingDir, [Ref] $StartupInformations, [Ref] $ProcessInformations)

    [ProcessLoader]::CloseHandle($ProcessHandle) | Out-Null
    [ProcessLoader]::CloseHandle($ProcessTokenHandle) | Out-Null
    [ProcessLoader]::CloseHandle($DuplicatedUserTokenHandle) | Out-Null


} else {


    [Int] $CreationFlag = [PROCESS_CREATION_FLAGS]::CreateNewConsole + [PROCESS_CREATION_FLAGS]::HighPriorityClass 

    $ProcessCreated = [ProcessLoader]::StartProcess($CmdLine, [Ref] $SecurityAttributes, [Ref] $SecurityAttributes, $CreationFlag, $WorkingDir, [Ref] $StartupInformations, [Ref] $ProcessInformations)


}


if ($ProcessCreated) {


    [Int] $ExitCode = $KnownReturn.Success


    if ($Wait) { 

        [Int] $WaitInfinite = 0xFFFFFFFF

        [ProcessLoader]::WaitForSingleObject($ProcessInformations.hProcess, $WaitInfinite) | Out-Null

        [ProcessLoader]::GetExitCodeProcess($ProcessInformations.hProcess, [Ref]$ExitCode) | Out-Null


    } 


} else {

           
    $ExitCode = $KnownReturn.ProcessCreationFailure
 
                    
}


Return $ExitCode

