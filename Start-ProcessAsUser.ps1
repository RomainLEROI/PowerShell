
Param (

    [Parameter(Mandatory = $true)]
    [String] $CmdLine,

    [Parameter(Mandatory = $false)]
    [String] $WorkingDir = [Environment]::SystemDirectory,

    [Parameter(Mandatory = $false)]
    [Switch] $Wait

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

    public enum TOKEN_ACCESS : uint
    {
        TokenDuplicate = 0x00000002,
        TokenImpersonate = 0x00000004,
        TokenQuery = 0x00000008,
        TokenQuerySource = 0x00000010,
        TokenAdjustPrivileges = 0x00000020,
        TokenAdjustGroups = 0x00000040,
        TokenAdjustDefault = 0x00000080,
        TokenAdjustSessionId = 0x00000100,
        Delete = 0x00010000,
        ReadControl = 0x00020000,
        WriteDAC = 0x00040000,
        WriteOwner = 0x00080000,
        Synchronize = 0x00100000,
        StandardRightsRequired = 0x000F0000,
        TokenAllAccess = 0x001f01ff
    }

    public enum PROCESS_ACCESS : uint
    {
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
        Synchronize = 0x00100000,
        All = 0x001F0FFF
    }

    public enum PROCESS_CREATION : uint
    {
        DebugProcess = 0x00000001,
        DebugOnlyThisProcess = 0x00000002,
        CreateSuspended = 0x00000004,
        DetachedProcess = 0x00000008,
        CreateNewConsole = 0x00000010,
        NormalPriorityClass = 0x00000020,
        IdlePriorityClass = 0x00000040,
        HighPriorityClass = 0x00000080,
        RealtimePriorityClass = 0x00000100,
        CreateNewProcessGroup = 0x00000200,
        CreateUnicodeEnvironment = 0x00000400,
        CreateSeparateWowVdm = 0x00000800,
        CreateSharedWowVdm = 0x00001000,
        CreateForceDos = 0x00002000,
        BelowNormalPriorityClass = 0x00004000,
        AboveNormalPriorityClass = 0x00008000,
        InheritParentAffinity = 0x00010000,
        InheritCallerPriority = 0x00020000,
        CreateProtectedProcess = 0x00040000,
        ExtendedStartupInfoPresent = 0x00080000,
        ProcessModeBackgroundBegin = 0x00100000,
        ProcessModeBackgroundEnd = 0x00200000,
        CreateBreakawayFromJob = 0x01000000,
        CreatePreserveCodeAuthzLevel = 0x02000000,
        CreateDefaultErrorMode = 0x04000000,
        CreateNoWindow = 0x08000000,
        ProfileUser = 0x10000000,
        ProfileKernel = 0x20000000,
        ProfileServer = 0x40000000,
        CreateIgnoreSystemDefault = 0x80000000
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
        public static extern bool OpenProcessToken(IntPtr hProcessHandle, uint dwDesiredAccess, ref IntPtr hTokenHandle);

        [DllImport("kernel32.dll")]
        public static extern bool CloseHandle(IntPtr hSnapshot);
   
        [DllImport("advapi32.dll")]
        public static extern bool DuplicateTokenEx(IntPtr hExistingToken, uint dwDesiredAccess, ref SECURITY_ATTRIBUTES lpTokenAttributes, SECURITY_IMPERSONATION_LEVEL lpImpersonationLevel, TOKEN_TYPE tokenType, out IntPtr phNewToken);
        
        [DllImport("advapi32.dll")]
        public static extern bool CreateProcessAsUser(IntPtr hToken, string lpApplicationName, string lpCommandLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);  
        
        [DllImport("kernel32.dll")]
        public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine,  ref SECURITY_ATTRIBUTES lpProcessAttributes,  ref SECURITY_ATTRIBUTES lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
        
        [DllImport("kernel32.dll")]
        public static extern IntPtr WaitForSingleObject(IntPtr hHandle, long dwMilliseconds);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GetExitCodeProcess(IntPtr HANDLE, ref uint LPDWORD);

        public static bool StartProcessAsUser(IntPtr duplicateUserTokenHandle, string cmdLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes, uint dwCreationFlags, string workingDir, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION processInformations)
        {
            return CreateProcessAsUser(duplicateUserTokenHandle, null, cmdLine, ref lpProcessAttributes, ref lpThreadAttributes, false, dwCreationFlags, IntPtr.Zero, workingDir, ref lpStartupInfo, out processInformations);
        }
        public static bool StartProcess(string cmdLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes, uint dwCreationFlags, string workingDir, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION processInformations)
        {
            return CreateProcess(null, cmdLine, ref lpProcessAttributes, ref lpThreadAttributes, false, dwCreationFlags, IntPtr.Zero, workingDir, ref lpStartupInfo, out processInformations);
        }
    }
  
"@


Function Is-InWinPE {


    Param()

    Try { 

        [__ComObject] $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue

        Return [Convert]::ToBoolean($TSEnvironment.Value("_SMSTSinWinPE"))

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

    Success = 0x0
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


[String] $CurrentSID = ([Security.Principal.NTAccount]::New([Security.Principal.WindowsIdentity]::GetCurrent().Name)).Translate([Security.Principal.SecurityIdentifier]).Value

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


    [Int] $WinLogonId = (Get-Process -Name winlogon).Id
    
    [IntPtr] $ProcessHandle = [ProcessLoader]::OpenProcess([PROCESS_ACCESS]::All, $false, $WinLogonId) 

    if ($ProcessHandle -eq [IntPtr]::Zero) { 

        Exit $KnownReturn.OpenProcessFailure

    } 


    [IntPtr] $ProcessTokenHandle = [IntPtr]::Zero

    [Int] $TokenAccess = [TOKEN_ACCESS]::TokenDuplicate + [TOKEN_ACCESS]::TokenQuery + [TOKEN_ACCESS]::TokenImpersonate

    [Void] [ProcessLoader]::OpenProcessToken($ProcessHandle, $TokenAccess, [Ref] $ProcessTokenHandle)

    [Void] [ProcessLoader]::CloseHandle($ProcessHandle)

    if ($ProcessTokenHandle -eq [IntPtr]::Zero) {
       
        Exit $KnownReturn.OpenUserTokenFailure

    }

    
    [IntPtr] $DuplicatedUserTokenHandle = [IntPtr]::Zero

    [Int] $MaximumAllowed = 0x10000000

    [Void] [ProcessLoader]::DuplicateTokenEx($ProcessTokenHandle, $MaximumAllowed, [Ref] $SecurityAttributes, [SECURITY_IMPERSONATION_LEVEL]::SecurityImpersonation, [TOKEN_TYPE]::TokenImpersonation, [Ref] $DuplicatedUserTokenHandle)

    [Void] [ProcessLoader]::CloseHandle($ProcessTokenHandle)

    if ($DuplicatedUserTokenHandle -eq [IntPtr]::Zero) {    
       
        Exit $KnownReturn.DuplicateTokenFailure

    }


    [Int] $CreationFlag = [PROCESS_CREATION]::CreateUnicodeEnvironment + [PROCESS_CREATION]::CreateNewConsole + [PROCESS_CREATION]::CreateBreakawayFromJob + [PROCESS_CREATION]::HighPriorityClass

    $ProcessCreated = [ProcessLoader]::StartProcessAsUser($DuplicatedUserTokenHandle, $CmdLine, [Ref] $SecurityAttributes, [Ref] $SecurityAttributes, $CreationFlag, $WorkingDir, [Ref] $StartupInformations, [Ref] $ProcessInformations)

    [Void] [ProcessLoader]::CloseHandle($DuplicatedUserTokenHandle)


} else {


    [Int] $CreationFlag = [PROCESS_CREATION]::CreateNewConsole + [PROCESS_CREATION]::HighPriorityClass

    $ProcessCreated = [ProcessLoader]::StartProcess($CmdLine, [Ref] $SecurityAttributes, [Ref] $SecurityAttributes, $CreationFlag, $WorkingDir, [Ref] $StartupInformations, [Ref] $ProcessInformations)


}


if ($ProcessCreated) {


    [Int] $ExitCode = $KnownReturn.Success


    if ($Wait) { 

        [Int] $WaitInfinite = 0xFFFFFFFF

        [Void] [ProcessLoader]::WaitForSingleObject($ProcessInformations.hProcess, $WaitInfinite)

        [Void] [ProcessLoader]::GetExitCodeProcess($ProcessInformations.hProcess, [Ref]$ExitCode)

    } 


} else {
          
    $ExitCode = $KnownReturn.ProcessCreationFailure
                    
}


Exit $ExitCode
