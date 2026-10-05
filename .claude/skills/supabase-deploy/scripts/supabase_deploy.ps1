<#
.SYNOPSIS
    Safe, non-interactive Supabase deployment for Telly: migrations, edge functions, secrets checks.

.DESCRIPTION
    The only manual prerequisite is `supabase login` (browser). Database access uses the CLI's
    temporary login role, so no database password is needed.

    Actions:
      status     (default) Login + link check, migration status, edge function drift, secret presence.
      plan       status + `supabase db push --dry-run`.
      push       plan + backup (when Docker is running) + `supabase db push --linked --yes` + verify.
      functions  Deploy edge functions (-Functions changed | all | name1,name2) with --use-api.
      deploy     push, then functions.
      test       Local pgTAP suite (`supabase test db`), needs Docker Desktop.

    Exit codes: 0 ok, 1 failure, 2 not logged in (run `supabase login`), 3 unsafe state (refused).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .agents/skills/supabase-deploy/scripts/supabase_deploy.ps1
    powershell -ExecutionPolicy Bypass -File .agents/skills/supabase-deploy/scripts/supabase_deploy.ps1 -Action plan
    powershell -ExecutionPolicy Bypass -File .agents/skills/supabase-deploy/scripts/supabase_deploy.ps1 -Action deploy -Functions changed
    powershell -ExecutionPolicy Bypass -File .agents/skills/supabase-deploy/scripts/supabase_deploy.ps1 -Action functions -Functions tmdb-details
#>

[CmdletBinding()]
param(
    [ValidateSet("status", "plan", "push", "functions", "deploy", "test")]
    [string]$Action = "status",

    # 'changed' (default): not deployed yet, or committed/edited after the last deploy.
    [string]$Functions = "changed",

    # telly-prod. A different linked ref is refused unless passed explicitly.
    [string]$ProjectRef = "cdbfixrttnysqvtulufm",

    # Proceed without a pg_dump backup when Docker is unavailable (platform daily backups still apply).
    [switch]$SkipBackup,

    # Allow pushing into a remote with NO migration history (would run the whole schema).
    [switch]$AllowFullSchema
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
Set-Location $RepoRoot

function Write-Step([string]$msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Gray }
function Write-Ok([string]$msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

# Prefer the native exe / cmd shim: the npm PowerShell shim turns CLI stderr (e.g. the
# "new version available" banner) into terminating PowerShell errors.
$SupabaseCli = (Get-Command supabase.exe, supabase.cmd -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $SupabaseCli) { $SupabaseCli = "supabase" }

# Runs the CLI with stdin closed (never hangs on a prompt). Returns stdout; throws on failure.
function Invoke-Sb {
    param([string[]]$CliArgs, [switch]$Json, [switch]$Stream)
    $ErrorActionPreference = "Continue"
    $all = @($CliArgs)
    if ($Json) { $all += @("--output-format", "json") }
    if ($Stream) {
        $null | & $SupabaseCli @all 2>&1 | ForEach-Object { Write-Host "$_" }
        if ($LASTEXITCODE -ne 0) { throw "supabase $($CliArgs -join ' ') failed (exit $LASTEXITCODE)" }
        return $null
    }
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $out = $null | & $SupabaseCli @all 2> $errFile
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            $err = (Get-Content $errFile -Raw)
            throw "supabase $($CliArgs -join ' ') failed (exit $code): $err"
        }
    } finally {
        Remove-Item $errFile -ErrorAction SilentlyContinue
    }
    $text = ($out | Out-String).Trim()
    if ($Json) {
        # Skip any banner lines before the JSON document.
        $start = $text.IndexOf("{")
        if ($start -lt 0) { throw "No JSON in output of supabase $($CliArgs -join ' ')" }
        return ($text.Substring($start) | ConvertFrom-Json)
    }
    return $text
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return $false }
    $null = & docker info 2>$null
    return ($LASTEXITCODE -eq 0)
}

