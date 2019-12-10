
Param (

    [Parameter(Mandatory = $true)]
    [String] $ComputerName,

    [Parameter(Mandatory = $True)]
    [String] $OUName

)


[DirectoryServices.DirectoryEntry] $OU = $null
[DirectoryServices.DirectoryEntry] $Computer = $null


Try {

    $Computer = "LDAP://$((Get-WmiObject -Namespace "root\directory\ldap" -Query "SELECT DS_distinguishedName FROM DS_computer WHERE DS_cn='$ComputerName'").DS_distinguishedName)"

} Catch {

    Return 10

}


Try {


    $OU = "LDAP://$((Get-WmiObject -Namespace "root\directory\ldap" -Query "SELECT DS_distinguishedName FROM DS_organizationalunit WHERE DS_name='$OuName'").DS_distinguishedName)"

} Catch {

    Return 20
                
}


Try {


    if (!($Computer.Path).Contains(($OU.Path).Replace("LDAP://", [String]::Empty))) {

        $Computer.MoveTo($OU)

    }

} Catch {

    Return 30

}
