
param(

    [Parameter(Mandatory = $true)]
    [String] $CmdLine,

    [Parameter(Mandatory = $false)]
    [Switch] $Interactive,

    [Parameter(Mandatory = $false)]
    [Switch] $Wait,

    [Parameter(Mandatory = $false)]
    [Switch] $LimitPrivileges


)



Add-Type -TypeDefinition @"

    using System;
    using System.Security;
    using System.Diagnostics;
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
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
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

    public enum PROCESS_CREATION_FLAG : uint
    {
        CreateNewConsole = 0x00000010,
        CreateNoWindow = 0x08000000,
        CreateBreakawayFromJob = 0x01000000,
        CreateUnicodeEnvironment = 0x00000400,
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
        public static extern uint WTSGetActiveConsoleSessionId(); 

        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, 
                                                bool bInheritHandle,
                                                uint dwProcessId);

        [DllImport("advapi32")]
        public static extern bool OpenProcessToken(IntPtr ProcessHandle,
                                                   int DesiredAccess, 
                                                   ref IntPtr TokenHandle);

        [DllImport("kernel32.dll")]
        public static extern bool CloseHandle(IntPtr hSnapshot);

    
        [DllImport("advapi32.dll")]
        public static extern bool DuplicateTokenEx(IntPtr hExistingToken,
                                                   uint dwDesiredAccess,
                                                   ref SECURITY_ATTRIBUTES lpTokenAttributes,
                                                   SECURITY_IMPERSONATION_LEVEL ImpersonationLevel,
                                                   TOKEN_TYPE TokenType,
                                                   out IntPtr phNewToken);

        [DllImport("wtsapi32.dll")]
        public static extern bool WTSQueryUserToken(Int32 sessionId, 
                                                    out IntPtr Token);

        [DllImport("userenv.dll")]
        public static extern bool CreateEnvironmentBlock(out IntPtr lpEnvironment, 
                                                        IntPtr hToken, 
                                                        bool bInherit);

        [DllImport("advapi32.dll")]
        public static extern bool CreateProcessAsUser(IntPtr hToken,
                                                      string lpApplicationName,
                                                      string lpCommandLine,
                                                      ref SECURITY_ATTRIBUTES lpProcessAttributes,
                                                      ref SECURITY_ATTRIBUTES lpThreadAttributes,
                                                      bool bInheritHandles,
                                                      uint dwCreationFlags,
                                                      IntPtr lpEnvironment,
                                                      string lpCurrentDirectory,
                                                      ref STARTUPINFO lpStartupInfo,
                                                      out PROCESS_INFORMATION lpProcessInformation);  

        [DllImport("kernel32.dll")]
	    public static extern bool CreateProcess(string lpApplicationName,
                                                string lpCommandLine, 
                                                ref SECURITY_ATTRIBUTES lpProcessAttributes, 
                                                ref SECURITY_ATTRIBUTES lpThreadAttributes, 
                                                bool bInheritHandles, 
                                                uint dwCreationFlags, 
                                                IntPtr lpEnvironment, 
                                                string lpCurrentDirectory, 
                                                ref STARTUPINFO lpStartupInfo, 
                                                out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll")]
        public static extern IntPtr WaitForSingleObject(IntPtr hHandle, 
                                                        long dwMilliseconds);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GetExitCodeProcess(IntPtr HANDLE, 
                                                       ref uint LPDWORD);




        public static bool StartProcessAsUser(IntPtr DuplicateUserTokenHandle,
                                                   string CmdLine,
                                                   ref SECURITY_ATTRIBUTES lpProcessAttributes,
                                                   ref SECURITY_ATTRIBUTES lpThreadAttributes,
                                                   uint dwCreationFlags,
                                                   string WorkingDir,
                                                   ref STARTUPINFO lpStartupInfo,
                                                   out PROCESS_INFORMATION ProcessInformations)
        {

            bool Started = CreateProcessAsUser(DuplicateUserTokenHandle,
                                               null,
                                               CmdLine,
                                               ref lpProcessAttributes,
                                               ref lpThreadAttributes,
                                               false,
                                               dwCreationFlags,
                                               IntPtr.Zero,
                                               WorkingDir,
                                               ref lpStartupInfo,
                                               out ProcessInformations);

            return Started;


        }







    }
  
"@






[HashTable] $PROCESS_ERROR = @{

    OpenProcessFailure = 1000
    OpenUserTokenFailure = 2000
    DuplicateTokenFailure = 0xBB8
    EnvironmentBlockCreationFailure = 0xFA0
    ProcessCreationFailure = 0x1388
    ImpersonateTokenFailure = 6000

}


