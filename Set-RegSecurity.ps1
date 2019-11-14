
Param ( 

    [Parameter(Mandatory = $true)]
    [ValidateSet('LocalMachine', 'ClassesRoot', 'Users')]
    [String] $Hive,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet('Registry32', 'Registry64')]
    [String] $View,
    
    [Parameter(Mandatory = $true)]
    [String] $Path,

    [Parameter(Mandatory = $true)]
    # BUILTIN\Administrateurs, AUTORITE NT\Système, BUILTIN\Utilisateurs, <Domain>\<Group>, <Domain>\<User>, <Computer>\<User>...
    [ValidatePattern("[a-zA-Z]\\[a-zA-Z0-9]")]
    [String] $Identity,

    [Parameter(Mandatory = $true)]
    [ValidateSet('FullControl', 'ReadPermissions', 'ChangePermissions')]
    [String] $Permission,

    [Parameter(Mandatory = $false)]
    [String] $ComputerName = $env:COMPUTERNAME
  
)


Function Is-Online {

    Param (

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


        [Hashtable] $HiveTable = @{

            LocalMachine = [Microsoft.Win32.RegistryHive]::LocalMachine
            ClassesRoot = [Microsoft.Win32.RegistryHive]::ClassesRoot
            Users = [Microsoft.Win32.RegistryHive]::Users

        }

        [Int] $Root = $HiveTable[$Hive]



        [Hashtable] $ViewTable = @{

            Registry32 = [Microsoft.Win32.RegistryView]::Registry32
            Registry64 = [Microsoft.Win32.RegistryView]::Registry64

        }

        [Int] $Node = $ViewTable[$View]


        [Hashtable] $PermissionTable = @{
                 
            FullControl = [Security.AccessControl.RegistryRights]::FullControl
            ReadPermissions =[Security.AccessControl.RegistryRights]::ReadPermissions
            ChangePermissions = [Security.AccessControl.RegistryRights]::ChangePermissions
        
        }

        [Int] $AccessMask = $PermissionTable[$Permission]


        [Microsoft.Win32.RegistryKey] $RootKey

        if (Is-LocalHost -ComputerName $ComputerName) {

            $RootKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Root, $Node)

        } else {

            $RootKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Root, $ComputerName, $Node)

        }


        [Microsoft.Win32.RegistryKey] $Key = $RootKey.OpenSubKey($Path, $true)

        [Int] $InheritanceFlag = [Security.AccessControl.InheritanceFlags]::ContainerInherit + [Security.AccessControl.InheritanceFlags]::ObjectInherit 

        [Int] $PropagationFlag = [Security.AccessControl.PropagationFlags]::None 

        [Int] $AccessControlType = [Security.AccessControl.AccessControlType]::Allow 

        [Security.AccessControl.RegistryAccessRule] $Ace = [Security.AccessControl.RegistryAccessRule]::new($Identity, $AccessMask, $InheritanceFlag, $PropagationFlag, $AccessControlType)

        [Security.AccessControl.RegistrySecurity] $Acl = $Key.GetAccessControl()

        $Acl.AddAccessRule($Ace)

        if (!(Is-LocalHost -ComputerName $ComputerName)) {

            $Acl.SetAccessRuleProtection($true, $true)
        }

        $Key.SetAccessControl($Acl)

        $Key.Close()

        $Key.Dispose()

    
    }  else {

        Write-Output -InputObject "$ComputerName is not online"

    }
   
} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
