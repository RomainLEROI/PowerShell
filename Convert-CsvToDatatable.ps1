
Param (

	[Parameter(Mandatory = $true)]
	[ValidateScript({ Test-Path -Path $_ })]
	[String] $CsvPath

)


$DataTable = New-Object -TypeName Data.DataTable("Data")

$ValidHeaders = @{

    "Device Name" = "DeviceName"
    "Email Address" = "EmailAddress"
    "Operating System" = "OperatingSystem"
    "IMEI/MEID" = "IMEI"
    "Last Reported" = "LastReported"
    "Device ID" = "DeviceID"
    "Domain/Workgroup" = "Domain"
    "Phone Number" = "PhoneNumber"
    "Platform Name" = "PlatformName"

}


$Headers = ($ValidHeaders.GetEnumerator() | Measure-Object).Count

$ExportContent = (Get-Content -Path $CsvPath)

$Done = 0

foreach ($Item in $ValidHeaders.GetEnumerator()) {

    $ExportContent[0] = $ExportContent[0].Replace($Item.Key, $Item.Value) 

    $Done++

    $PercentDone = [Math]::Round((($Done / $Headers) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("Formating headers" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;

}


$ExportContent | Out-File -FilePath $CsvPath

$ExportContent = Import-Csv -Path $CsvPath


foreach ($NoteProperty in ($ExportContent | Get-Member -MemberType NoteProperty)) {

    switch ($NoteProperty.Name) {

        "LastReported" {

            [Void] $DataTable.columns.add($NoteProperty.Name, [DateTime])

        } default {

            [Void] $DataTable.columns.add($NoteProperty.Name, [String])

        }

    }

}


$Items = ($ExportContent | Measure-Object).Count

$Done = 0

foreach ($Obj in $ExportContent) {

    $Row = $DataTable.NewRow()

    foreach ($Column in $DataTable.columns) {

        switch ($Column.ColumnName) {

            "LastReported" {

                $Row.($Column.ColumnName) = [DateTime]($Obj.($Column.ColumnName))

            } default {

                $Row.($Column.ColumnName) = $Obj.($Column.ColumnName)

            }

        }

    }

    $DataTable.Rows.Add($Row)
    
    $Done++

    $PercentDone = [Math]::Round((($Done / $Items) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("Building DataTable" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;

}
