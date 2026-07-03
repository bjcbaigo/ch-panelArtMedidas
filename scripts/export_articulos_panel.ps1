param(
    [string]$Server = "10.10.10.99\SQL_AXOFT",
    [string]$Database = "CASA_CENTRAL",
    [string]$StockServer = "10.10.10.109\SQLEXPRESS_AXOFT",
    [string]$StockDatabase = "Suc_ChemesWeb",
    [string]$PrestashopImageFolder = "C:\Users\rbaig\Documents\Codex\2026-06-11\nueva-necesidad-hay-que-hacer-un\prestashop_imagenes",
    [int[]]$PriceLists = @(1, 2, 3, 4, 5, 6, 20, 21, 500, 501, 504),
    [string]$User = "Axoft",
    [string]$Password = $env:CHEMES_SQL_AXOFT_PASSWORD,
    [string]$OutputPath = ".\data\articulos-data.js"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Password)) {
    throw "Falta password. Defina CHEMES_SQL_AXOFT_PASSWORD o pase -Password."
}

$outputFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDir = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$connectionString = "Server=$Server;Database=$Database;User ID=$User;Password=$Password;TrustServerCertificate=True;Connection Timeout=20"
$priceListSql = ($PriceLists | ForEach-Object { [int]$_ }) -join ", "

function Convert-DbValue($value) {
    if ($null -eq $value -or $value -is [System.DBNull]) {
        return $null
    }
    if ($value -is [decimal] -or $value -is [double] -or $value -is [float]) {
        return [double]$value
    }
    return $value
}

$query = @"
select
    ltrim(rtrim(a.COD_ARTICU)) as sku,
    ltrim(rtrim(a.DESCRIPCIO)) as name,
    ltrim(rtrim(isnull(a.CA_967_MARCA, ''))) as brand,
    ltrim(rtrim(isnull(a.COD_BARRA, ''))) as barcode,
    ltrim(rtrim(isnull(a.DESC_ADIC, ''))) as category,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_ALTO_1_CM)[1]', 'varchar(50)'), ',', '.'), '')) as height,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_ANCHO_1_CM)[1]', 'varchar(50)'), ',', '.'), '')) as width,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_LARGO_1_CM)[1]', 'varchar(50)'), ',', '.'), '')) as depth,
    try_convert(decimal(18, 3), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_NUMBER_1733331476658)[1]', 'varchar(50)'), ',', '.'), '')) as weight,
    try_convert(decimal(18, 4), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_VOLUMEN)[1]', 'varchar(50)'), ',', '.'), '')) as volume,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_ALTO_2_CM)[1]', 'varchar(50)'), ',', '.'), '')) as package_height,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_ANCHO_2_CM)[1]', 'varchar(50)'), ',', '.'), '')) as package_width,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_LARGO_2_CM)[1]', 'varchar(50)'), ',', '.'), '')) as package_depth,
    try_convert(decimal(18, 2), nullif(replace(a.CAMPOS_ADICIONALES.value('(/CAMPOS_ADICIONALES/CA_NUMBER_1733331481626)[1]', 'varchar(50)'), ',', '.'), '')) as package_units,
    ltrim(rtrim(isnull(a.BMP, ''))) as image_path,
    convert(varchar(19), a.FECHA_ULTIMA_MODIFICACION, 120) as updated_at
from STA11 a
where a.PERFIL <> 'N'
  and a.STOCK = 1
order by a.COD_ARTICU
"@

$priceQuery = @"
select
    ltrim(rtrim(p.COD_ARTICU)) as sku,
    p.NRO_DE_LIS as price_list,
    p.PRECIO as price,
    ltrim(rtrim(isnull(l.NOMBRE_LIS, ''))) as name,
    isnull(l.HABILITADA, 0) as enabled
from GVA17 p
left join GVA10 l on l.NRO_DE_LIS = p.NRO_DE_LIS
where p.NRO_DE_LIS in ($priceListSql)
"@

