
Param ( 

    [Parameter(Mandatory = $true)]
    [String] $Namespace,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Delete')]
    [String] $Operation,

    [Parameter(Mandatory = $true)]
    # BUILTIN\Administrateurs, AUTORITE NT\Système, BUILTIN\Utilisateurs, <Domain>\<Group>, <Domain>\<User>, <Computer>\<User>...
    [ValidatePattern("[a-zA-Z]\\[a-zA-Z0-9]")]
    [String] $Identity,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Enable', 'MethodExecute', 'FullWrite', 'PartialWrite', 'ProviderWrite', 'RemoteAccess', 'ReadSecurity')]
    [string[]] $Permissions = $null,

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [Switch] $Deny = $false
  
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

    [String[]] $DomainAccount = $Identity.Split('\')

    [String] $Domain = $DomainAccount[0]

    if (($Domain -eq "BUILTIN") -or ($Domain -eq "AUTORITE NT")) {

        $Domain = $ComputerName

    }

    [String] $Account = $DomainAccount[1]


    [Management.ManagementBaseObject] $Win32_Account = Get-WmiObject -Class "Win32_Account" -Filter "Domain='$Domain' and Name='$Account'" -ComputerName $ComputerName

    [PSObject] $NTIdentity

    if ($null -eq $Win32_Account) {

        [Management.ManagementBaseObject] $Win32_Group = Get-WmiObject -Class "Win32_Group" -Filter "Domain='$Domain' and Name='$Account'" -ComputerName $ComputerName

        $NTIdentity = New-Object –TypeName PSObject -Property @{'Name'=$Account;'Domain'=$Domain;'Sid'=$Win32_Group.Sid}

    } else {

        $NTIdentity = New-Object –TypeName PSObject -Property @{'Name'=$Account;'Domain'=$Domain;'Sid'=$Win32_Account.Sid}

    }

    Return $NTIdentity


}



if (([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {


    if ((Is-LocalHost -ComputerName $ComputerName) -or (Is-Online -ComputerName $ComputerName)) {


        if (($Operation -eq "Add") -and ($null -eq $Permissions)) {

            Throw "-Permissions must be specified for a -add operation"

        } elseif (($Operation -eq "Delete") -and ($null -ne $Permissions)) {

            Throw "-Permissions cannot be specified for a -delete operation"

        }


        [Hashtable] $PermissionTable = @{
        
            Enable = 0x1
            MethodExecute = 0x2
            FullWrite = 0x4
            PartialWrite = 0x8
            ProviderWrite = 0x10
            RemoteAccess = 0x20
            ReadSecurity = 0x20000
        
        }
        

        Try {


            [ComponentModel.Component] $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name GetSecurityDescriptor

            if ($Output.ReturnValue -ne 0) {

	            throw "GetSecurityDescriptor failed: $($output.ReturnValue)"

            }

            [ComponentModel.Component] $Acl = $Output.Descriptor
            
            [PSObject] $NTIdentity = Get-NTIdentity -ComputerName $ComputerName -Identity $Identity

            if ($null -eq $NTIdentity.Sid) {

                Throw "NTAccount $Account was not found"

            }

            [String] $Sid = $NTIdentity.Sid

     
            switch ($Operation) {


                "Add" {


                    [Int] $AccessMask = 0

                    foreach ($Permission in $Permissions) {

                        $AccessMask += $PermissionTable[$Permission]

                    }


                    [Management.ManagementBaseObject] $Trustee = [Management.ManagementClass]::new("win32_Trustee").CreateInstance()
                    $Trustee.SidString = $Sid

                    [Management.ManagementBaseObject] $Ace = [Management.ManagementClass]::new("Win32_Ace").CreateInstance()
                    $Ace.AccessMask = $accessMask
        
                    [Int] $ACCESS_ALLOWED_ACE_TYPE = 0x0
                    [Int] $ACCESS_DENIED_ACE_TYPE = 0x1  
                    [Int] $CONTAINER_INHERIT_ACE_FLAG = 0x2

                    if ($Deny) {

                        $Ace.AceType = $ACCESS_DENIED_ACE_TYPE

                    } else {

                        $Ace.AceType = $ACCESS_ALLOWED_ACE_TYPE

                    }

                    $Ace.Trustee = $Trustee
                    $Ace.AceFlags = $CONTAINER_INHERIT_ACE_FLAG
      
                    $Acl.DACL += $Ace.PsObject.immediateBaseObject


                } "Delete" {


                    [Management.ManagementBaseObject[]] $NewDACL = @()
                    
                    foreach ($Ace in $Acl.DACL) {

                        if ($Ace.Trustee.SidString -ne $Win32Account.Sid) {

                            $NewDACL += $Ace.psobject.immediateBaseObject

                        }

                    }

                    $Acl.DACL = $NewDACL.PsObject.immediateBaseObject


                }

            }


            [ComponentModel.Component] $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name "SetSecurityDescriptor" -ArgumentList $acl.psobject.immediateBaseObject

            if ($Output.ReturnValue -ne 0) {

	            Throw "SetSecurityDescriptor failed: $($Output.ReturnValue)"

            }


        } Catch {

            Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

        } Finally {


            foreach ($Disposable in @($Output, $Acl, $Trustee, $Ace, $NewDACL)) {

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
