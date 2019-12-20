
Param(

    [Parameter(Mandatory = $true)]
    [String] $CmdLine,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("[a-zA-Z]\\[a-zA-Z0-9]")]
    [String] $Identity,

    [Parameter(Mandatory = $true)]
    [String] $UserPass,

    [Parameter(Mandatory = $false)]
    [String] $WorkingDir = [Environment]::SystemDirectory,

    [Parameter(Mandatory = $false)]
    [Switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [Switch]$Wait

)


if (!([Management.Automation.PSTypeName]'ProcessAs').Type) {

    Add-Type -TypeDefinition @"

        using System;
        using System.Runtime.InteropServices;

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

        public enum LOGON_FLAGS : uint
        {
            LogonWithProfile = 0x00000001,
            LogonNetCredentialsOnly = 0x00000002
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


  
        public static class ProcessAs
        {

            [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
            public static extern bool CreateProcessWithLogonW(string userName, string domain, string password, int logonFlags, string applicationName, string commandLine, int creationFlags, IntPtr environment, string currentDirectory, ref STARTUPINFO startupInfo, out PROCESS_INFORMATION processInformation);      

            [DllImport("kernel32.dll")]
            public static extern IntPtr WaitForSingleObject(IntPtr hHandle, long dwMilliseconds);

            [DllImport("kernel32.dll")]
            public static extern IntPtr GetExitCodeProcess(IntPtr HANDLE, ref uint LPDWORD);


            public static bool StartProcessAs(string domain, string userName, string password, int logonFlags, string cmdline, string workingDir, int creationFlags, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION processInformations)
            {

                return CreateProcessWithLogonW(userName, domain, password, logonFlags, null, cmdline, creationFlags, IntPtr.Zero, workingDir, ref lpStartupInfo, out processInformations);

            }

        }
  
"@

}



$StartupInformations = New-Object -TypeName STARTUPINFO

$StartupInformations.dwFlags = 1

if ($Interactive) {

    $StartupInformations.wShowWindow = 1

} else {

    $StartupInformations.wShowWindow = 0

}

$StartupInformations.cb = [Runtime.InteropServices.Marshal]::SizeOf($StartupInformations)


$ProcessInformations = New-Object -TypeName PROCESS_INFORMATION


if ($CmdLine.Contains(".\")) { 

    $CmdLine = $CmdLine.Replace(".\", "$PSScriptRoot\")

}

if ($WorkingDir.StartsWith(".\")) { 

    $WorkingDir = $CmdLine.Replace(".\", "$PSScriptRoot\")

}


$NTAccount = $Identity.Split('\')

$UserDomain = $NTAccount[0]

$UserName = $NTAccount[1]

$ProcessCreated = [ProcessAs]::StartProcessAs($UserDomain, $UserName, $UserPass, [LOGON_FLAGS]::LogonNetCredentialsOnly, $CmdLine, $WorkingDir, [PROCESS_CREATION]::CreateDefaultErrorMode, [Ref] $StartupInformations, [Ref] $ProcessInformations)


if ($ProcessCreated) {

    $ExitCode = $KnownReturn.Success

    if ($Wait) { 

        $WaitInfinite = 0xFFFFFFFF

        [Void] [ProcessAs]::WaitForSingleObject($ProcessInformations.hProcess, $WaitInfinite)

        [Void] [ProcessAs]::GetExitCodeProcess($ProcessInformations.hProcess, [Ref] $ExitCode)

    } 


} else {

           
    $ExitCode = 10
 
                    
}


Exit $ExitCode
