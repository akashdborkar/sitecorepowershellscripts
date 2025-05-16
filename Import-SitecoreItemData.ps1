<#
    .SYNOPSIS
       Generic Pages Import
       
    .DESCRIPTION
        Iterate through CSV, create siteore items for generic pages and Populate fields. Generate List of processed and Non processed items.
        By default, packages are saved to disk at C:\inetpub\wwwroot\App_Data\packages. Thus C:\inetpub\wwwroot\App_Data\GenericPages.csv will be
        path
    
    .NOTES
        Akash Borkar 
#>

functionWrite-LogExtended{
param(
[string]$Message,
[System.ConsoleColor]$ForegroundColor = $host.UI.RawUI.ForegroundColor,
[System.ConsoleColor]$BackgroundColor = $host.UI.RawUI.BackgroundColor
)
Write-Log -Object $message
Write-Host -Object $message -ForegroundColor $ForegroundColor -BackgroundColor $backgroundColor
}


Write-LogExtended"Generic Pages Import"
Write-LogExtended"-----------------------------------------------------------------"
# Prompt for the file path
$filePath = Show-Input -Prompt "Please enter the full path to the CSV file"
if($filePath -ne $null)
{
Write-Host"Selected file: $filePath"

# Import the CSV file
$csvData = Import-Csv -Path $filePath | Where-Object{ -join $_.psobject.Properties.Value }
Write-LogExtended"CSV file read successfully" -ForegroundColor Green
if($csvData -ne $null)
{
$processedItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$NonProcessedItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$database = Get-Database"master"
$placeholder = "/headless-main/container-1"
foreach($rowin$csvData){
#Generic Page branch
$branchTemplateId = [Sitecore.Data.ID]::Parse("{8032FE9E-3CD1-4E80-8377-66BBF74F839E}")

# Extract the desired item name, parent item and template id from the URL
$itemName = $row.Name
$parentItemPath = $row.Path -Replace $itemName, ""

# Get the parent item
$parentItem = $database.GetItem($parentItemPath)
if($parentItem)
{
# Check if the item already exists
$existingItemPath = "$($parentItem.Paths.FullPath)/$itemName"
$itemExists = Test-Path -Path $existingItemPath
if(-not $itemExists)
{
$item = [Sitecore.Data.Managers.ItemManager]::AddFromTemplate($itemName, $branchTemplateId, $parentItem)
if($item -eq $null)
{
Write-LogExtended"Unable to create new item - $($itemName) - in Language en" -ForegroundColor Red
      $NonProcessedItems.Add(
      [PSCustomObject]@{
       ID = $row.ID
       Name    = $row.Name
       Path = $row.Path
})
}

if($item -ne $null){
$item.Editing.BeginEdit()
$item["Title"] = $row.Title

#Meta Properties/OG
$item["OpenGraphTitle"] = $row.Title
$item["OpenGraphDescription"] = $row.Summary
$item["MetaDescription"] = $row.Summary
$item["TwitterDescription"] = $row.Summary 
$item["TwitterImage"] = $row.OGImage
$item.Editing.EndEdit() | Out-Null

$datasourcePath =  $item.Paths.FullPath + "/Data/"
#Create and Populate Rich Text (Max RT are 3 as we had extracted 3 RTEs)
if($row.RichText1 -ne "")
{
For($i=1; $i -lt 4; $i++)
{
$propname = "RichText$i"
if($row.$propname -ne "")
{
$dsitem = New-Item -Path $datasourcePath -Name "Text $i" -ItemType "{4FBDBF79-C7D6-42F1-8048-D5E70D6167D5}"
$dsitem.Editing.BeginEdit()
$dsitem.Text =  $row.$propname
$dsitem.Editing.EndEdit() | Out-Null
#Create and Set Rich text Rendering
$rendering = get-item -path master: -id {EF82E4AE-C274-40D4-837C-B3E1BF180CCC}
$renderinginstance = $rendering | new-rendering -placeholder $placeholder
$renderinginstance.datasource = $dsitem.id
Add-Rendering -Item $item -placeholder $placeholder -instance $renderinginstance -finallayout
$item.Editing.beginedit()
$item.Editing.endedit() | out-null
}
}
}

#Create and Populate Accordion datasource item (Max Acc are 4)
if($row.AccTitle1 -ne "" -and $row.AccDesc1 -ne "")
{
$accDatasourcePath =  $item.Paths.FullPath + "/Data/"
#Accordion
$Accitem = New-Item -Path $accDatasourcePath -Name "Accordion" -ItemType "{D482D45C-4248-46C8-BDD5-DE7C2255C52A}"
$Accitem.Editing.BeginEdit()
$Accitem.Title =  "Accordion"
$Accitem.Editing.EndEdit() | Out-Null
#Create and Set Acc rendering
$rendering = Get-Item -Path master: -ID {3341A94D-42C9-4EE3-8A25-51D8B437982B}#Accordion
$renderingInstance = $rendering | New-Rendering -Placeholder $placeholder
$renderingInstance.Datasource = $Accitem.ID
Add-Rendering -Item $item -PlaceHolder $placeholder -Instance $renderingInstance -FinalLayout
For($i=1; $i -lt 5; $i++)
{
$titlename = "AccTitle$i"
$descname = "AccDesc$i"
if($row.$titlename -ne "" -and $row.$descname -ne "")
{
#Acc Panel
$dsitem = New-Item -Path $Accitem.Paths.FullPath -Name $row.$titlename -ItemType "{B50C502C-2740-44C8-A63E-E9E4AF4BAA4B}"
$dsitem.Editing.BeginEdit()
$dsitem.Title =  $row.$titlename
$dsitem.Content =  $row.$descname
$dsitem.Editing.EndEdit() | Out-Null
#Create and Set Acc panel rendering
$rendering = Get-Item -Path master: -ID {7614DFFF-6735-4BA5-929A-A82FBC91DB25}#Acc Panel
$renderingInstance = $rendering | New-Rendering -Placeholder "/headless-main/container-1/accordion-panels-1"
$renderingInstance.Datasource = $dsitem.ID
Add-Rendering -Item $item -PlaceHolder "/headless-main/container-1/accordion-panels-1" -Instance $renderingInstance -FinalLayout
$item.Editing.BeginEdit()
$item.Editing.EndEdit() | Out-Null
Write-LogExtended"Added Accordion datasource to New Item - $($item.Name) at $($dsitem.Paths.FullPath)" -ForegroundColor Green
}
}
}

$ManualWork = "No"
if(($row.HasRTE -gt 3) -or($row.HasAccordion -gt 4))
{
$ManualWork = "Yes"
}

Write-LogExtended"Created New Item - $($itemName) at $($parentItemPath)" -ForegroundColor Green
                    $processedItems.Add(
                    [PSCustomObject]@{
                            Name    = $item.Name
                            Id = $item.ID
                            NewPath = $item.Paths.FullPath
                            HasRTE = $row.HasRTE
                            HasAccordion = $row.HasAccordion
                            ManualWork = $ManualWork
})
}
}
else
{
Write-LogExtended"Item $($itemName) already exists at $($parentItemPath) " -ForegroundColor Yellow
}
}
else
{
Write-LogExtended"Parent item not found: $parentItemPath" -ForegroundColor Red
}
}

$processedItems | Show-ListView -PageSize 2000 -InfoTitle "Processed Items" -Property  Name, Id, NewPath, HasRTE, HasAccordion, ManualWork
$processedItems | export-csv -Path "C:\inetpub\wwwroot\App_Data\GenericPagesReport.csv" -NoTypeInformation
$NonProcessedItems | Show-ListView -PageSize 2000 -InfoTitle "Non Processed Items" -Property  ID, Name, Path
}
}
else
{
Write-Host"No file selected : $filePath"
}
