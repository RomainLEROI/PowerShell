Function Get-TaskExecutionStatus {

    [CmdletBinding()]
    Param (

        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [String] $ComputerName,

        [Parameter(ValueFromPipeline, Mandatory = $false)]
        [Int] $GetLast = 0
   
    )


    Begin {

        $CMClient = New-Object -ComObject "Microsoft.SMS.Client"

        $ManagementPoint = $CMClient.GetCurrentManagementPoint()

        $AssignedSite = $CMClient.GetAssignedSite()

        $ConnectionString = "Data Source=$ManagementPoint;Initial Catalog=CM_$AssignedSite;Integrated Security=True"

        $Connection = New-Object -TypeName Data.SqlClient.SqlConnection

        $Connection.ConnectionString = $ConnectionString

        Try {

            $Connection.Open()

            $IsAbleToConnect = ($Connection.State -eq "Open")

        } Catch {

            $IsAbleToConnect =  $false

            Write-Error -Message "[!] Unable to access SQL database"

        }

    } Process {

        if ($IsAbleToConnect) {

            Try {



                if ($GetLast -gt 0) {

                    $Query = @"

                        Declare @TableRowsCount Int
                        Declare @N Int

                        select @TableRowsCount = COUNT(*) FROM [v_TaskExecutionStatus]
                        LEFT OUTER JOIN [v_R_System]
                        ON [v_R_System].[ResourceID] = [v_TaskExecutionStatus].[ResourceID]
                        LEFT OUTER JOIN [v_Advertisement] 
                        ON [v_TaskExecutionStatus].[AdvertisementID] = [v_Advertisement].[AdvertisementID]
                        LEFT OUTER JOIN [v_TaskSequencePackage] 
                        ON [v_Advertisement].[PackageID] = [v_TaskSequencePackage].[PackageID]
                        WHERE [v_TaskExecutionStatus].[ActionOutput] <> ''
                        AND [v_R_System].[Name0] = 'VEPO857'

                        select @N = '{0}'

                        SELECT [v_TaskExecutionStatus].[ExecutionTime]
                                ,[v_TaskExecutionStatus].[Step]
                                ,[v_TaskExecutionStatus].[GroupName]
                                ,[v_TaskExecutionStatus].[ActionName]
                                ,[v_TaskExecutionStatus].[ExitCode]
                                ,[v_TaskExecutionStatus].[ActionOutput]
                        FROM [v_TaskExecutionStatus]
                        LEFT OUTER JOIN [v_R_System]
                        ON [v_R_System].[ResourceID] = [v_TaskExecutionStatus].[ResourceID]
                        LEFT OUTER JOIN [v_Advertisement] 
                        ON [v_TaskExecutionStatus].[AdvertisementID] = [v_Advertisement].[AdvertisementID]
                        LEFT OUTER JOIN [v_TaskSequencePackage] 
                        ON [v_Advertisement].[PackageID] = [v_TaskSequencePackage].[PackageID]
                        WHERE [v_TaskExecutionStatus].[ActionOutput] <> ''
                        AND [v_R_System].[Name0] = '{1}'
                        ORDER BY [v_TaskExecutionStatus].[ExecutionTime]
                        OFFSET (@TableRowsCount-@N) ROWS
                        FETCH NEXT @N ROWS ONLY;      

"@ -f $GetLast, $ComputerName

                } else {

                    $Query = @"

                        SELECT  [v_TaskExecutionStatus].[ExecutionTime]
                                ,[v_TaskExecutionStatus].[Step]
                                ,[v_TaskExecutionStatus].[GroupName]
                                ,[v_TaskExecutionStatus].[ActionName]
                                ,[v_TaskExecutionStatus].[ExitCode]
                                ,[v_TaskExecutionStatus].[ActionOutput]
                        FROM [v_TaskExecutionStatus]
                        LEFT OUTER JOIN [v_R_System]
                        ON [v_R_System].[ResourceID] = [v_TaskExecutionStatus].[ResourceID]
                        LEFT OUTER JOIN [v_Advertisement] 
                        ON [v_TaskExecutionStatus].[AdvertisementID] = [v_Advertisement].[AdvertisementID]
                        LEFT OUTER JOIN [v_TaskSequencePackage] 
                        ON [v_Advertisement].[PackageID] = [v_TaskSequencePackage].[PackageID]
                        WHERE [v_TaskExecutionStatus].[ActionOutput] <> ''
                        AND [v_R_System].[Name0] = '{0}'
                        ORDER BY [v_TaskExecutionStatus].[ExecutionTime]             

"@ -f $ComputerName

                }

            
                $SqlCommand = New-Object -TypeName Data.SqlClient.SqlCommand($Query, $Connection)
                   
                $DataSet = New-Object -TypeName Data.DataSet

                $DataAdapter = New-Object -TypeName Data.SqlClient.SqlDataAdapter($SqlCommand)

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


            }

            if (![String]::IsNullOrEmpty($SqlResult.Exception)) {

                Write-Error -Message "[!] $ComputerName : $($SqlResult.Exception)"

            } else {

                if ($SqlResult.RecordCount -gt 0) { 

                    $SqlResult.DataSet.Tables[0] | Out-GridView -Title $ComputerName

                } else {

                    Write-Warning -Message "[!] $ComputerName : No match"

                }

            }   

        }


    } End {

        if ($Connection.State -eq "Open") {

            $Connection.Close()

        }

    }

}
