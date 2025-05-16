<#
    .SYNOPSIS
       Generic Page data extraction
       
    .DESCRIPTION
        Gets Sitecore Items from legacy database and extracts field values.
        List could be exported to csv by OOTB feature of List View in SPE.
        
    .NOTES
        Akash Borkar 
#>

function Write-LogExtended {
param(
[string]$Message,
[System.ConsoleColor]$ForegroundColor = $host.UI.RawUI.ForegroundColor,
[System.ConsoleColor]$BackgroundColor = $host.UI.RawUI.BackgroundColor
)
    Write-Log -Object $message
    Write-Host -Object $message -ForegroundColor $ForegroundColor -BackgroundColor $backgroundColor
}

# Function for getting item names from pipe-separated item ids
function GetItemNamesFromIds {
param(
[System.String] $ids
)
if($ids.Contains("|"))
{
# Split the string by pipe and clean up each GUID
        $guids = $ids.Split("|")| ForEach-Object { $_.Trim(' {}')}
[Sitecore.Text.ListString]$nameArr = ""
foreach($id in $guids){
            $formattedId = "{0}{1}{2}" -f '{', $id, '}'
            $Id = [Sitecore.Data.ID]::Parse($formattedId)
            $item = Get-Item -Path xyz: -ID $Id
if($item -ne $null -and !$nameArr.Contains($item.Name)){
                $nameArr.Add($item.Name)| Out-Null
}
}
# Join the names with pipe separator and return the result
        $names = [System.String]::Join("|", $nameArr)
return $names
}
else
{
        $item = Get-Item -Path xyz: -ID $ids
        return $item.Name
}
}

#Function for getting datasource item, which is further used for extracting field value & assigning to new rendering
function Get-DatasourceItem{
param(
[System.String] $path
)
        $datasourceItem = $sourceDatabase.GetItem($path)
return $datasourceItem
}


Write-LogExtended "Generic Pages Data Extraction"
Write-LogExtended "-----------------------------------------------------------------"
$processedItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$nonprocessedItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$sourceDatabase = Get-Database "xyz"
$parentPath = Show-Input -Prompt "Please enter the Sitecore item path for getting children"
if($parentPath -ne $null)
{
    Write-Host "Selected path: $parentPath"
    #Get all child items based on provided path. /sitecore/content/XYZ/Home/Generic
    $nodePath = "xyz:" + $parentPath
    $items = Get-ChildItem -Path $nodePath -Recurse | Where-Object { $_.TemplateName -eq 'Generic Page'}
    Write-LogExtended "Total child items: $($items.Count)  Path: $($nodePath)" -ForegroundColor Green

foreach($sourceItem in $items)
{
if($sourceItem -ne $null){
#Retrieve RTE
$rts = Get-Rendering -Item $sourceItem -Device $defaultLayout -FinalLayout | Where-Object { $_.ItemID -eq "{278F7B0D-98F4-4873-9B7B-940082158E4A}"}
[Sitecore.Text.ListString]$rtArr = ""
if($rts -ne $null)
{
foreach($rt in $rts)
{
$item = $sourceDatabase.GetItem($rt.Datasource)
if($item -ne $null -and $item["Text"] -ne "")
{
    $rtArr.Add($item["Text"])| Out-Null
}
}
}

#Retrieve Accordion
$accordion = Get-Rendering -Item $sourceItem -Device $defaultLayout -FinalLayout | Where-Object { $_.ItemID -eq "{165B5ECC-E6A0-4B41-AA23-D28FA5A9BF68}"}
$accordionCount = 0
[Sitecore.Text.ListString]$titleArr = ""
[Sitecore.Text.ListString]$descArr = ""
if($accordion -ne $null)
{
    foreach($renderingItem in $accordion)
    {
      if($renderingItem.Datasource -ne "")
      {
          $rendering = Get-Item -Path xyz: -Id $renderingItem.Datasource
        if($rendering.HasChildren)
        {
           $accdChildItems = Get-ChildItem -Path xyz: -ID $rendering.ID
           foreach($item in $accdChildItems)
           {
            if($item["Title"] -ne "" -and $item["Description"] -ne "")
            {
                  $titleArr.Add($item["Title"])| Out-Null
                  $descArr.Add($item["Description"])| Out-Null
            }
           }
                            $accordionCount++;
        }
       }
    }
}

#Retrieve values of multilist field named Categories
            $categories = $sourceitem["Categories"]
            $categoriesnames = ""
if($categories -ne "" -and $categories -ne $null)
{
    $categoriesnames = GetItemNamesFromIds -ids $categories
}
try{
                $processedItems.Add(
                [PSCustomObject]@{
                        Name = $sourceItem.Name
                        Id = $sourceItem.Id
                        Path = $sourceItem.Paths.FullPath
                        Title = $sourceItem["Title"]
                        HeaderTitle = $sourceItem["Header Title"]
                        Summary = $sourceItem["Summary"]
                        Image = $sourceItem["Image"]
                        OGImage = $sourceItem["Media Image"]
                        Categories = $categoriesnames
                        HasRTE = $rtArr.Count
                        RichText1 = $richText
                        RichText2 = $rtArr[1]
                        RichText3 = $rtArr[2]
                        HasAccordion = $accordionCount
                        AccTitle1 = $titleArr[0]
                        AccDesc1 = $descArr[0]
                        AccTitle2 = $titleArr[1]
                        AccDesc2 = $descArr[1]
                        AccTitle3 = $titleArr[2]
                        AccDesc3 = $descArr[2]
                        AccTitle4 = $titleArr[3]
                        AccDesc4 = $descArr[3]
}
)
  Write-LogExtended "Added data for $($sourceItem.Name), Path: $($sourceItem.Paths.FullPath) " -ForegroundColor Green
}
catch{
                Write-Host "Error occured" -BackgroundColor DarkRed
                $nonprocessedItems.Add(
                [PSCustomObject]@{
                        Name = $sourceItem.Name
                        Id = $sourceItem.Id
                        Path = $sourceItem.Paths.FullPath
}
)
}
}
else
{
  Write-LogExtended "No Item found in csv for SourceURL: $($row.SourceURL)" -ForegroundColor RED
}
}
    $processedItems | Show-ListView -PageSize 15000 -Property  Name, Id, Path, Title, HeaderTitle, Summary, Categories, Image, OGImage, 
                                                               HasRTE, RichText1, RichText2, RichText3, HasAccordion, AccTitle1, AccDesc1, AccTitle2, AccDesc2, AccTitle3, 
                                                               AccDesc3, AccTitle4, AccDesc4
    $processedItems | export-csv -Path "C:\inetpub\wwwroot\App_Data\Process.csv" -NoTypeInformation                                                  
    $nonprocessedItems | Show-ListView -PageSize 15000 -Property  Name, Id, Path
}
else
{
        Write-Host "Path is not provided : $parentPath"
}
