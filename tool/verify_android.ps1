param(
  [Parameter(Mandatory = $true)][string]$FlutterSdk,
  [Parameter(Mandatory = $true)][string]$JavaHome,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [string]$GradleUserHome,
  [ValidatePattern('^[a-z0-9-]+$')][string]$EvidenceDirectoryName = 'phase0-android',
  [ValidatePattern('^[A-Z]{2}$')][string]$CountryCode = 'IN',
  [ValidateSet('customer','vendor','rider')][string[]]$Apps = @('customer','vendor','rider'),
  [ValidateSet('development','staging','production')][string[]]$Flavors = @('development','staging','production')
)

# Local debug build evidence only. No emulator, provider activation, release
# signing, publication or remote deployment is performed by this command.
$repository = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repository ('build\'+$EvidenceDirectoryName)
$flutterCommand = Join-Path $FlutterSdk 'bin\flutter.bat'
$analyzerCommand = Join-Path $AndroidSdk 'cmdline-tools\latest\bin\apkanalyzer.bat'
foreach ($requiredFile in @($flutterCommand, $analyzerCommand, (Join-Path $JavaHome 'bin\java.exe'))) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "Required build tool is unavailable: $requiredFile" }
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
if (-not $GradleUserHome) { $GradleUserHome = Join-Path $repository 'build\phase0-gradle' }
$previousEnvironment = @{}
foreach ($key in @('JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','GRADLE_USER_HOME','PATH')) {
  $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
$report = [ordered]@{check_id='android-build-matrix'; result='IN_PROGRESS'; complete_all_nine=$false; country_code=$CountryCode; source_revision=''; source_fingerprint=''; results=@()}
function Save-BuildReport {
  $report.updated_at = [DateTimeOffset]::UtcNow.ToString('o')
  [IO.File]::WriteAllText((Join-Path $outputDirectory 'report.json'), ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}
function Get-MobileSourceFingerprint {
  $files = & git -C $repository ls-files -c -o --exclude-standard -- apps packages pubspec.yaml pubspec.lock tool
  if ($LASTEXITCODE -ne 0) { throw 'Cannot fingerprint the mobile source files.' }
  $fingerprint = (($files | Sort-Object -Unique | ForEach-Object { $_+':'+(Get-FileHash -LiteralPath (Join-Path $repository $_) -Algorithm SHA256).Hash }) -join "`n")
  $digest = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint))).Replace('-','').ToLowerInvariant() }
  finally { $digest.Dispose() }
}
try {
  $env:JAVA_HOME = $JavaHome
  $env:ANDROID_HOME = $AndroidSdk
  $env:ANDROID_SDK_ROOT = $AndroidSdk
  $env:GRADLE_USER_HOME = $GradleUserHome
  $env:PATH = (Join-Path $FlutterSdk 'bin')+';'+(Join-Path $JavaHome 'bin')+';'+$env:PATH
  Push-Location $repository
  try {
    $report.source_revision = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the mobile source revision.' }
    $report.source_fingerprint = Get-MobileSourceFingerprint
  } finally { Pop-Location }
  $urls = @{development='http://10.0.2.2:8082'; staging='https://staging-api.planext4u.net'; production='https://api.planext4u.net'}
  foreach ($app in ($Apps | Select-Object -Unique)) {
    foreach ($flavor in ($Flavors | Select-Object -Unique)) {
      $log = Join-Path $outputDirectory "$app-$flavor.log"
      $entry = [ordered]@{app=$app; flavor=$flavor; started_at=[DateTimeOffset]::UtcNow.ToString('o'); result='IN_PROGRESS'; log=$log}
      $report.results += $entry
      Save-BuildReport
      Write-Output "Building $app / $flavor debug APK"
      Push-Location (Join-Path $repository "apps\$app")
      try {
        & $flutterCommand build apk --debug --no-pub --flavor $flavor "--dart-define=APP_ENV=$flavor" "--dart-define=API_BASE_URL=$($urls[$flavor])" "--dart-define=DEFAULT_COUNTRY_CODE=$CountryCode" *> $log
        $entry.exit_code = $LASTEXITCODE
      } finally { Pop-Location }
      $entry.completed_at = [DateTimeOffset]::UtcNow.ToString('o')
      if ($entry.exit_code -ne 0) { $entry.result='FAILED'; throw "Android build failed: $app/$flavor. See $log" }
      $artifact = Join-Path $repository "apps\$app\build\app\outputs\flutter-apk\app-$flavor-debug.apk"
      if (-not (Test-Path -LiteralPath $artifact -PathType Leaf) -or (Get-Item -LiteralPath $artifact).Length -eq 0) { $entry.result='FAILED'; throw 'Expected APK is missing or empty.' }
      $manifest = & $analyzerCommand manifest application-id $artifact 2>> $log
      $analysisExit = $LASTEXITCODE
      $applicationID = @($manifest | Where-Object { $_ -match '^net\.planext4u\.' })
      $suffix = if ($flavor -eq 'development') { '.dev' } elseif ($flavor -eq 'staging') { '.staging' } else { '' }
      if ($analysisExit -ne 0 -or $applicationID.Count -ne 1 -or $applicationID[0].Trim() -ne "net.planext4u.$app$suffix") { $entry.result='FAILED'; throw 'APK manifest application ID does not match the requested app/flavor.' }
      $entry.application_id = $applicationID[0].Trim()
      $entry.artifact = $artifact
      $entry.bytes = (Get-Item -LiteralPath $artifact).Length
      $entry.sha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
      $entry.result = 'PASSED'
      Save-BuildReport
      Write-Output "Passed $app / $flavor; manifest verified."
    }
  }
  $report.source_fingerprint_after = Get-MobileSourceFingerprint
  $report.source_unchanged = $report.source_fingerprint -eq $report.source_fingerprint_after
  if (-not $report.source_unchanged) { throw 'Mobile sources changed during the build matrix. Rebuild stable sources before accepting this receipt.' }
  $report.result = 'PASSED'
  $report.complete_all_nine = $report.results.Count -eq 9
  Save-BuildReport
  Write-Output "Android build report: $(Join-Path $outputDirectory 'report.json')"
} catch {
  $report.result = 'FAILED'
  Save-BuildReport
  throw
} finally {
  foreach ($key in $previousEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $previousEnvironment[$key], 'Process') }
}
