Param (

    [Parameter(Mandatory = $true)]
    [String] $DisplayName

)


if (([Security.Principal.NTAccount]::New([Security.Principal.WindowsIdentity]::GetCurrent().Name)).Translate([Security.Principal.SecurityIdentifier]).Value -eq "S-1-5-18") {
    
    $ManagementClass = New-Object -TypeName Management.ManagementClass

    $ManagementClass.Path = "ROOT\ccm\dcm:SMS_DesiredConfiguration"

    $Baseline = Get-WmiObject -Namespace root\ccm\dcm -QUERY "SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName = '$DisplayName'"

    if ($null -ne $Baseline) {

        ($ManagementClass.TriggerEvaluation($Baseline.Name, $Baseline.Version)).ReturnValue

    }

}
