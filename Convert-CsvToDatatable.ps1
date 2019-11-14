
Param (

	[Parameter(Mandatory = $true)]
	[ValidateScript({ Test-Path -Path $_ })]
	[String] $CsvPath

)


[Data.DataTable] $DataTable = [Data.DataTable]::new("Data")

[HashTable] $ValidHeaders = @{

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


[Int] $Headers = ($ValidHeaders.GetEnumerator() | Measure-Object).Count

[Object[]] $ExportContent = (Get-Content -Path $CsvPath)

[Int] $Done = 0

foreach ($Item in $ValidHeaders.GetEnumerator()) {

    $ExportContent[0] = $ExportContent[0].Replace($Item.Key, $Item.Value) 

    $Done++

    [Decimal] $PercentDone = [Math]::Round((($Done / $Headers) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("Formating Devices headers" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;

}


$ExportContent | Out-File -FilePath $CsvPath

$ExportContent = Import-Csv -Path $CsvPath


foreach ($NoteProperty in ($ExportContent | Get-Member -MemberType NoteProperty)) {


    if ($NoteProperty.Name -eq "LastReported") {

        [Void] $DataTable.columns.add($NoteProperty.Name, [DateTime])

    } else {

        [Void] $DataTable.columns.add($NoteProperty.Name, [String])

    }

}


[Int] $Items = ($ExportContent | Measure-Object).Count

$Done = 0

foreach ($Obj in $ExportContent) {

    [Object] $Row = $DataTable.NewRow()

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

    [Decimal] $PercentDone = [Math]::Round((($Done / $Items) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("Building DataTable" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;

}