# ----------------------------------------------------------------------------- preflight
function Assert-Ready {
    Write-Step "Preflight"
    if (-not (Get-Command $SupabaseCli -ErrorAction SilentlyContinue)) {
        Write-Fail "Supabase CLI not found. Install: npm i -g supabase (or scoop install supabase)."
        exit 1
    }
    Write-Info ("CLI " + (Invoke-Sb @("--version")).Split("`n")[0])

    try {
        $projects = (Invoke-Sb @("projects", "list") -Json).projects
    } catch {
        Write-Fail "Not logged in to Supabase. The ONE manual step: run 'supabase login' in a terminal, then re-run."
        exit 2
    }
    $project = $projects | Where-Object { $_.ref -eq $ProjectRef }
    if (-not $project) {
        Write-Fail "Logged-in account cannot see project $ProjectRef."
        exit 1
    }
    Write-Ok "Logged in; target project '$($project.name)' ($ProjectRef) is $($project.status)."

    $refFile = Join-Path $RepoRoot "supabase\.temp\project-ref"
    $linked = ""
    if (Test-Path $refFile) { $linked = (Get-Content $refFile -Raw).Trim() }
    if ($linked -ne $ProjectRef) {
        if ($linked) {
            Write-Fail "Repo is linked to '$linked', not '$ProjectRef'. Pass -ProjectRef $linked to target it deliberately."
            exit 3
        }
        Write-Info "Linking repo to $ProjectRef ..."
        Invoke-Sb @("link", "--project-ref", $ProjectRef, "--yes") | Out-Null
    }
    Write-Ok "Repo linked to $ProjectRef."
    return $project
}

# ----------------------------------------------------------------------------- migrations
function Get-MigrationState {
    $rows = (Invoke-Sb @("migration", "list", "--linked") -Json).migrations
    $local = @($rows | Where-Object { $_.local } | ForEach-Object { $_.local })
    $remote = @($rows | Where-Object { $_.remote } | ForEach-Object { $_.remote })
    $pending = @($local | Where-Object { $remote -notcontains $_ })
    $remoteOnly = @($remote | Where-Object { $local -notcontains $_ })
    $latestRemote = ""
    if ($remote.Count -gt 0) { $latestRemote = ($remote | Sort-Object)[-1] }
    $outOfOrder = @($pending | Where-Object { $latestRemote -and $_ -lt $latestRemote })
    return [pscustomobject]@{
        Local = $local; Remote = $remote; Pending = $pending
        RemoteOnly = $remoteOnly; OutOfOrder = $outOfOrder
    }
}

function Show-Migrations($state) {
    Write-Step "Migrations ($($state.Local.Count) local, $($state.Remote.Count) remote)"
    if ($state.Pending.Count -eq 0) { Write-Ok "Remote is up to date; nothing to push." }
    foreach ($v in $state.Pending) {
        $file = Get-ChildItem (Join-Path $RepoRoot "supabase\migrations") -Filter "$v*.sql" | Select-Object -First 1
        Write-Warn "PENDING  $($file.Name)"
    }
    foreach ($v in $state.RemoteOnly) { Write-Fail "REMOTE-ONLY $v (applied remotely but missing locally)" }
}

function Assert-SafeToPush($state) {
    if ($state.RemoteOnly.Count -gt 0) {
        Write-Fail "Remote has migrations this repo lacks. Pull them first (supabase migration fetch / git pull). Refusing."
        exit 3
    }
    if ($state.OutOfOrder.Count -gt 0) {
        Write-Fail "Pending migration(s) $($state.OutOfOrder -join ', ') are older than the newest remote migration. Rename with a newer timestamp. Refusing."
        exit 3
    }
    if ($state.Remote.Count -eq 0 -and $state.Local.Count -gt 0 -and -not $AllowFullSchema) {
        Write-Fail "Remote migration history is EMPTY: pushing would run the entire schema. Re-run with -AllowFullSchema only for a brand-new project. Refusing."
        exit 3
    }
}

