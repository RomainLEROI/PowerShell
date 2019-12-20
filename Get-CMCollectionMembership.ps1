Param (

    [Parameter(ParameterSetName = "ByID", Mandatory = $true)]
    [String] $CollectionID

)

$CmClient = New-Object -ComObject "Microsoft.SMS.Client"
$MP = $CmClient.GetCurrentManagementPoint()
$Site = $CmClient.GetAssignedSite()

$ConnectionOptions = New-Object -TypeName Management.ConnectionOptions
$ConnectionOptions.Impersonation = [Management.ImpersonationLevel]::Impersonate
$ConnectionOptions.Authentication = [Management.AuthenticationLevel]::Packet

$ManagementScope = New-Object -TypeName Management.ManagementScope("\\$MP\root\SMS\site_$Site", $ConnectionOptions)
$managementScope.Connect()

$SelectQuery = New-Object -TypeName Management.SelectQuery("SELECT ClientType, ResourceId, Name, IsDirect FROM SMS_FullCollectionMembership WHERE CollectionID = '$CollectionID'")
$SelectQuery.IsSchemaQuery = $false

$EnumerationOptions = New-Object -TypeName Management.EnumerationOptions
$EnumerationOptions.ReturnImmediately = $true
$EnumerationOptions.EnumerateDeep = $false
$EnumerationOptions.DirectRead = $true

$ManagementObjectSearcher = New-Object -TypeName Management.ManagementObjectSearcher($ManagementScope, $SelectQuery)
$ManagementObjectSearcher.Options = $EnumerationOptions

$ManagementObjectCollection = $ManagementObjectSearcher.Get()

$DataTable = -TypeName Data.DataTable("CollectionMembers")

[Void] $DataTable.columns.add("ClientType", [Int])
[Void] $DataTable.columns.add("ResourceId", [String])
[Void] $DataTable.columns.add("Name", [String])
[Void] $DataTable.columns.add("IsDirect", [Bool])

$ManagementObjectCollection | ForEach-Object {

    $Row = $DataTable.NewRow()

    $Row.ClientType = [Convert]::ToInt32($_.ClientType)
          
    $Row.Name = $_.Name

    $Row.ResourceID = $_.ResourceID

    $Row.IsDirect = [Convert]::ToBoolean($_.IsDirect)

    $DataTable.Rows.Add($Row)

}

Return $DataTable
