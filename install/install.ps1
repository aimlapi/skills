# Install AI/ML API agent skills on Windows without Node.js (PowerShell 5.1+ or pwsh):
#
#   irm https://aimlapi.com/skills/install.ps1 | iex
#
# With options:
#
#   & ([scriptblock]::Create((irm https://aimlapi.com/skills/install.ps1))) -Agent cursor -Scope user aimlapi-models
#
# The skills come from the public npm package @ai-ml.api/skills (the same files
# `npx @ai-ml.api/skills install` copies). The tarball is checked against the
# registry's sha512 integrity before anything is written. No administrator
# rights and no Node.js are needed.
#
# Options:
#   -Agent   claude (default), cursor, codex, gemini, opencode, copilot, universal; several allowed
#   -Scope   project (the current repository, default) or user
#   -Dir     install into this folder instead
#   -DryRun  show what would be written
#   skill ... only these skills (default: all)
#
# Environment:
#   AIMLAPI_SKILLS_VERSION  version to install, e.g. 1.0.0 (default: latest)
#   AIMLAPI_NPM_REGISTRY    npm registry (default: https://registry.npmjs.org)
#
# Source of truth: install/install.ps1 in aimlapi/skills, attached to each
# release. Everything below is definitions; the only command is the call on
# the last line, so a truncated download runs nothing. Keep this file ASCII:
# Windows PowerShell 5.1 reads a BOM-less script in the ANSI code page.

# No positional binding: bare words are skill names, never -Agent or -Dir.
[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$Agent = @(),
  [string]$Scope = 'project',
  [string]$Dir = '',
  [switch]$DryRun,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Skill = @()
)

function Write-SkillsMessage([string]$Message) {
  [Console]::Error.WriteLine($Message)
}

function Get-SkillsAgentDir([string]$Name, [string]$Scope) {
  $map = @{
    'claude:project' = '.claude\skills'; 'claude:user' = '.claude\skills'
    'cursor:project' = '.agents\skills'; 'cursor:user' = '.cursor\skills'
    'codex:project' = '.agents\skills'; 'codex:user' = '.codex\skills'
    'gemini:project' = '.agents\skills'; 'gemini:user' = '.gemini\skills'
    'opencode:project' = '.agents\skills'; 'opencode:user' = '.config\opencode\skills'
    'copilot:project' = '.agents\skills'; 'copilot:user' = '.copilot\skills'
    'universal:project' = '.agents\skills'; 'universal:user' = '.agents\skills'
  }
  $key = "$($Name.ToLowerInvariant()):$Scope"
  if (-not $map.ContainsKey($key)) {
    throw "unknown agent $Name; use claude, cursor, codex, gemini, opencode, copilot or universal"
  }
  return $map[$key].Replace('\', [IO.Path]::DirectorySeparatorChar)
}

function Get-SkillsProjectRoot {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $root) { return [IO.Path]::GetFullPath($root) }
  }
  return (Get-Location).ProviderPath
}

function ConvertTo-SkillsBase64Sha512([string]$Path) {
  $hex = (Get-FileHash -LiteralPath $Path -Algorithm SHA512).Hash
  $bytes = New-Object byte[] ($hex.Length / 2)
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
  }
  return [Convert]::ToBase64String($bytes)
}

function Read-SkillsBlock([System.IO.Stream]$Stream, [byte[]]$Buffer, [long]$Count) {
  $read = 0
  while ($read -lt $Count) {
    $n = $Stream.Read($Buffer, $read, $Count - $read)
    if ($n -le 0) { throw 'the package tarball is truncated' }
    $read += $n
  }
}

function Get-SkillsTarString([byte[]]$Header, [int]$Offset, [int]$Length) {
  $end = $Offset
  while ($end -lt $Offset + $Length -and $Header[$end] -ne 0) { $end++ }
  return [Text.Encoding]::UTF8.GetString($Header, $Offset, $end - $Offset)
}

