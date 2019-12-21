
Param ( 

    [Parameter(Mandatory = $true)]
    [String] $Namespace,

    [Parameter(Mandatory = $true)]
    # BUILTIN\Administrateurs, AUTORITE NT\Système, BUILTIN\Utilisateurs, <Domain>\<Group>, <Domain>\<User>, <Computer>\<User>...
    [ValidatePattern("[a-zA-Z]\\[a-zA-Z0-9]")]
    [String] $Identity,

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,
   
    [Parameter(ParameterSetName = "Add", Mandatory = $true)]
    [ValidateSet('Enable', 'MethodExecute', 'FullWrite', 'PartialWrite', 'ProviderWrite', 'RemoteAccess', 'ReadSecurity')]
    [string[]] $Rights = $null,

    [Parameter(ParameterSetName = "Add", Mandatory = $false)]
    [ValidateSet('Allow', 'Deny')]
    [String] $AccessType = 'Allow',

    [Parameter(ParameterSetName = "Remove", Mandatory = $true)]
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

        Try {

            $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name GetSecurityDescriptor

            if ($Output.ReturnValue -ne 0) {

	            throw "GetSecurityDescriptor filed: $($output.ReturnValue)"

            }

            $Acl = $Output.Descriptor
            
            
            $Account = $Identity.Split('\')

            $Domain = $Account[0]

            if (($Domain -eq "BUILTIN") -or ($Domain -eq "AUTORITE NT")) {

                $Domain = $ComputerName

            }

            $Name = $Account[1]

            $Win32_Account = Get-WmiObject -Class "Win32_Account" -Filter "Domain='$Domain' and Name='$Name'" -ComputerName $ComputerName

            if ($null -eq $Win32_Account) {

                $Win32_Group = Get-WmiObject -Class "Win32_Group" -Filter "Domain='$Domain' and Name='$Name'" -ComputerName $ComputerName

                $NTIdentity = New-Object –TypeName PSObject -Property @{'Name'=$Name;'Domain'=$Domain;'Sid'=$Win32_Group.Sid}

            } else {

                $NTIdentity = New-Object –TypeName PSObject -Property @{'Name'=$Name;'Domain'=$Domain;'Sid'=$Win32_Account.Sid}

            }


            if ($null -eq $NTIdentity.Sid) {

                Throw "NTAccount $Account was not found"

            }

            $Sid = $NTIdentity.Sid


            if ($Remove) {

                $NewDACL = @()
                    
                foreach ($Ace in $Acl.DACL) {

                    if ($Ace.Trustee.SidString -ne $Win32Account.Sid) {

                        $NewDACL += $Ace.psobject.immediateBaseObject

                    }

                }

                $Acl.DACL = $NewDACL.PsObject.immediateBaseObject

            } else {

                $RightsTable = @{
        
                    Enable = 0x1
                    MethodExecute = 0x2
                    FullWrite = 0x4
                    PartialWrite = 0x8
                    ProviderWrite = 0x10
                    RemoteAccess = 0x20
                    ReadSecurity = 0x20000
        
                }

                $AccessMask = 0

                foreach ($Right in $Rights) {

                    $AccessMask += $RightsTable[$Right]

                }

                $Trustee = New-Object –TypeName Management.ManagementClass("win32_Trustee").CreateInstance()
                $Trustee.SidString = $Sid

                $Ace = New-Object –TypeName Management.ManagementClass("Win32_Ace").CreateInstance()
                $Ace.AccessMask = $accessMask
        
                $ACCESS_ALLOWED_ACE_TYPE = 0x0
                $ACCESS_DENIED_ACE_TYPE = 0x1  
                $CONTAINER_INHERIT_ACE_FLAG = 0x2

                if ($AccessType -eq "Allow") {

                    $Ace.AceType = $ACCESS_ALLOWED_ACE_TYPE

                } elseif ($AccessType -eq "Deny") {

                    $Ace.AceType = $ACCESS_DENIED_ACE_TYPE

                }

                $Ace.Trustee = $Trustee
                $Ace.AceFlags = $CONTAINER_INHERIT_ACE_FLAG
      
                $Acl.DACL += $Ace.PsObject.immediateBaseObject

            }

            $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name "SetSecurityDescriptor" -ArgumentList $acl.PsObject.ImmediateBaseObject

            if ($Output.ReturnValue -ne 0) {

	            Throw "SetSecurityDescriptor failed: $($Output.ReturnValue)"

            }

        } Catch {

            Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"

        } Finally {

            foreach ($Disposable in @($Output)) {

                if ($null -ne $Disposable) {

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
