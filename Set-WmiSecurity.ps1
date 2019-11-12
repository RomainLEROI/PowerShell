
Param ( 

    [parameter(Mandatory = $true)]
    [String] $Namespace,

    [parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Delete')]
    [String] $operation,

    [parameter(Mandatory = $true)]
    [String] $Account,

    [parameter(Mandatory = $false)]
    [ValidateSet('Enable', 'MethodExecute', 'FullWrite', 'PartialWrite', 'ProviderWrite', 'RemoteAccess', 'ReadSecurity', 'WriteSecurity')]
    [string[]] $Permissions = $null,

    [parameter(Mandatory = $false)]
    [string] $computerName = $env:COMPUTERNAME,

    [parameter(Mandatory = $false)]
    [Switch] $AllowInherit = $false,

    [parameter(Mandatory = $false)]
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

    Switch ($true) {

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

        if (($Operation -eq "Add") -and ($null -eq $Permissions)) {

            Throw "-Permissions must be specified for an add operation"

        } elseif (($Operation -eq "Delete") -and ($null -ne $Permissions)) {

            Throw "Permissions cannot be specified for a delete operation"

        }

        [Hashtable] $PermissionTable = @{
        
            "Enable" = 0x1
            "MethodExecute" = 0x2
            "FullWrite" = 0x4
            "PartialWrite" = 0x8
            "ProviderWrite" = 0x10
            "RemoteAccess" = 0x20
            "ReadSecurity" = 0x20000
            "WriteSecurity" = 0x40000
        
        }

        [ComponentModel.Component] $Output = Invoke-WmiMethod -Namespace $Namespace -Path "__systemsecurity=@" -ComputerName $ComputerName -Name GetSecurityDescriptor

        if ($Output.ReturnValue -ne 0) {

            Throw "GetSecurityDescriptor failed: $($Output.ReturnValue)"

        }

        [ComponentModel.Component] $Acl = $Output.Descriptor

        [String[]] $DomainAccount

        [String] $Domain

        [String] $AccountName

        if ($Account.Contains('\')) {

            $DomainAccount = $Account.Split('\')

            $Domain = $DomainAccount[0]

            if (($Domain -eq ".") -or ($Domain -eq "BUILTIN") -or ($Domain -eq $env:COMPUTERNAME)) {

                $Domain = $env:COMPUTERNAME

            }

            $AccountName = $DomainAccount[1]

        } elseif ($Account.Contains('@')) {

            $DomainAccount = $Account.Split('@')

            $Domain = $DomainAccount[1].Split('.')[0]

            $AccountName = $DomainAccount[0]

        } else {

            $Domain = $env:COMPUTERNAME

            $AccountName = $Account

        }
 
        [Management.ManagementBaseObject] $Win32Account = Get-WmiObject -Class "Win32_Account" -Filter "Domain='$Domain' and Name='$AccountName'" -ComputerName $ComputerName

        if ($null -eq $Win32Account) {

            Throw "Account $Account was not found"

        }

        switch ($Operation) {

            "Add" {

                [Int] $AccessMask = 0

                foreach ($Permission in $Permissions) {

                    $AccessMask += $PermissionTable[$Permission]

                }

                [Int] $OBJECT_INHERIT_ACE_FLAG = 0x1
                [Int] $CONTAINER_INHERIT_ACE_FLAG = 0x2

                [Management.ManagementBaseObject] $Ace = ([Management.ManagementClass]::new("Win32_Ace")).CreateInstance()
                $Ace.AccessMask = $accessMask

                if ($AllowInherit) {

                    $Ace.AceFlags = $OBJECT_INHERIT_ACE_FLAG + $CONTAINER_INHERIT_ACE_FLAG

                } else {

                    $Ace.AceFlags = 0

                }

                [Int] $ACCESS_ALLOWED_ACE_TYPE = 0x0
                [Int] $ACCESS_DENIED_ACE_TYPE = 0x1                     

                [Management.ManagementBaseObject] $Trustee = ([Management.ManagementClass]::new("win32_Trustee")).CreateInstance()
                $Trustee.SidString = $Win32Account.Sid
                $Ace.Trustee = $Trustee

                if ($Deny) {

                    $Ace.AceType = $ACCESS_DENIED_ACE_TYPE

                } else {

                    $Ace.AceType = $ACCESS_ALLOWED_ACE_TYPE

                }

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

        [ComponentModel.Component] $Output = Invoke-WmiMethod -Name "SetSecurityDescriptor" -ArgumentList $Acl.psobject.immediateBaseObject -Namespace $Namespace -Path "__systemsecurity=@" -ComputerName $ComputerName
        
        if ($Output.ReturnValue -ne 0) {

            Throw "SetSecurityDescriptor failed: $($output.ReturnValue)"

        }

    }  else {

        Write-Output -InputObject "$ComputerName is not online"

    }
   
} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
