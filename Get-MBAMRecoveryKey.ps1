
Param (

    [Parameter(Mandatory = $true)]
    [String] $SqlServer,

    [Parameter(Mandatory = $false)]
    [String] $SqlDatabase = "MBAM Recovery and Hardware",

    [Parameter(ParameterSetName = "ByID", Mandatory = $true)]
    [String] $RecoveryID = [String]::Empty,

    [Parameter(ParameterSetName = "ByName", Mandatory = $true)]
    [String] $ComputerName = [String]::Empty
   
)


Function Build-Query {

    [String] $Query = @"

        SELECT 

             [RecoveryAndHardwareCore].[Keys].[LastUpdateTime]
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

    if (($ComputerName -ne [String]::Empty) -and ($RecoveryID -eq [String]::Empty)) {
      
      $Query = "$Query WHERE [RecoveryAndHardwareCore].[Machines].[Name] = '{0}'" -f $ComputerName

    } elseif (($ComputerName -eq [String]::Empty) -and ($RecoveryID -ne [String]::Empty)) {
      
      $Query = "$Query WHERE [RecoveryAndHardwareCore].[Keys].[RecoveryKeyId] LIKE '{0}%'" -f $RecoveryID

    } elseif (($ComputerName -ne [String]::Empty) -and ($RecoveryID -ne [String]::Empty)) {
      
      $Query = "$Query WHERE [RecoveryAndHardwareCore].[Machines].[Name] = '{0}' AND [RecoveryAndHardwareCore].[Keys].[RecoveryKeyId] LIKE '{1}%'" -f $ComputerName, $RecoveryID

    }

    Return $Query

}


Function Execute-SqlQuery {

    Try {

        [Data.SqlClient.SqlCommand] $SqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query, $Connection)
                   
        [Data.DataSet] $DataSet = New-Object System.Data.DataSet

        [Data.SqlClient.SqlDataAdapter] $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCommand)

        [Int] $RecordCount = $DataAdapter.Fill($DataSet)

        [HashTable] $SqlResult = @{

            DataSet = $DataSet
            RecordCount = $RecordCount
            Exception = [String]::Empty

        }

        Return $SqlResult

    } Catch {

        [HashTable] $SqlResult = @{

            DataSet = $null
            RecordCount = 0
            Exception = $_.Exception.Message

        }

        Return $SqlResult

    } Finally {

        if ($Connection.State -eq "Open") {

            $Connection.Close()

        }

    }

}


Function Check-SqlConnection {


    Try {

        $Connection.Open()

        [Bool] $IsAbleToConnect = ($Connection.State -eq "Open")

        if ($IsAbleToConnect) { 
        
            $Connection.Close() 
            
        }
 
        Return $IsAbleToConnect


    } Catch {

        Return $false

    }

}


Function Create-SqlConnection {


    [String] $ConnectionString = "Data Source=$SqlServer;Initial Catalog=$SqlDatabase;Integrated Security=True"

    [Data.SqlClient.SqlConnection] $Connection = New-Object System.Data.SqlClient.SqlConnection

    $Connection.ConnectionString = $ConnectionString

    Return $Connection

}


[Data.SqlClient.SqlConnection] $Connection = Create-SqlConnection
    
[Bool] $IsAbleToConnect =  Check-SqlConnection

if ($IsAbleToConnect) {

    [String] $Query = Build-Query

    [HashTable] $Result = Execute-SqlQuery

    if ($Result.RecordCount -gt 0) { 
    
        $Result.DataSet.Tables[0].Rows

    } else {

        Write-Warning -Message "[!] No match"

    }

    if (![String]::IsNullOrEmpty($Result.Exception)) {

        Write-Error -Message "[!] $($Result.Exception)"

    }

} else {

    Write-Error -Message "[!] Unable to access SQL database"

}