$stockConnectionString = "Server=$StockServer;Database=$StockDatabase;User ID=$User;Password=$Password;TrustServerCertificate=True;Connection Timeout=20"
$stockQuery = @"
select
    ltrim(rtrim(COD_ARTICU)) as sku,
    sum(case when COD_DEPOSI = 'CD' then CANT_STOCK else 0 end) as stock_cd,
    sum(case when COD_DEPOSI = 'CA' then CANT_STOCK else 0 end) as stock_candioti,
    sum(case when COD_DEPOSI in ('50', '70') then CANT_STOCK else 0 end) as stock_colchoneria
from STA19
where COD_DEPOSI in ('CD', 'CA', '50', '70')
group by COD_ARTICU
"@

$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$command = $connection.CreateCommand()
$command.CommandTimeout = 120
$command.CommandText = $query

$table = New-Object System.Data.DataTable
$connection.Open()
try {
    $table.Load($command.ExecuteReader())
}
finally {
    $connection.Close()
}

$priceConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$priceCommand = $priceConnection.CreateCommand()
$priceCommand.CommandTimeout = 120
$priceCommand.CommandText = $priceQuery
$priceTable = New-Object System.Data.DataTable
$priceConnection.Open()
try {
    $priceTable.Load($priceCommand.ExecuteReader())
}
finally {
    $priceConnection.Close()
}

$priceListNames = @{}
$pricesBySku = @{}
foreach ($priceRow in $priceTable.Rows) {
    $listCode = [string][int]$priceRow.price_list
    $skuPrice = [string]$priceRow.sku
    if (-not $priceListNames.ContainsKey($listCode)) {
        $priceListNames[$listCode] = [string]$priceRow.name
    }
    if (-not $pricesBySku.ContainsKey($skuPrice)) {
        $pricesBySku[$skuPrice] = @{}
    }
    $pricesBySku[$skuPrice][$listCode] = Convert-DbValue $priceRow.price
}

$stockConnection = New-Object System.Data.SqlClient.SqlConnection $stockConnectionString
$stockCommand = $stockConnection.CreateCommand()
$stockCommand.CommandTimeout = 120
$stockCommand.CommandText = $stockQuery
$stockTable = New-Object System.Data.DataTable
$stockConnection.Open()
try {
    $stockTable.Load($stockCommand.ExecuteReader())
}
finally {
    $stockConnection.Close()
}

$stockBySku = @{}
foreach ($stockRow in $stockTable.Rows) {
    $stockBySku[[string]$stockRow.sku] = [ordered]@{
        cd = [double]$stockRow.stock_cd
        candioti = [double]$stockRow.stock_candioti
        colchoneria = [double]$stockRow.stock_colchoneria
    }
}

function Convert-ToFileUri($path) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        return $null
    }
    $resolved = [System.IO.Path]::GetFullPath($path)
    return ([System.Uri]::new($resolved)).AbsoluteUri
}

function Get-NormalizedSku($value) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    return ($value -replace '\s+', ' ').Trim().ToUpperInvariant()
}

function Get-BaseSku($value) {
    $normalized = Get-NormalizedSku $value
    if ($normalized -match '^(.+?)\s{1,}[A-Z0-9]{1,4}$') {
        return $matches[1].Trim()
    }
    return $normalized
}

$imageBySku = @{}
$imageExtensions = @(".jpg", ".jpeg", ".png", ".webp")
if (Test-Path -LiteralPath $PrestashopImageFolder) {
    $imageFiles = Get-ChildItem -LiteralPath $PrestashopImageFolder -File -Recurse |
        Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object FullName

    foreach ($imageFile in $imageFiles) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($imageFile.Name)
        $skuFromFile = Get-NormalizedSku ($name -replace '_\d+$', '')
        if ([string]::IsNullOrWhiteSpace($skuFromFile)) {
            continue
        }
        if (-not $imageBySku.ContainsKey($skuFromFile)) {
            $imageBySku[$skuFromFile] = New-Object System.Collections.ArrayList
        }
        [void]$imageBySku[$skuFromFile].Add([ordered]@{
            path = $imageFile.FullName
            uri = Convert-ToFileUri $imageFile.FullName
            name = $imageFile.Name
        })
    }
}

