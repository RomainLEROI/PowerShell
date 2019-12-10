Param (

    [Parameter(Mandatory = $true)]
    [String] $ComputerName,

    [Parameter(ParameterSetName = "Add", Mandatory = $true)]
    [String] $Add,

    [Parameter(ParameterSetName = "Remove", Mandatory = $true)]
    [String] $Remove,

    [Parameter(Mandatory = $true)]
    [String] $GroupName


)


[DirectoryServices.DirectoryEntry] $Group = $null
[DirectoryServices.DirectoryEntry] $Computer	= $null

		
Try {

    $Computer = "LDAP://$((Get-WmiObject -Namespace "root\directory\ldap" -Query "SELECT DS_distinguishedName FROM DS_computer WHERE DS_cn='$ComputerName'").DS_distinguishedName)"

} Catch {

    Return 10

}

Try {

    $Group = "LDAP://$((Get-WmiObject -Namespace "root\directory\ldap" -Query "SELECT DS_distinguishedName FROM DS_group WHERE DS_cn='$GroupName'").DS_distinguishedName)"


} Catch {

    Return 20
                
}




Try {

    if ($Add) {

        if (!($Group.IsMember($Computer.ADSPath))) {

            $Group.Add($Computer.ADSPath)

        }

    } elseif ($Remove) {
        
        if ($Group.IsMember($Computer.ADSPath)) {

			$Group.Remove($Computer.ADSPath)

	    } 

    }  

} Catch {

    Return 30

}
