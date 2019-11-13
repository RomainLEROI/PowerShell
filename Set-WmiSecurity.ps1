
Param ( 

    [parameter(Mandatory = $true)]
    [String] $Namespace,

    [parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Delete')]
    [String] $Operation,

    [parameter(Mandatory = $false)]
    [String] $Account,

    [parameter(Mandatory = $false)]
    [ValidateSet('SYSTEM', 'ADMINISTRATORS', 'USERS')]
    [String] $Group,
    
    [parameter(Mandatory = $false)]
    [ValidateSet('Enable', 'MethodExecute', 'FullWrite', 'PartialWrite', 'ProviderWrite', 'RemoteAccess', 'ReadSecurity', 'WriteSecurity')]
    [string[]] $Permissions = $null,

    [parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,

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


Function Get-NTAccount {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName,

        [Parameter(Mandatory = $true)]
        [String] $Account

    
    )

    [String[]] $DomainAccount

    [String] $Domain

    [String] $AccountName

    switch ($true) {

        ($Account.Contains('\')) {


            $DomainAccount = $Account.Split('\')

            $Domain = $DomainAccount[0]

            if (($Domain -eq ".") -or ($Domain -eq "BUILTIN") -or ($Domain -eq $env:COMPUTERNAME)) {

                $Domain = $env:COMPUTERNAME

            }

            $AccountName = $DomainAccount[1]


        } ($Account.Contains('@')) {


            $DomainAccount = $Account.Split('@')

            $Domain = $DomainAccount[1].Split('.')[0]

            $AccountName = $DomainAccount[0]


        } Default {

            $Domain = $env:COMPUTERNAME

            $AccountName = $Account

        }

    }


    [Management.ManagementBaseObject] $Win32_Account = Get-WmiObject -Class "Win32_Account" -Filter "Domain='$Domain' and Name='$AccountName'" -ComputerName $ComputerName

    $NTAccount = New-Object –TypeName PSObject -Property @{'Name'=$AccountName;'Domain'=$Domain;'Sid'=$Win32_Account.Sid}

    Return $NTAccount


}


if (([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {


    if ((Is-LocalHost -ComputerName $ComputerName) -or (Is-Online -ComputerName $ComputerName)) {


        if (($Operation -eq "Add") -and ($null -eq $Permissions)) {

            Throw "-Permissions must be specified for a -add operation"

        } elseif (($Operation -eq "Delete") -and ($null -ne $Permissions)) {

            Throw "-Permissions cannot be specified for a -delete operation"

        }


        if (([String]::IsNullOrEmpty($Account)) -and ([String]::IsNullOrEmpty($Group))) {
        
            Throw "-Account or -Group must be specified"
        
        } elseif ((![String]::IsNullOrEmpty($Account)) -and (![String]::IsNullOrEmpty($Group))) {
  
            Throw "-Account and -Group must be specified together"

        } 


        [Hashtable] $PermissionTable = @{
        
            Enable = 0x1
            MethodExecute = 0x2
            FullWrite = 0x4
            PartialWrite = 0x8
            ProviderWrite = 0x10
            RemoteAccess = 0x20
            ReadSecurity = 0x20000
            WriteSecurity = 0x40000
        
        }


        [Hashtable] $GroupTable = @{
        
            SYSTEM = "S-1-5-18"
            ADMINISTRATORS = "S-1-5-32-544"
            USERS = "S-1-5-32-545"

        }


        [ComponentModel.Component] $Output = Invoke-WmiMethod -Path "__systemsecurity=@" -Namespace $Namespace -ComputerName $ComputerName -Name GetSecurityDescriptor

        if ($output.ReturnValue -ne 0) {

	        throw "GetSecurityDescriptor failed: $($output.ReturnValue)"

        }

        [ComponentModel.Component] $Acl = $Output.Descriptor

        [String] $Sid

        if (![String]::IsNullOrEmpty($Account)) {

            [PSObject] $NTAccount = Get-NTAccount -ComputerName $ComputerName -Account $Account

            if ($null -eq $NTAccount.Sid) {

                Throw "NTAccount $Account was not found on $ComputerName"

            }

            $Sid = $NTAccount.Sid

        } else {

            $Sid = $GroupTable[$Group]

        }

        
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
        

                if ($Deny) {

                    $Ace.AceType = [Security.AccessControl.AccessControlType]::Deny

                } else {

                    $Ace.AceType = [Security.AccessControl.AccessControlType]::Allow

                }

                $Ace.Trustee = $Trustee
                $Ace.AceFlags = [Security.AccessControl.AceFlags]::ContainerInherit
      
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

	        Throw "SetSecurityDescriptor failed: $($output.ReturnValue)"

        }


    }  else {

        Write-Output -InputObject "$ComputerName is not online"

    }
   
} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