$products = foreach ($row in $table.Rows) {
    $height = Convert-DbValue $row.height
    $width = Convert-DbValue $row.width
    $depth = Convert-DbValue $row.depth
    $weight = Convert-DbValue $row.weight
    $sku = [string]$row.sku
    $prices = [ordered]@{}
    foreach ($listCode in $PriceLists) {
        $listKey = [string]$listCode
        $prices[$listKey] = if ($pricesBySku.ContainsKey($sku) -and $pricesBySku[$sku].ContainsKey($listKey)) {
            $pricesBySku[$sku][$listKey]
        } else {
            $null
        }
    }
    $stock = if ($stockBySku.ContainsKey($sku)) {
        $stockBySku[$sku]
    } else {
        [ordered]@{
            cd = 0
            candioti = 0
            colchoneria = 0
        }
    }
    $normalizedSku = Get-NormalizedSku $sku
    $baseSku = Get-BaseSku $sku
    $prestashopImages = if ($imageBySku.ContainsKey($normalizedSku)) {
        @($imageBySku[$normalizedSku])
    } elseif ($imageBySku.ContainsKey($baseSku)) {
        @($imageBySku[$baseSku])
    } else {
        @()
    }
    $primaryImage = if ($prestashopImages.Count -gt 0) { $prestashopImages[0].uri } else { $null }
    $primaryImagePath = if ($prestashopImages.Count -gt 0) { $prestashopImages[0].path } else { [string]$row.image_path }
    $missingLogistics = ($null -eq $height -or $null -eq $width -or $null -eq $depth -or $null -eq $weight)
    $hasAnyLogistics = ($null -ne $height -or $null -ne $width -or $null -ne $depth -or $null -ne $weight)
    $status = if (-not $missingLogistics) { "ok" } elseif ($hasAnyLogistics) { "warn" } else { "bad" }

    [ordered]@{
        sku = $sku
        name = [string]$row.name
        brand = [string]$row.brand
        barcode = [string]$row.barcode
        category = [string]$row.category
        dimensions = [ordered]@{
            height = $height
            width = $width
            depth = $depth
        }
        weight = $weight
        volume = Convert-DbValue $row.volume
        packageDimensions = [ordered]@{
            height = Convert-DbValue $row.package_height
            width = Convert-DbValue $row.package_width
            depth = Convert-DbValue $row.package_depth
            units = Convert-DbValue $row.package_units
        }
        stock = $stock
        prices = $prices
        status = $status
        image = $primaryImage
        imagePath = $primaryImagePath
        images = @($prestashopImages)
        notes = if ($status -eq "ok") {
            "Ficha logistica completa segun campos actuales de Tango."
        } elseif ($hasAnyLogistics) {
            "Ficha logistica parcial. Revisar medidas/peso antes de publicar."
        } else {
            "Sin medidas/peso cargados en campos adicionales de Tango."
        }
        updatedAt = [string]$row.updated_at
    }
}

$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$priceListPayload = foreach ($listCode in $PriceLists) {
    $listKey = [string]$listCode
    [ordered]@{
        code = $listKey
        name = if ($priceListNames.ContainsKey($listKey)) { $priceListNames[$listKey] } else { "Lista $listKey" }
    }
}
$payload = [ordered]@{
    generatedAt = $generatedAt
    source = "$Server/$Database"
    stockSource = "$StockServer/$StockDatabase"
    imageSource = $PrestashopImageFolder
    priceLists = @($priceListPayload)
    products = $products
}

$json = $payload | ConvertTo-Json -Depth 8
$content = "window.PANEL_DATA = $json;`r`n"
[System.IO.File]::WriteAllText($outputFullPath, $content, [System.Text.Encoding]::UTF8)

Write-Host "Exportados $($products.Count) articulos a $outputFullPath"
