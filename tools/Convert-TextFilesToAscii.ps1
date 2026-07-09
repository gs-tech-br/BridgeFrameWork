[CmdletBinding()]
param(
    # Shows the planned conversion by default. Use both switches to change files.
    [switch]$Apply,
    [switch]$ConfirmLossy,

    # Determines how characters with no safe ASCII transliteration are handled.
    [ValidateSet('Escape', 'Fail')]
    [string]$UnmappedCharacterPolicy = 'Escape',

    [string]$ReportPath = 'reports/ascii-conversion-preview.csv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Apply -and -not $ConfirmLossy) {
    throw 'A conversao para ASCII remove acentos e pode alterar literais. Para gravar, informe -Apply -ConfirmLossy.'
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$reportFullPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $ReportPath))
$binaryExtensions = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@(
    '.7z', '.avi', '.bin', '.bmp', '.db', '.dcu', '.dll', '.exe', '.gif', '.gz',
    '.ico', '.jpeg', '.jpg', '.lib', '.mp3', '.mp4', '.obj', '.otf', '.pdf', '.png',
    '.rar', '.res', '.sqlite', '.tar', '.ttf', '.wav', '.woff', '.woff2', '.zip'
) | ForEach-Object { [void]$binaryExtensions.Add($_) }

function Test-ByteSignature {
    param(
        [byte[]]$Bytes,
        [byte[]]$Signature
    )

    if ($Bytes.Length -lt $Signature.Length) { return $false }
    for ($index = 0; $index -lt $Signature.Length; $index++) {
        if ($Bytes[$index] -ne $Signature[$index]) { return $false }
    }
    return $true
}