# Extracts every regular file under package/skills/ of the .tgz at $Tarball
# into $Destination with .NET only (GZipStream and a minimal ustar/pax
# reader), so it works on every Windows PowerShell without tar.exe.
function Expand-SkillsTarball([string]$Tarball, [string]$Destination) {
  $file = [IO.File]::OpenRead($Tarball)
  try {
    $gzip = New-Object IO.Compression.GZipStream($file, [IO.Compression.CompressionMode]::Decompress)
    $header = New-Object byte[] 512
    $paxPath = $null
    while ($true) {
      Read-SkillsBlock $gzip $header 512
      $empty = $true
      foreach ($b in $header) { if ($b -ne 0) { $empty = $false; break } }
      if ($empty) { break }

      $name = Get-SkillsTarString $header 0 100
      $sizeText = (Get-SkillsTarString $header 124 12).Trim()
      $size = [Convert]::ToInt64($(if ($sizeText) { $sizeText } else { '0' }), 8)
      $type = [char]$header[156]
      if ((Get-SkillsTarString $header 257 5) -eq 'ustar') {
        $prefix = Get-SkillsTarString $header 345 155
        if ($prefix) { $name = "$prefix/$name" }
      }
      if ($paxPath) { $name = $paxPath; $paxPath = $null }
      $padded = [long]([Math]::Ceiling($size / 512.0) * 512)

      if ($type -eq 'x') {
        $data = New-Object byte[] $padded
        Read-SkillsBlock $gzip $data $padded
        $text = [Text.Encoding]::UTF8.GetString($data, 0, $size)
        foreach ($record in $text.Split("`n")) {
          if ($record -match '^\d+ path=(.*)$') { $paxPath = $Matches[1] }
        }
        continue
      }

      $wanted = ($type -eq '0' -or $type -eq [char]0) -and $name.StartsWith('package/skills/')
      if ($wanted) {
        $rel = $name.Substring('package/skills/'.Length)
        foreach ($part in $rel.Split('/')) {
          if ($part -eq '..' -or $part -eq '') { throw "unsafe path in the package: $name" }
        }
        $target = Join-Path $Destination ($rel.Replace('/', [IO.Path]::DirectorySeparatorChar))
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        $out = [IO.File]::Create($target)
        try {
          $buffer = New-Object byte[] 65536
          $left = $size
          while ($left -gt 0) {
            $n = $gzip.Read($buffer, 0, [int][Math]::Min($buffer.Length, $left))
            if ($n -le 0) { throw 'the package tarball is truncated' }
            $out.Write($buffer, 0, $n)
            $left -= $n
          }
        } finally {
          $out.Dispose()
        }
        $rest = $padded - $size
        if ($rest -gt 0) { Read-SkillsBlock $gzip (New-Object byte[] $rest) $rest }
        continue
      }

      $skip = New-Object byte[] 512
      for ($left = $padded; $left -gt 0; $left -= 512) { Read-SkillsBlock $gzip $skip 512 }
    }
  } finally {
    $file.Dispose()
  }
}