function Invoke-Backup {
    $dir = Join-Path $RepoRoot "supabase\backups"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (-not (Test-Docker)) {
        if ($SkipBackup) {
            Write-Warn "Docker not running: skipping pg_dump backup (-SkipBackup). Platform daily backups remain available."
            return
        }
        Write-Fail "Docker Desktop is not running, so no pre-push backup can be taken. Start Docker, or re-run with -SkipBackup."
        exit 3
    }
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $schema = Join-Path $dir "$($stamp)_schema.sql"
    $data = Join-Path $dir "$($stamp)_data.sql"
    Write-Info "Backing up schema -> supabase/backups/$(Split-Path $schema -Leaf)"
    Invoke-Sb @("db", "dump", "--linked", "-f", $schema) | Out-Null
    Write-Info "Backing up data   -> supabase/backups/$(Split-Path $data -Leaf)"
    Invoke-Sb @("db", "dump", "--linked", "--data-only", "-f", $data) | Out-Null
    Write-Ok "Backup written (gitignored)."
}

function Invoke-Push {
    $state = Get-MigrationState
    Show-Migrations $state
    if ($state.Pending.Count -eq 0) { return }
    Assert-SafeToPush $state

    Write-Step "Dry run"
    Invoke-Sb @("db", "push", "--linked", "--dry-run") -Stream

    if ($Action -eq "plan") { return }

    Write-Step "Backup"
    Invoke-Backup

    Write-Step "Applying $($state.Pending.Count) migration(s)"
    Invoke-Sb @("db", "push", "--linked", "--yes") -Stream

    $after = Get-MigrationState
    if ($after.Pending.Count -gt 0) {
        Write-Fail "Still pending after push: $($after.Pending -join ', ')"
        exit 1
    }
    Write-Ok "All migrations applied to $ProjectRef."
}

# ----------------------------------------------------------------------------- edge functions
$FunctionsDir = Join-Path $RepoRoot "supabase\functions"
$PlatformSecrets = @("SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_DB_URL")
# Env vars a function reads only as an optional upgrade.
$OptionalSecrets = @("WATCHMODE_API_KEY")
# Any one of each group satisfies the requirement.
$EitherOf = @(, @("TMDB_ACCESS_TOKEN", "TMDB_API_KEY"))

function Get-LocalFunctions {
    Get-ChildItem $FunctionsDir -Directory |
        Where-Object { -not $_.Name.StartsWith("_") -and $_.Name -ne "tests" -and (Test-Path (Join-Path $_.FullName "index.ts")) } |
        ForEach-Object { $_.Name }
}

function Get-RequiredSecrets([string]$name) {
    $files = Get-ChildItem (Join-Path $FunctionsDir $name) -Filter *.ts -Recurse
    $names = @()
    foreach ($f in $files) {
        $names += ([regex]::Matches((Get-Content $f.FullName -Raw), 'Deno\.env\.get\("([A-Z0-9_]+)"\)') | ForEach-Object { $_.Groups[1].Value })
    }
    return @($names | Sort-Object -Unique | Where-Object { $PlatformSecrets -notcontains $_ -and $OptionalSecrets -notcontains $_ })
}

function Get-MissingSecrets([string]$name, [string[]]$have) {
    $required = Get-RequiredSecrets $name
    $missing = @()
    $handled = @()
    foreach ($group in $EitherOf) {
        $needed = @($group | Where-Object { $required -contains $_ })
        if ($needed.Count -eq 0) { continue }
        $handled += $group
        if (-not ($group | Where-Object { $have -contains $_ })) { $missing += ($group -join " or ") }
    }
    foreach ($s in $required) {
        if ($handled -notcontains $s -and $have -notcontains $s) { $missing += $s }
    }
    return $missing
}

