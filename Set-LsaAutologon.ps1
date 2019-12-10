Param (

    [Parameter(ParameterSetName = "Add", Mandatory = $true)]
    [Switch] $Add,

    [Parameter(ParameterSetName = "Remove", Mandatory = $true)]
    [Switch] $Remove,

    [Parameter(ParameterSetName = "Add", Mandatory = $true)]
    [String] $DefaultUserName,

    [Parameter(ParameterSetName = "Add", Mandatory = $true)]
    [String] $DefaultPassword,

    [Parameter(ParameterSetName = "Add", Mandatory = $false)]
    [String] $DefaultDomainName = $env:COMPUTERNAME

)



if (!([Management.Automation.PSTypeName]'LSAutil').Type) {

    Add-Type -TypeDefinition @"

        using System;
        using System.Runtime.InteropServices;

        [StructLayout(LayoutKind.Sequential)]
        public struct LSA_UNICODE_STRING
        {
            public UInt16 Length;
            public UInt16 MaximumLength;
            public IntPtr Buffer;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct LSA_OBJECT_ATTRIBUTES
        {
            public int Length;
            public IntPtr RootDirectory;
            public LSA_UNICODE_STRING ObjectName;
            public uint Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }

        public enum LSA_AccessPolicy : long
        {
            POLICY_VIEW_LOCAL_INFORMATION = 0x00000001L,
            POLICY_VIEW_AUDIT_INFORMATION = 0x00000002L,
            POLICY_GET_PRIVATE_INFORMATION = 0x00000004L,
            POLICY_TRUST_ADMIN = 0x00000008L,
            POLICY_CREATE_ACCOUNT = 0x00000010L,
            POLICY_CREATE_SECRET = 0x00000020L,
            POLICY_CREATE_PRIVILEGE = 0x00000040L,
            POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080L,
            POLICY_SET_AUDIT_REQUIREMENTS = 0x00000100L,
            POLICY_AUDIT_LOG_ADMIN = 0x00000200L,
            POLICY_SERVER_ADMIN = 0x00000400L,
            POLICY_LOOKUP_NAMES = 0x00000800L,
            POLICY_NOTIFICATION = 0x00001000L
        }

        public class LSAutil
        {

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            public static extern uint LsaRetrievePrivateData(IntPtr PolicyHandle, ref LSA_UNICODE_STRING KeyName, out IntPtr PrivateData);

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            public static extern uint LsaStorePrivateData(IntPtr policyHandle, ref LSA_UNICODE_STRING KeyName, ref LSA_UNICODE_STRING PrivateData);

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            public static extern uint LsaOpenPolicy(ref LSA_UNICODE_STRING SystemName, ref LSA_OBJECT_ATTRIBUTES ObjectAttributes, uint DesiredAccess, out IntPtr PolicyHandle);

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            public static extern uint LsaNtStatusToWinError(uint status);

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            public static extern uint LsaClose(IntPtr policyHandle);

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            public static extern uint LsaFreeMemory(IntPtr buffer);

        }

"@

}


[LSA_OBJECT_ATTRIBUTES] $objectAttributes = [LSA_OBJECT_ATTRIBUTES]::new()
$objectAttributes.Length = 0
$objectAttributes.RootDirectory = [IntPtr]::Zero
$objectAttributes.Attributes = 0
$objectAttributes.SecurityDescriptor = [IntPtr]::Zero
$objectAttributes.SecurityQualityOfService = [IntPtr]::Zero

[LSA_UNICODE_STRING] $localsystem = [LSA_UNICODE_STRING]::new()
$localsystem.Buffer = [IntPtr]::Zero
$localsystem.Length = 0
$localsystem.MaximumLength = 0

[LSA_UNICODE_STRING] $secretName = [LSA_UNICODE_STRING]::new()
$secretName.Buffer = [Runtime.InteropServices.Marshal]::StringToHGlobalUni("DefaultPassword")
$secretName.Length = ("DefaultPassword").Length * [Text.UnicodeEncoding]::CharSize
$secretName.MaximumLength = (("DefaultPassword").Length + 1) * [Text.UnicodeEncoding]::CharSize

[LSA_UNICODE_STRING] $lusSecretData = [LSA_UNICODE_STRING]::new()

if ($Add) {

    $lusSecretData.Buffer = [Runtime.InteropServices.Marshal]::StringToHGlobalUni($DefaultPassword)
    $lusSecretData.Length = $DefaultPassword.Length * [Text.UnicodeEncoding]::CharSize
    $lusSecretData.MaximumLength = ($DefaultPassword.Length + 1) * [Text.UnicodeEncoding]::CharSize

} elseif ($Remove) {

    $lusSecretData.Buffer = [IntPtr]::Zero;
    $lusSecretData.Length = 0;
    $lusSecretData.MaximumLength = 0;

}

[IntPtr] $LsaPolicyHandle = [IntPtr]::Zero

[Int] $result = [LSAutil]::LsaOpenPolicy([Ref] $localsystem, [Ref] $objectAttributes, [LSA_AccessPolicy]::POLICY_CREATE_SECRET, [Ref] $LsaPolicyHandle);


if ([LSAutil]::LsaNtStatusToWinError($result) -eq 0) {


    $result = [LSAutil]::LsaStorePrivateData($LsaPolicyHandle, [Ref] $secretName, [Ref] $lusSecretData);

    if ([LSAutil]::LsaNtStatusToWinError($result) -eq 0) {


        Try {

            [Microsoft.Win32.RegistryKey] $Key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)

            $Key = $Key.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", $true)

            $Key.SetValue("DefaultUserName", $DefaultUserName)

            $Key.SetValue("DefaultDomainName", $DefaultDomainName)

            $Key.SetValue("AutoAdminLogon", 1)

            if ($null -ne $Key.GetValue("AutoLogonCount")) {

                $Key.DeleteValue("AutoLogonCount")

            }

            $Key.Close()
            $Key.Dispose()

        } Catch {

            Return 30

        }
  
    }

    $result = [LSAutil]::LsaClose($LsaPolicyHandle)

    if ([LSAutil]::LsaNtStatusToWinError($result) -ne 0) {

        Return 20

    }


} else {

    Return 10
}
