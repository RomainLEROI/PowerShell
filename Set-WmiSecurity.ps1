
Param ( 

    [Parameter(Mandatory = $true)]
    [String] $Namespace,

    [Parameter(Mandatory = $true)]
    # BUILTIN\Administrateurs, AUTORITE NT\Système, BUILTIN\Utilisateurs, <Domain>\<Group>, <Domain>\<User>, <Computer>\<User>...
    [ValidatePattern("[a-zA-Z]\\[a-zA-Z0-9]")]
    [String] $Identity,

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,
   
    [Parameter(ParameterSetName = "Add", Mandatory = $false)]
    [ValidateSet('Enable', 'MethodExecute', 'FullWrite', 'PartialWrite', 'ProviderWrite', 'RemoteAccess', 'ReadSecurity')]
    [string[]] $Rights = $null,

    [Parameter(ParameterSetName = "Add", Mandatory = $false)]
    [ValidateSet('Allow', 'Deny')]
    [String] $AccessType = 'Allow',

    [Parameter(ParameterSetName = "Remove", Mandatory = $false)]
    [Switch] $Remove

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


Function Get-NTIdentity {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName,

        [Parameter(Mandatory = $true)]
        [String] $Identity

    
    )

    [String[]] $Account = $Identity.Split('\')

    [String] $Domain = $Account[0]

    if (($Domain -eq "BUILTIN") -or ($Domain -eq "AUTORITE NT")) {

        $Domain = $ComputerName

    }

    [String] $Name = $Account[1]

    [Management.ManagementBaseObject] $Win32_Account = Get-WmiObject -Class "Win32_Account" -Filter "Domain='$Domain' and Name='$Name'" -ComputerName $ComputerName

    [PSObject] $NTIdentity

    if ($null -eq $Win32_Account) {

        [Management.ManagementBaseObject] $Win32_Group = Get-WmiObject -Class "Win32_Group" -Filter "Domain='$Domain' and Name='$Name'" -ComputerName $ComputerName

        $NTIdentity = New-Object –TypeName PSObject -Property @{'Name'=$Name;'Domain'=$Domain;'Sid'=$Win32_Group.Sid}

    } else {

        $NTIdentity = New-Object –TypeName PSObject -Property @{'Name'=$Name;'Domain'=$Domain;'Sid'=$Win32_Account.Sid}

    }

    Return $NTIdentity


}



if (([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {


    if ((Is-LocalHost -ComputerName $ComputerName) -or (Is-Online -ComputerName $ComputerName)) {


        Try {


            [ComponentModel.Component] $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name GetSecurityDescriptor

            if ($Output.ReturnValue -ne 0) {

	            throw "GetSecurityDescriptor filed: $($output.ReturnValue)"

            }

            [ComponentModel.Component] $Acl = $Output.Descriptor
            
            [PSObject] $NTIdentity = Get-NTIdentity -ComputerName $ComputerName -Identity $Identity

            if ($null -eq $NTIdentity.Sid) {

                Throw "NTAccount $Account was not found"

            }

            [String] $Sid = $NTIdentity.Sid


            if ($Remove) {

                [Management.ManagementBaseObject[]] $NewDACL = @()
                    
                foreach ($Ace in $Acl.DACL) {

                    if ($Ace.Trustee.SidString -ne $Win32Account.Sid) {

                        $NewDACL += $Ace.psobject.immediateBaseObject

                    }

                }

                $Acl.DACL = $NewDACL.PsObject.immediateBaseObject

            } else {


                [Hashtable] $RightsTable = @{
        
                    Enable = 0x1
                    MethodExecute = 0x2
                    FullWrite = 0x4
                    PartialWrite = 0x8
                    ProviderWrite = 0x10
                    RemoteAccess = 0x20
                    ReadSecurity = 0x20000
        
                }

                [Int] $AccessMask = 0

                foreach ($Right in $Rights) {

                    $AccessMask += $RightsTable[$Right]

                }


                [Management.ManagementBaseObject] $Trustee = [Management.ManagementClass]::new("win32_Trustee").CreateInstance()
                $Trustee.SidString = $Sid

                [Management.ManagementBaseObject] $Ace = [Management.ManagementClass]::new("Win32_Ace").CreateInstance()
                $Ace.AccessMask = $accessMask
        
                [Int] $ACCESS_ALLOWED_ACE_TYPE = 0x0
                [Int] $ACCESS_DENIED_ACE_TYPE = 0x1  
                [Int] $CONTAINER_INHERIT_ACE_FLAG = 0x2

                if ($AccessType -eq "Allow") {

                    $Ace.AceType = $ACCESS_ALLOWED_ACE_TYPE

                } elseif ($AccessType -eq "Deny") {

                    $Ace.AceType = $ACCESS_DENIED_ACE_TYPE

                }

                $Ace.Trustee = $Trustee
                $Ace.AceFlags = $CONTAINER_INHERIT_ACE_FLAG
      
                $Acl.DACL += $Ace.PsObject.immediateBaseObject

            }

     
            [ComponentModel.Component] $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name "SetSecurityDescriptor" -ArgumentList $acl.PsObject.ImmediateBaseObject

            if ($Output.ReturnValue -ne 0) {

	            Throw "SetSecurityDescriptor failed: $($Output.ReturnValue)"

            }


        } Catch {

            Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

        } Finally {


            foreach ($Disposable in @($Output)) {

                if ($null -ne $Disposable) {

                    [Void] $Disposable.Dispose()

                }

            }

        }


    }  else {

        Write-Output -InputObject "$ComputerName is not online"

    }
   
} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
