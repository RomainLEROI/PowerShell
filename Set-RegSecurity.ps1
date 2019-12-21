
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

    [Parameter(Mandatory = $false)]
    [String] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [ValidateSet('FullControl', 'ReadPermissions', 'ChangePermissions')]
    [String] $Rights,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Allow', 'Deny')]
    [String] $AccessType = 'Allow',

    [Parameter(Mandatory = $false)]
    [Switch] $Remove

)


$IsElevated = ([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if ($IsElevated) {

    $IsLocalHost = (($ComputerName -eq $env:COMPUTERNAME) -or ($ComputerName -eq 'localhost') -or ($ComputerName -eq '.') -or (((Get-NetIPAddress).IPAddress).Contains($ComputerName)))
    
    if ($IsLocalHost) {

        $IsOnline = $true

    } else {

        $IsOnline = Try { Write-Output (Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

    }
    
    if ($IsOnline) {

        $HiveTable = @{

            LocalMachine = [Microsoft.Win32.RegistryHive]::LocalMachine
            ClassesRoot = [Microsoft.Win32.RegistryHive]::ClassesRoot
            Users = [Microsoft.Win32.RegistryHive]::Users

        }

        $Root = $HiveTable[$Hive]

        $ViewTable = @{

            Registry32 = [Microsoft.Win32.RegistryView]::Registry32
            Registry64 = [Microsoft.Win32.RegistryView]::Registry64

        }

        $Node = $ViewTable[$View]

        $RightsTable = @{
                 
            FullControl = [Security.AccessControl.RegistryRights]::FullControl
            ReadPermissions = [Security.AccessControl.RegistryRights]::ReadPermissions
            ChangePermissions = [Security.AccessControl.RegistryRights]::ChangePermissions
        
        }

        $AccessMask = $RightsTable[$Rights]

        $AccessTypeTable = @{
                 
            Allow = [Security.AccessControl.AccessControlType]::Allow
            Deny = [Security.AccessControl.AccessControlType]::Deny 
        
        }

        $AccessControlType = $AccessTypeTable[$AccessType]


        Try {

            if ($IsLocalHost) {

                $RootKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Root, $Node)

            } else {

                $RootKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Root, $ComputerName, $Node)

            }

            $Key = $RootKey.OpenSubKey($Path, $true)

            if ($null -ne $Key) {

                $InheritanceFlag = [Security.AccessControl.InheritanceFlags]::ContainerInherit + [Security.AccessControl.InheritanceFlags]::ObjectInherit 

                $PropagationFlag = [Security.AccessControl.PropagationFlags]::None 
    
                $Ace = New-Object TypeName Security.AccessControl.RegistryAccessRule($Identity, $AccessMask, $InheritanceFlag, $PropagationFlag, $AccessControlType)

                $Acl = $Key.GetAccessControl()
                
                if (!(Is-LocalHost -ComputerName $ComputerName)) {

                    $Acl.SetAccessRuleProtection($true, $true)
                }

                if ($Remove) {

                    $Acl.RemoveAccessRule($Ace)

                } else {

                    $Acl.AddAccessRule($Ace)

                }

                $Key.SetAccessControl($Acl)
             
            } else {

                Write-Warning -Message "Registry key not found not found"

            }

        } Catch {

            Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"

        } Finally {

            foreach ($Disposable in @($Key, $RootKey)) {

                if ($null -ne $Disposable) {

                    [Void] $Disposable.Close()
                    [Void] $Disposable.Dispose()

                }

            }

        }

    }  else {

        Write-Warning -Message "$ComputerName is not online"

    }
   
} else {

    Write-Warning -Message "The requested operation requires elevation"

}