# Epoch seconds of the latest commit touching the function or _shared; now when uncommitted edits exist.
function Get-SourceTime([string]$name) {
    $paths = @("supabase/functions/$name", "supabase/functions/_shared")
    $dirty = (& git status --porcelain -- @paths) | Out-String
    if ($dirty.Trim()) { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    $ct = (& git log -1 --format=%ct -- @paths) | Out-String
    if ($ct.Trim()) { return [int64]$ct.Trim() }
    return 0
}

function Get-FunctionState {
    $deployed = @{}
    $raw = Invoke-Sb @("functions", "list", "--project-ref", $ProjectRef) -Json
    $list = $raw
    if ($raw.PSObject.Properties.Name -contains "functions") { $list = $raw.functions }
    foreach ($f in $list) { $deployed[$f.slug] = $f }
    $secrets = @((Invoke-Sb @("secrets", "list", "--project-ref", $ProjectRef) -Json).secrets | ForEach-Object { $_.name })

    $rows = @()
    foreach ($name in Get-LocalFunctions) {
        $d = $deployed[$name]
        $deployedAt = 0
        if ($d) { $deployedAt = [int64]([double]$d.updated_at / 1000) }
        $changed = (-not $d) -or ((Get-SourceTime $name) -gt $deployedAt)
        $rows += [pscustomobject]@{
            Name = $name
            Deployed = [bool]$d
            Version = $(if ($d) { $d.version } else { "-" })
            Changed = $changed
            Missing = @(Get-MissingSecrets $name $secrets)
        }
    }
    return $rows
}

function Show-Functions($rows) {
    Write-Step "Edge functions"
    foreach ($r in $rows) {
        $status = "up to date (v$($r.Version))"
        if (-not $r.Deployed) { $status = "NOT DEPLOYED" } elseif ($r.Changed) { $status = "CHANGED since v$($r.Version)" }
        $line = "{0,-24} {1}" -f $r.Name, $status
        if ($r.Missing.Count -gt 0) { $line += "  | missing secret: $($r.Missing -join ', ')" }
        if ($r.Missing.Count -gt 0) { Write-Warn $line } elseif ($r.Changed) { Write-Warn $line } else { Write-Ok $line }
    }
}

function Invoke-Functions {
    $rows = Get-FunctionState
    Show-Functions $rows
    $targets = @()
    switch ($Functions) {
        "changed" { $targets = @($rows | Where-Object { $_.Changed }) }
        "all" { $targets = $rows }
        default {
            $wanted = $Functions.Split(",") | ForEach-Object { $_.Trim() }
            foreach ($w in $wanted) {
                $match = $rows | Where-Object { $_.Name -eq $w }
                if (-not $match) { Write-Fail "Unknown function '$w'. Local functions: $((Get-LocalFunctions) -join ', ')"; exit 1 }
                $targets += $match
            }
        }
    }
    if ($targets.Count -eq 0) { Write-Ok "No functions to deploy."; return }

    foreach ($t in $targets) {
        if ($t.Missing.Count -gt 0) {
            Write-Warn "Skipping $($t.Name): set its secret first (supabase secrets set NAME=value --project-ref $ProjectRef). Missing: $($t.Missing -join ', ')"
            continue
        }
        Write-Step "Deploying $($t.Name)"
        Invoke-Sb @("functions", "deploy", $t.Name, "--project-ref", $ProjectRef, "--use-api") -Stream
        Write-Ok "$($t.Name) deployed."
    }
}

# ----------------------------------------------------------------------------- main
if ($Action -eq "test") {
    Write-Step "Local pgTAP suite"
    if (-not (Test-Docker)) { Write-Fail "Docker Desktop must be running for 'supabase test db'."; exit 1 }
    Invoke-Sb @("start") -Stream
    Invoke-Sb @("db", "reset", "--local") -Stream
    Invoke-Sb @("test", "db") -Stream
    Write-Ok "pgTAP suite passed."
    exit 0
}

Assert-Ready | Out-Null

switch ($Action) {
    "status" {
        Show-Migrations (Get-MigrationState)
        Show-Functions (Get-FunctionState)
    }
    "plan" { Invoke-Push; Show-Functions (Get-FunctionState) }
    "push" { Invoke-Push }
    "functions" { Invoke-Functions }
    "deploy" { Invoke-Push; Invoke-Functions }
}
Write-Host ""
Write-Ok "Done ($Action)."
