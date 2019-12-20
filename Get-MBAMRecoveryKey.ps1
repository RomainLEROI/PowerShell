
Param (

    [Parameter(Mandatory = $true)]
    [String] $SqlServer,

    [Parameter(ParameterSetName = "ByID", Mandatory = $true)]
    [String] $RecoveryID,

    [Parameter(ParameterSetName = "ByName", Mandatory = $true)]
    [String] $ComputerName
   
)

$ConnectionString = "Data Source=$SqlServer;Initial Catalog=MBAM Recovery and Hardware;Integrated Security=True"

$Connection = New-Object System.Data.SqlClient.SqlConnection

$Connection.ConnectionString = $ConnectionString
    
Try {

    $Connection.Open()

    $IsAbleToConnect = ($Connection.State -eq "Open")

} Catch {

    $IsAbleToConnect =  $false

}


if ($IsAbleToConnect) {

    $Query = @"

        SELECT [RecoveryAndHardwareCore].[Keys].[LastUpdateTime]
	          ,[RecoveryAndHardwareCore].[Domains].[DomainName]
	          ,[RecoveryAndHardwareCore].[Machines].[Name]
	          ,[RecoveryAndHardwareCore].[Keys].[RecoveryKeyId]
	          ,[RecoveryAndHardwareCore].[Keys].[RecoveryKey]

        FROM [RecoveryAndHardwareCore].[Keys]

        INNER JOIN [RecoveryAndHardwareCore].[Machines_Volumes]
        ON [RecoveryAndHardwareCore].[Machines_Volumes].[VolumeId] = [RecoveryAndHardwareCore].[Keys].[VolumeId]

        INNER JOIN [RecoveryAndHardwareCore].[Machines]
        ON [RecoveryAndHardwareCore].[Machines].[Id] = [RecoveryAndHardwareCore].[Machines_Volumes].[MachineId]

        INNER JOIN [RecoveryAndHardwareCore].[Domains]
        ON [RecoveryAndHardwareCore].[Domains].[Id] = [RecoveryAndHardwareCore].[Machines].[DomainId]

"@

    if (![String]::IsNullOrEmpty($ComputerName)) {
      
      $Query = "$Query WHERE [RecoveryAndHardwareCore].[Machines].[Name] = '{0}'" -f $ComputerName

    } elseif (![String]::IsNullOrEmpty($RecoveryID)) {
      
      $Query = "$Query WHERE [RecoveryAndHardwareCore].[Keys].[RecoveryKeyId] LIKE '{0}%'" -f $RecoveryID

    }

    Try {

        $SqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query, $Connection)
                   
        $DataSet = New-Object System.Data.DataSet

        $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCommand)

        $SqlResult = @{

            DataSet = $DataSet
            RecordCount = $DataAdapter.Fill($DataSet)
            Exception = [String]::Empty

        }

    } Catch {

        $SqlResult = @{

            DataSet = $null
            RecordCount = 0
            Exception = $_.Exception.Message

        }

    } Finally {

        if ($Connection.State -eq "Open") {

            $Connection.Close()

        }

    }

    if ($SqlResult.RecordCount -gt 0) { 
    
        $SqlResult.DataSet.Tables[0].Rows

    } else {

        Write-Warning -Message "[!] No match"

    }

    if (![String]::IsNullOrEmpty($SqlResult.Exception)) {

        Write-Error -Message "[!] $($SqlResult.Exception)"

    }

} else {

    Write-Error -Message "[!] Unable to access SQL database"

}