function Get-TextFile {
    param([string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $extension = [IO.Path]::GetExtension($Path)
    if ($binaryExtensions.Contains($extension)) { return $null }

    # ASCII is defined by bytes 0x00 through 0x7F. A UTF-8 BOM therefore also
    # requires a rewrite, even if the visible content contains only ASCII.
    $isAsciiByteStream = $true
    foreach ($value in $bytes) {
        if ($value -gt 0x7F) {
            $isAsciiByteStream = $false
            break
        }
    }

    if (
        (Test-ByteSignature $bytes ([byte[]](0x1F, 0x8B))) -or # gzip
        (Test-ByteSignature $bytes ([byte[]](0x50, 0x4B, 0x03, 0x04))) -or # zip
        (Test-ByteSignature $bytes ([byte[]](0x25, 0x50, 0x44, 0x46, 0x2D))) -or # pdf
        (Test-ByteSignature $bytes ([byte[]](0x89, 0x50, 0x4E, 0x47))) -or # png
        (Test-ByteSignature $bytes ([byte[]](0x4D, 0x5A))) # Windows executable
    ) { return $null }

    $encoding = $null
    $offset = 0
    if (Test-ByteSignature $bytes ([byte[]](0xEF, 0xBB, 0xBF))) {
        $encoding = [Text.UTF8Encoding]::new($false, $true)
        $offset = 3
    }
    elseif (Test-ByteSignature $bytes ([byte[]](0xFF, 0xFE, 0x00, 0x00))) {
        $encoding = [Text.UTF32Encoding]::new($false, $true, $true)
        $offset = 4
    }
    elseif (Test-ByteSignature $bytes ([byte[]](0x00, 0x00, 0xFE, 0xFF))) {
        $encoding = [Text.UTF32Encoding]::new($true, $true, $true)
        $offset = 4
    }
    elseif (Test-ByteSignature $bytes ([byte[]](0xFF, 0xFE))) {
        $encoding = [Text.UnicodeEncoding]::new($false, $true, $true)
        $offset = 2
    }
    elseif (Test-ByteSignature $bytes ([byte[]](0xFE, 0xFF))) {
        $encoding = [Text.UnicodeEncoding]::new($true, $true, $true)
        $offset = 2
    }

    if ($null -ne $encoding) {
        try {
            $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
            return [PSCustomObject]@{ Text = $text; Encoding = $encoding.WebName; IsAsciiByteStream = $isAsciiByteStream }
        }
        catch { return $null }
    }

    # A NUL or other control character is a strong binary signal when no BOM exists.
    foreach ($value in $bytes) {
        if ($value -eq 0 -or (($value -lt 32) -and ($value -ne 9) -and ($value -ne 10) -and ($value -ne 13))) {
            return $null
        }
    }

    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        return [PSCustomObject]@{ Text = $text; Encoding = 'utf-8'; IsAsciiByteStream = $isAsciiByteStream }
    }
    catch {
        # Files invalid as UTF-8 are treated as legacy Windows ANSI, matching the audit.
        return [PSCustomObject]@{ Text = [Text.Encoding]::GetEncoding(1252).GetString($bytes); Encoding = 'windows-1252'; IsAsciiByteStream = $isAsciiByteStream }
    }
}

function Convert-TextToAscii {
    param(
        [string]$Text,
        [ValidateSet('Escape', 'Fail')]
        [string]$Policy
    )

    $transliterations = @{
        0x00C6 = 'AE'; 0x00E6 = 'ae'; 0x00D0 = 'D'; 0x00F0 = 'd'
        0x00D8 = 'O';  0x00F8 = 'o';  0x00DE = 'TH'; 0x00FE = 'th'
        0x00DF = 'ss'; 0x0152 = 'OE'; 0x0153 = 'oe'; 0x0141 = 'L'; 0x0142 = 'l'
        0x2013 = '-';  0x2014 = '--'; 0x2018 = "'"; 0x2019 = "'"
        0x201C = '"';  0x201D = '"';  0x2026 = '...'; 0x00A0 = ' '
    }

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $result = [Text.StringBuilder]::new($normalized.Length)
    for ($index = 0; $index -lt $normalized.Length; $index++) {
        $codePoint = [char]::ConvertToUtf32($normalized, $index)
        if ($codePoint -gt 0xFFFF) { $index++ }

        if ($codePoint -le 0x7F) {
            [void]$result.Append([char]$codePoint)
            continue
        }

        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($normalized, $index)
        if ($category -in [Globalization.UnicodeCategory]::NonSpacingMark, [Globalization.UnicodeCategory]::SpacingCombiningMark, [Globalization.UnicodeCategory]::EnclosingMark) {
            continue
        }

        if ($transliterations.ContainsKey($codePoint)) {
            [void]$result.Append([string]$transliterations[$codePoint])
            continue
        }

        if ($Policy -eq 'Fail') {
            throw ('Caractere sem transliteracao segura: U+{0:X4}' -f $codePoint)
        }

        # Keeps the character identifiable while ensuring the resulting file is ASCII-only.
        [void]$result.Append(('\\u{0:X4}' -f $codePoint))
    }
    return $result.ToString()
}

$relativeFiles = @(
    & rg --files --hidden -g '!.git/**' -g '!reports/ascii-conversion-preview.csv' $repositoryRoot |
        ForEach-Object { $_.Substring($repositoryRoot.Length).TrimStart([char[]]@('\', '/')) }
)

$results = foreach ($relativePath in $relativeFiles) {
    $fullPath = Join-Path $repositoryRoot $relativePath
    try {
        $source = Get-TextFile $fullPath
        if ($null -eq $source) {
            [PSCustomObject]@{ File = $relativePath; SourceEncoding = 'binary'; Action = 'skipped'; Detail = 'Binary or unsupported file' }
            continue
        }

        $converted = Convert-TextToAscii -Text $source.Text -Policy $UnmappedCharacterPolicy
        $contentChanged = $converted -cne $source.Text
        $requiresRewrite = $contentChanged -or -not $source.IsAsciiByteStream
        if ($requiresRewrite -and $Apply) {
            [IO.File]::WriteAllText($fullPath, $converted, [Text.Encoding]::ASCII)
        }

        [PSCustomObject]@{
            File = $relativePath
            SourceEncoding = $source.Encoding
            Action = if ($contentChanged) { if ($Apply) { 'converted' } else { 'would-convert' } } elseif ($requiresRewrite) { if ($Apply) { 'reencoded-ascii' } else { 'would-reencode-ascii' } } else { 'already-ascii' }
            Detail = if ($contentChanged) { 'Accents removed, transliterated, or escaped' } elseif ($requiresRewrite) { 'Removed UTF BOM or non-ASCII byte encoding' } else { '' }
        }
    }
    catch {
        [PSCustomObject]@{ File = $relativePath; SourceEncoding = 'unknown'; Action = 'skipped'; Detail = $_.Exception.Message }
    }
}

$reportDirectory = Split-Path -Parent $reportFullPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$results | Sort-Object File | Export-Csv -LiteralPath $reportFullPath -NoTypeInformation -Encoding ASCII
$results | Group-Object Action | Sort-Object Count -Descending | Select-Object Count, Name | Format-Table -AutoSize
Write-Output "Report: $reportFullPath"
if (-not $Apply) {
    Write-Output 'Preview only. No project file was changed.'
}
