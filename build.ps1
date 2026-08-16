# Builds the standalone single-file game out of the docs/ folder.
#
#   docs\index.html + icons  ->  "MinePong v2.9.html"
#
# The result is one HTML file with the icons and the manifest inlined as data
# URIs: nothing to host, nothing to unpack, just send it to someone. Run this
# again after editing docs\index.html so the shareable file stays in sync.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root "docs\index.html"
$out  = Join-Path $root "MinePong v2.9.html"

function Get-DataUri([string]$file) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $root "docs\$file"))
    "data:image/png;base64," + [Convert]::ToBase64String($bytes)
}

$html = [System.IO.File]::ReadAllText($src)

$icon180 = Get-DataUri "apple-touch-icon.png"
$icon192 = Get-DataUri "icon-192.png"
$icon512 = Get-DataUri "icon-512.png"

# Manifest as a data URI. Only Chrome-family browsers read it, and only when the
# file is served over http(s) - harmless otherwise, useful if the same file ever
# gets uploaded somewhere.
$manifest = [ordered]@{
    name             = "Mine Pong"
    short_name       = "Mine Pong"
    start_url        = "."
    display          = "standalone"
    orientation      = "any"
    background_color = "#000000"
    theme_color      = "#000000"
    icons            = @(
        @{ src = $icon192; sizes = "192x192"; type = "image/png" },
        @{ src = $icon512; sizes = "512x512"; type = "image/png" }
    )
} | ConvertTo-Json -Compress -Depth 5
$manifestUri = "data:application/manifest+json;base64," +
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($manifest))

# 1. point the three <link> tags at the inlined copies
$html = $html.Replace('<link rel="manifest" href="manifest.webmanifest">',
                      "<link rel=""manifest"" href=""$manifestUri"">")
$html = $html.Replace('<link rel="apple-touch-icon" href="apple-touch-icon.png">',
                      "<link rel=""apple-touch-icon"" href=""$icon180"">")
$html = $html.Replace('<link rel="icon" href="icon-192.png" sizes="192x192">',
                      "<link rel=""icon"" href=""$icon192"" sizes=""192x192"">")

# 2. drop the service worker registration: there is no sw.js next to a file that
#    travels on its own, and a local copy is already offline by definition
$html = [Regex]::Replace($html, "(?s)\s*/\* SW_BLOCK_START \*/.*?/\* SW_BLOCK_END \*/", "")

foreach ($marker in @($manifestUri.Substring(0, 40), "SW_BLOCK_START")) {
    if ($marker -eq "SW_BLOCK_START" -and $html.Contains($marker)) {
        throw "service worker block was not stripped - check the markers in docs\index.html"
    }
}
if (-not $html.Contains("data:image/png;base64,")) {
    throw "icons were not inlined - the <link> tags in docs\index.html must have changed"
}

[System.IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding $false))
"{0}  ({1:N0} KB)" -f $out, ((Get-Item $out).Length / 1KB)