[IntPtr] $EnvironmentBlock = [IntPtr]::Zero

[Bool] $Inherit = $false


[HastTable] $OpenProcessAccess = @{

    Highest = 0x2000000

}


[HastTable] $OpenProcessTokenAccess = @{

    TokenDuplicate = 0x0002
    TokenImpersonate = 0x0004
    TokenQuery = 0x0008

}


[HastTable] $DuplicateTokenAccess = @{

    Highest = 0x10000000
    Lowest = 0x0

}


#[SECURITY_ATTRIBUTES] $SecurityAttributes = [SECURITY_ATTRIBUTES]::New()
$SecurityAttributes = New-Object SECURITY_ATTRIBUTES

$SecurityAttributes.lpSecurityDescriptor = [IntPtr]::Zero
$SecurityAttributes.bInheritHandle = $Inherit
$SecurityAttributes.Length = [Runtime.InteropServices.Marshal]::SizeOf($SecurityAttributes)

[IntPtr] $ImpersonateToken = [IntPtr]::Zero


<#if ($LimitPrivileges) {


    [Int] $ActiveSessionId = [ProcessLoader]::WTSGetActiveConsoleSessionId()

    $ProcessHandle = [ProcessLoader]::OpenProcess(0x2000000, $False, $WinLogonId)

   
    


    #if ($LimitPrivileges) {

        #[ProcessLoader]::DuplicateTokenEx($ImpersonateToken, $DuplicateTokenAccess.Lowest, [Ref] $SecurityAttributes, [SECURITY_IMPERSONATION_LEVEL]::SecurityImpersonation -as [int], [TOKEN_TYPE]::TokenPrimary -as [int], [Ref] $DuplicatedToken) | Out-Null

        #[ProcessLoader]::DuplicateTokenEx($ImpersonateToken, $DuplicateTokenAccess.Lowest, [Ref] $SecurityAttributes, [SECURITY_IMPERSONATION_LEVEL]::SecurityImpersonation -as [int], [TOKEN_TYPE]::TokenPrimary -as [int], [Ref] $DuplicatedToken) | Out-Null

    #} else {

       [ProcessLoader]::DuplicateTokenEx($ImpersonateToken, 0x10000000, [Ref] $SecurityAttributes, [SECURITY_IMPERSONATION_LEVEL]::SecurityImpersonation -as [int], [TOKEN_TYPE]::TokenImpersonation -as [int], [Ref] $DuplicatedToken) | Out-Null

    #}

    
    if ([IntPtr]::Zero -eq $DuplicatedToken) {

        [ProcessLoader]::CloseHandle($ImpersonateToken)

        [Environment]::Exit($PROCESS_ERROR.DuplicateTokenFailure)

    }


    [ProcessLoader]::CreateEnvironmentBlock([ref] $EnvironmentBlock, $DuplicatedToken, $Inherit) | Out-Null

    if ([IntPtr]::Zero -eq $EnvironmentBlock) {

        [ProcessLoader]::CloseHandle($ImpersonateToken)

        [ProcessLoader]::CloseHandle($DuplicatedToken)

        [Environment]::Exit($PROCESS_ERROR.EnvironmentBlockCreationFailure)

    }





} else { #>




    #[Int] $WinLogonProcessId = (Get-Process -Name winlogon).Id

    [Int] $ActiveSessionId = [ProcessLoader]::WTSGetActiveConsoleSessionId()

    [ProcessLoader]::WTSQueryUserToken($ActiveSessionId, [Ref] $ImpersonateToken) | Out-Null


    <#
    [Int] $MaxAllowed = 0x2000000

    [IntPtr] $Process = [ProcessLoader]::OpenProcess($MaxAllowed, $Inherit, $WinLogonProcessId);

    if ([IntPtr]::Zero -eq $Process) {

        [Environment]::Exit($PROCESS_ERROR.OpenProcessFailure)

    }


    [Int] $TokenDesiredAccess = $OpenProcessTokenAccess.TokenDuplicate + $OpenProcessTokenAccess.TokenImpersonate + $OpenProcessTokenAccess.TokenQuery

    [ProcessLoader].OpenProcessToken($Process, $TokenDesiredAccess, [Ref] $ImpersonateToken) | Out-Null

    if ([IntPtr]::Zero -eq $ImpersonateToken) {

        [ProcessLoader]::CloseHandle($Process)

        [Environment]::Exit($PROCESS_ERROR.OpenUserTokenFailure)

    }
    #>


    [ProcessLoader]::DuplicateTokenEx($ImpersonateToken,
                                      $DuplicateTokenAccess.Highest, 
                                      [Ref] $SecurityAttributes, 
                                      [SECURITY_IMPERSONATION_LEVEL]::SecurityImpersonation -as [int], 
                                      [TOKEN_TYPE].TokenImpersonation -as [int], 
                                      [Ref] $DuplicatedToken) | Out-Null




    if ([IntPtr]::Zero -eq $DuplicatedToken) {

        [ProcessLoader]::CloseHandle($Process)

        [ProcessLoader]::CloseHandle($ImpersonateToken)

        [Environment]::Exit($PROCESS_ERROR.DuplicateTokenFailure)

    }

    <#
    [ProcessLoader]::CreateEnvironmentBlock([ref] $EnvironmentBlock, $DuplicatedToken, $Inherit) | Out-Null

    if ([IntPtr]::Zero -eq $EnvironmentBlock) {

        [ProcessLoader]::CloseHandle($Process)

        [ProcessLoader]::CloseHandle($ImpersonateToken)

        [ProcessLoader]::CloseHandle($DuplicatedToken)

        [Environment]::Exit($PROCESS_ERROR.EnvironmentBlockCreationFailure)

    }
    #>


#}


[HastTable] $nCmdShow = @{

    SW_SHOW = 5
    SW_HIDE = 0

}

        $StartupInformations = New-Object STARTUPINFO

#[STARTUPINFO] $StartupInformations = [STARTUPINFO]::New()
$StartupInformations.dwFlags =  0   <#STARTF_USESHOWWINDOW

if ($Interactive) {

    $StartupInformations.wShowWindow = $nCmdShow.SW_SHOW

} else {

    $StartupInformations.wShowWindow = $nCmdShow.SW_HIDE

}#>

$StartupInformations.lpDesktop = [String]::Empty
$StartupInformations.cb = [Runtime.InteropServices.Marshal]::SizeOf($StartupInformations)

#[PROCESS_INFORMATION] $ProcessInformations = [PROCESS_INFORMATION]::New()
        $ProcessInformations = New-Object PROCESS_INFORMATION

[Int] $CreationFlag = [PROCESS_CREATION_FLAG]::CreateBreakawayFromJob


#[Bool] $ProcessCreated = [ProcessLoader]::CreateProcessAsUser($DuplicatedToken, $null, $CmdLine, $SecurityAttributes, $SecurityAttributes, $Inherit, $CreationFlag, $EnvironmentBlock, [Environment]::SystemDirectory, $StartupInformations, [Ref] $ProcessInformations)

#[Bool] $ProcessCreated = [ProcessLoader]::CreateProcessAsUser($DuplicatedToken, $CmdLine, $null, $SecurityAttributes, $SecurityAttributes, $Inherit, $CreationFlag, $EnvironmentBlock, [Environment]::SystemDirectory, $StartupInformations, [Ref] $ProcessInformations)


    $ProcessCreated = [ProcessLoader]::StartProcessAsUser($DuplicatedToken, 
                                                              $CmdLine, 
                                                              [ref]$SecurityAttributes, 
                                                              [ref]$SecurityAttributes, 
                                                              $CreationFlag, 
                                                              [Environment]::SystemDirectory, 
                                                              [ref]$StartupInformations, 
                                                              [ref]$ProcessInformations)






            
if ($ProcessCreated) {


    [Int] $ExitCode = 0

    if ($Wait) {

        [ProcessLoader]::WaitForSingleObject($ProcessInformations.hProcess, -1)

        [ProcessLoader]::GetExitCodeProcess($ProcessInformations.hProcess, [Ref] $ExitCode)

    }

    [ProcessLoader]::DestroyEnvironmentBlock($EnvironmentBlock)
    [ProcessLoader]::CloseHandle($ImpersonateToken)
    [ProcessLoader]::CloseHandle($DuplicatedToken)

    [Environment]::Exit($ExitCode)


} else {

    [ProcessLoader]::DestroyEnvironmentBlock($EnvironmentBlock)
    [ProcessLoader]::CloseHandle($ImpersonateToken)
    [ProcessLoader]::CloseHandle($DuplicatedToken)

    [Environment]::Exit($PROCESS_ERROR.ProcessCreationFailure)

}