function Invoke-SkillsInstall([string[]]$Agent, [string]$Scope, [string]$Dir, [bool]$DryRun, [string[]]$Skill) {
  $ProgressPreference = 'SilentlyContinue' # Invoke-WebRequest is very slow with a progress bar on 5.1
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

  if ($Scope -ne 'project' -and $Scope -ne 'user') { throw "-Scope must be project or user, not $Scope" }
  $agents = @($Agent | ForEach-Object { $_.Split(',') } | Where-Object { $_ })
  if ($agents.Count -eq 0) { $agents = @('claude') }
  foreach ($name in $Skill) {
    if ($name -notmatch '^aimlapi-[a-z0-9-]+$') { throw "unknown skill $name (skill names start with aimlapi-)" }
  }

  $targets = @()
  if ($Dir) {
    $targets = @([IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath $Dir)))
  } else {
    # USERPROFILE on Windows, HOME elsewhere; $HOME only as a last resort (pwsh on Linux fixes it at startup).
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { $HOME }
    $base = if ($Scope -eq 'user') { $userHome } else { Get-SkillsProjectRoot }
    foreach ($a in $agents) {
      $t = Join-Path $base (Get-SkillsAgentDir $a $Scope)
      if ($targets -notcontains $t) { $targets += $t }
    }
  }

  $registry = $env:AIMLAPI_NPM_REGISTRY
  if (-not $registry) { $registry = 'https://registry.npmjs.org' }
  $registry = $registry.TrimEnd('/')
  $version = $env:AIMLAPI_SKILLS_VERSION
  if (-not $version) { $version = 'latest' }
  $version = $version.TrimStart('v')
  if ($version -notmatch '^[0-9A-Za-z.+-]+$') { throw "invalid AIMLAPI_SKILLS_VERSION: $version" }
  $metadataUrl = "$registry/@ai-ml.api%2fskills/$version"

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("aimlapi-skills-" + [Guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($tmp)
  try {
    Write-SkillsMessage "Fetching @ai-ml.api/skills@$version from $registry"
    $metadata = Invoke-RestMethod -Uri $metadataUrl -UseBasicParsing -Headers @{ Accept = 'application/json' }
    $resolved = [string]$metadata.version
    $tarball = [string]$metadata.dist.tarball
    if (-not $resolved -or -not $tarball) { throw "unexpected registry response from $metadataUrl" }
    if ($version -match '^[0-9]' -and $resolved -ne $version) { throw "the registry returned version $resolved for $version" }
    if ($tarball -notmatch '^https?://') { throw "unexpected tarball URL in the registry response: $tarball" }
    $sha512 = $null
    foreach ($hash in ([string]$metadata.dist.integrity).Split(' ')) {
      if ($hash.StartsWith('sha512-')) { $sha512 = $hash.Substring(7); break }
    }
    if (-not $sha512) { throw "the registry gave no sha512 integrity for @ai-ml.api/skills@$resolved; refusing to install" }

    $tgz = Join-Path $tmp 'package.tgz'
    Invoke-WebRequest -Uri $tarball -OutFile $tgz -UseBasicParsing
    if ((ConvertTo-SkillsBase64Sha512 $tgz) -ne $sha512) {
      throw "integrity check failed for ${tarball}: its sha512 does not match the registry's; refusing to install"
    }

    $src = Join-Path $tmp 'skills'
    Expand-SkillsTarball $tgz $src
    $all = @(Get-ChildItem -LiteralPath $src -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | ForEach-Object { $_.Name } | Sort-Object)
    $names = if ($Skill.Count -gt 0) { $Skill } else { $all }
    foreach ($name in $names) {
      if ($all -notcontains $name) { throw "@ai-ml.api/skills@$resolved has no skill $name" }
    }

    foreach ($target in $targets) {
      foreach ($name in $names) {
        $dest = Join-Path $target $name
        $verb = if (Test-Path -LiteralPath $dest) { 'update' } else { 'install' }
        if ($DryRun) { Write-SkillsMessage "would $verb $dest"; continue }
        [void][IO.Directory]::CreateDirectory($target)
        # Copy next to the destination, then swap, so a failed copy never leaves half a skill.
        $staged = Join-Path $target ".$name.install.$PID"
        if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged -Recurse -Force }
        Copy-Item -LiteralPath (Join-Path $src $name) -Destination $staged -Recurse
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Move-Item -LiteralPath $staged -Destination $dest
        Write-SkillsMessage "${verb}d $dest"
      }
    }
    if (-not $DryRun) {
      Write-SkillsMessage ''
      Write-SkillsMessage "@ai-ml.api/skills $resolved is in place. Restart your agent (or start a new session) so it loads the skills."
      Write-SkillsMessage 'Scripts and examples read your key from AIMLAPI_API_KEY.'
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Invoke-SkillsInstall -Agent $Agent -Scope $Scope -Dir $Dir -DryRun ([bool]$DryRun) -Skill $Skill
