<#
  WASA Bhakkar: one-time Supabase setup and checks, run on the office Windows PC.

  What it does:
    1. writes apps/office/env.json and apps/driver/env.json (URL + publishable key; git-ignored)
    2. links this folder to your Supabase project and pushes all migrations + the seed
    3. runs the SQL checks on the real project (seed, rules, RLS, "nobody can mark Paid")
    4. signs in as operator1, driver1 and admin through the real Auth API and checks
       what each one can see and that none of them can mark a challan Paid

  Needs: Node.js (for npx), internet. Run from the repo folder in PowerShell:
      powershell -ExecutionPolicy Bypass -File tool\setup_supabase.ps1
  Re-run the checks only (no push):
      powershell -ExecutionPolicy Bypass -File tool\setup_supabase.ps1 -SkipPush
#>
param(
  [string]$ProjectRef = "xjdfwjjvudndxbdlkkki",
  [string]$Url = "https://xjdfwjjvudndxbdlkkki.supabase.co",
  [string]$PublishableKey = "sb_publishable_Ho9b_grpRMvhJdHyMCxntQ_RLvtBnG8",
  [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$failed = 0

function Step($text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }
function Ok($text)   { Write-Host "   OK   $text" -ForegroundColor Green }
function Bad($text)  { Write-Host "   FAIL $text" -ForegroundColor Red; $script:failed++ }
function Run($exe, [string[]]$argv) {
  & $exe @argv
  if ($LASTEXITCODE -ne 0) { throw "'$exe $($argv -join ' ')' failed (exit code $LASTEXITCODE)" }
}

# ------------------------------------------------------------------ 1. env files
Step "1. Writing env.json for both apps"
$envJson = @{ SUPABASE_URL = $Url; SUPABASE_PUBLISHABLE_KEY = $PublishableKey; LOGIN_DOMAIN = "wasabhakkar.demo" } |
  ConvertTo-Json
foreach ($app in "apps\office", "apps\driver") {
  # UTF-8 without BOM (Flutter's --dart-define-from-file does not accept a BOM)
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) "$app\env.json"), $envJson, (New-Object System.Text.UTF8Encoding $false))
  Ok "$app\env.json"
}
$ignored = git check-ignore apps/office/env.json apps/driver/env.json .env 2>$null
if (($ignored | Measure-Object).Count -eq 3) { Ok "env.json and .env are git-ignored" } else { Bad "env files are NOT git-ignored - check .gitignore" }

# ------------------------------------------------------------------ 2. link + push
if (-not $SkipPush) {
  Step "2. Linking to project $ProjectRef and pushing migrations + seed"
  Write-Host "   A browser window opens to log in to Supabase (first time only)."
  Run "npx" @("-y", "supabase@latest", "login")
  Write-Host "   You will be asked for the DATABASE PASSWORD you chose when creating the project."
  Run "npx" @("-y", "supabase@latest", "link", "--project-ref", $ProjectRef)
  Run "npx" @("-y", "supabase@latest", "db", "push", "--include-seed", "--yes")
  Ok "migrations and seed pushed"
}

# ------------------------------------------------------------------ 3. SQL checks on the real project
Step "3. SQL checks on the real project (rolled back, nothing is changed)"
foreach ($test in Get-ChildItem "supabase\tests\test_*.sql" | Sort-Object Name) {
  & npx -y supabase@latest db query --linked -f $test.FullName
  if ($LASTEXITCODE -eq 0) { Ok $test.Name } else { Bad "$($test.Name) (see the error above)" }
}

# ------------------------------------------------------------------ 4. real sign-ins through the API
Step "4. Signing in through Supabase Auth and checking permissions"
$base = @{ apikey = $PublishableKey }

function SignIn($user) {
  $body = @{ email = "$user@wasabhakkar.demo"; password = "Wasa@1234" } | ConvertTo-Json
  $r = Invoke-RestMethod -Method Post -Uri "$Url/auth/v1/token?grant_type=password" -Headers $base `
         -ContentType "application/json" -Body $body
  return $r
}
function Api($token, $method, $path, $body) {
  $h = @{ apikey = $PublishableKey; Authorization = "Bearer $token"; Prefer = "return=representation" }
  if ($body) {
    return Invoke-RestMethod -Method $method -Uri "$Url/rest/v1/$path" -Headers $h -ContentType "application/json" -Body $body
  }
  return Invoke-RestMethod -Method $method -Uri "$Url/rest/v1/$path" -Headers $h
}

$expect = @{ operator1 = "operator"; driver1 = "driver"; admin = "admin" }
foreach ($user in "operator1", "driver1", "admin") {
  try {
    $s = SignIn $user
    $p = Api $s.access_token "Get" "profiles?select=full_name,role&id=eq.$($s.user.id)" $null
    if ($p.Count -eq 1 -and $p[0].role -eq $expect[$user]) { Ok "$user signs in as $($p[0].role) ($($p[0].full_name))" }
    else { Bad "$user signed in but profile/role is wrong: $($p | ConvertTo-Json -Compress)" }

    $challans = @(Api $s.access_token "Get" "challans?select=id,driver_id,payment_status" $null)
    if ($user -eq "driver1") {
      $others = @($challans | Where-Object { $_.driver_id -ne "00000000-0000-4000-b000-000000000001" })
      if ($challans.Count -gt 0 -and $others.Count -eq 0) { Ok "driver1 sees only his own $($challans.Count) jobs" }
      else { Bad "driver1 sees $($challans.Count) challans, $($others.Count) not his" }
    } else {
      if ($challans.Count -eq 40) { Ok "$user sees all 40 Bhakkar challans" } else { Bad "$user sees $($challans.Count) challans (expected 40)" }
    }

    # nobody can mark Paid: try it and expect a refusal (or zero rows changed)
    $target = @($challans | Where-Object { $_.payment_status -ne "paid" })[0]
    try {
      $changed = @(Api $s.access_token "Patch" "challans?id=eq.$($target.id)" '{"payment_status":"paid"}')
      if ($changed.Count -eq 0) { Ok "$user cannot mark a challan Paid (0 rows changed)" }
      else { Bad "$user MARKED A CHALLAN PAID - this must never happen" }
    } catch {
      Ok "$user cannot mark a challan Paid (refused: $([int]$_.Exception.Response.StatusCode))"
    }
  } catch {
    Bad "$user could not sign in: $($_.Exception.Message)"
  }
}

# ------------------------------------------------------------------ summary
Write-Host ""
if ($failed -eq 0) {
  Write-Host "ALL CHECKS PASSED. Start the office app with:" -ForegroundColor Green
  Write-Host "   cd apps\office"
  Write-Host "   flutter run -d windows --dart-define-from-file=env.json"
  Write-Host "   (sign in as operator1 / Wasa@1234 - you should land on the Dashboard)"
} else {
  Write-Host "$failed CHECK(S) FAILED - copy the output above and send it to Claude." -ForegroundColor Red
  exit 1
}
