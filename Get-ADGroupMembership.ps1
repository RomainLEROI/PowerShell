Param (

    [Parameter(Mandatory = $true)]
    [String] $GroupName

)

		
$GroupPath = (Get-WmiObject -Namespace "root\directory\ldap" -Query "SELECT DS_distinguishedName FROM DS_group WHERE DS_cn='$GroupName'").DS_distinguishedName

$Group = New-Object -TypeName DirectoryServices.DirectoryEntry("LDAP://$GroupPath")

$Count = ($Group.member | Measure-Object).Count

$Done = 0

$Members = @()

foreach ($Item in $Group.member | Sort-Object) {

    $MemberName = [Regex]::Match($Item,'CN=([^,]+)').Groups[1].Value 

    $Member =  New-Object -TypeName DirectoryServices.DirectoryEntry("LDAP://$Item")

    $Members += [Ordered]@{ Name = $MemberName; DirectoryEntry  = $Member }

    $Done++

    $PercentDone = [Math]::Round((($Done / $Count) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("Fetching $GroupName members" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;

}

Return $Members
