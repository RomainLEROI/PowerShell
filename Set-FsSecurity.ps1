
Param ( 

    [Parameter(Mandatory = $true)]
    [String] $Path,

    [Parameter(Mandatory = $true)]
    # BUILTIN\Administrateurs, AUTORITE NT\Système, BUILTIN\Utilisateurs, <Domain>\<Group>, <Domain>\<User>, <Computer>\<User>...
    [ValidatePattern("[a-zA-Z]\\[a-zA-Z0-9]")]
    [String] $Identity,

    [Parameter(Mandatory = $false)]
    [String] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [ValidateSet('FullControl', 'Modify', 'ReadAndExecute', 'Read', 'Write')]
    [String[]] $Rights,

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

        if (!$IsLocalHost -and ($Path -match "^[a-zA-Z]:\\")) {

            $Path = "\\$ComputerName\$($Path.Replace(":", "$"))"

        }

        if (Test-Path -Path $Path) {
        
            Try {

                $RightsTable = @{
                 
                    FullControl = [Security.AccessControl.FileSystemRights]::FullControl
                    Modify = [Security.AccessControl.FileSystemRights]::Modify
                    ReadAndExecute = [Security.AccessControl.FileSystemRights]::ReadAndExecute
                    Read = [Security.AccessControl.FileSystemRights]::Read
                    Write = [Security.AccessControl.FileSystemRights]::Write
        
                }

     
                $AccessMask = 0

                foreach ($Right in $Rights) {

                    $AccessMask += $RightsTable[$Right]

                }

                $PropagationFlag = [Security.AccessControl.PropagationFlags]::None 

                $AccessTypeTable = @{
                 
                    Allow = [Security.AccessControl.AccessControlType]::Allow
                    Deny = [Security.AccessControl.AccessControlType]::Deny 
        
                }

                $AccessControlType = $AccessTypeTable[$AccessType]


                if ((Get-Item -Path $Path).PSIsContainer) {

                    $InheritanceFlag = [Security.AccessControl.InheritanceFlags]::ContainerInherit + [Security.AccessControl.InheritanceFlags]::ObjectInherit
         
                    $Ace = New-Object -TypeName Security.AccessControl.FileSystemAccessRule($Identity, $AccessMask, $InheritanceFlag, $PropagationFlag, $AccessControlType)

                    $Acl = [IO.Directory]::GetAccessControl($path)

                    if ($Remove) {

                        $Acl.RemoveAccessRule($Ace)

                    } else {

                        $Acl.AddAccessRule($Ace)

                    }

                    [IO.Directory]::SetAccessControl($Path, $Acl)


                } else {

                    $InheritanceFlag = [Security.AccessControl.InheritanceFlags]::None
         
                    $Ace = New-Object -TypeName Security.AccessControl.FileSystemAccessRule($Identity, $AccessMask, $InheritanceFlag, $PropagationFlag, $AccessControlType)

                    $Acl = [IO.File]::GetAccessControl($path)

                    if ($Remove) {

                        $Acl.RemoveAccessRule($Ace)

                    } else {

                        $Acl.AddAccessRule($Ace)

                    }

                    [IO.File]::SetAccessControl($Path, $Acl)

                }

            } Catch {

                Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"

            }

        } else {

            Write-Warning -Message "Path not found not found"

        }

    }  else {

        Write-Warning -Message "$ComputerName is not online"

    }
   
} else {

    Write-Warning -Message "The requested operation requires elevation"

}
