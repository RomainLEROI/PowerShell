Param (

    [Parameter(Mandatory = $true)]
    [String] $GroupName

)


[DirectoryServices.DirectoryEntry] $Group = $null

		
Try {

    $Group = "LDAP://$((Get-WmiObject -Namespace "root\directory\ldap" -Query "SELECT DS_distinguishedName FROM DS_group WHERE DS_cn='$GroupName'").DS_distinguishedName)"


} Catch {

    Return 10
                
}


[Int] $Count = ($Group.member | Measure-Object).Count

[Int] $Done = 0


$Members = @()

foreach ($Member in $Group.member | Sort-Object) {


    [String] $ComputerName = [Regex]::Match($Member,'CN=([^,]+)').Groups[1].Value 

    [DirectoryServices.DirectoryEntry] $Computer =  "LDAP://$Member"

    $Members += [Ordered]@{ Name = $ComputerName; DirectoryEntry  = $Computer }

    $Done++

    [Decimal] $PercentDone = [Math]::Round((($Done / $Count) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("Fetching $GroupName members" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;


}

Return $Members
