param([string]$SourceDir, [string]$OutputDir,
    [string[]]$Names=@('00_Topology','01_SISO_VsVo_a','02_SISO_VsVo_b'),
    [string]$ManifestName='visio_sources.csv')
$ErrorActionPreference='Stop'
. 'C:\Users\SuSug\.codex\skills\visio-image-rebuilder\scripts\visio_export_formats.ps1'
$app=New-Object -ComObject Visio.Application
$app.Visible=$false
$records=@()
try {
    foreach($name in $Names) {
        $path=Join-Path $SourceDir ($name+'.vsdx')
        $before=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $doc=$app.Documents.OpenEx($path,66)
        try {
            Export-VisioPageFormats -Document $doc -Page $doc.Pages.Item(1) -SourcePath $path -Formats @('png') -OutputDir $OutputDir
        } finally { $doc.Close() }
        $after=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if($before -ne $after) { throw 'Source hash changed' }
        $records += [pscustomobject]@{Source=$path;SHA256=$after;Unchanged=$true}
    }
    $records | Export-Csv -LiteralPath (Join-Path $OutputDir $ManifestName) -NoTypeInformation -Encoding UTF8
} finally {
    $app.Quit()
    [Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
}
