param(
  [Parameter(Mandatory = $true)][string]$FlutterSdk,
  [Parameter(Mandatory = $true)][string]$JavaHome,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [Parameter(Mandatory = $true)][string]$GradleUserHome,
  [ValidateSet('customer','vendor','rider')][string[]]$Apps = @('customer','vendor','rider'),
  [ValidatePattern('^emulator-[0-9]+$')][string]$Device = 'emulator-5554',
  [switch]$VerifyPortableExport,
  [ValidatePattern('^[a-z0-9-]+$')][string]$EvidenceDirectoryName = 'phase2-local-android'
)

# This harness only uses the dedicated synthetic AVD. It never clears a physical
# device or another developer's emulator. Firebase/provider UAT is separate.
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repository ('build\'+$EvidenceDirectoryName)
$adb = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$flutter = Join-Path $FlutterSdk 'bin\flutter.bat'
foreach ($required in @($adb, $flutter, (Join-Path $JavaHome 'bin\java.exe'))) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required tool is unavailable: $required" }
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$report = [ordered]@{check_id='android-local-foundations'; result='IN_PROGRESS'; device=$Device; avd='planext4u-phase2-api35'; external_provider_verified=$false; results=@()}
function Save-Report {
  $report.updated_at = [DateTimeOffset]::UtcNow.ToString('o')
  [IO.File]::WriteAllText((Join-Path $outputDirectory 'report.json'), ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}
function Source-Fingerprint {
  $files = & git -C $repository ls-files -c -o --exclude-standard -- apps packages pubspec.yaml pubspec.lock tool
  if ($LASTEXITCODE -ne 0) { throw 'Cannot fingerprint the mobile sources.' }
  $contents = (($files | Sort-Object -Unique | ForEach-Object { $_+':'+(Get-FileHash -LiteralPath (Join-Path $repository $_) -Algorithm SHA256).Hash }) -join "`n")
  $digest = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($contents))).Replace('-','').ToLowerInvariant() }
  finally { $digest.Dispose() }
}
function Quote-WorkerArgument([string]$value) { return "'"+$value.Replace("'","''")+"'" }
$previous = @{}
$addedObjectReverse = $false
foreach ($key in @('JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','GRADLE_USER_HOME','GRADLE_OPTS','PATH')) { $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
try {
  $name = @(& $adb -s $Device emu avd name 2>$null)
  if ($LASTEXITCODE -ne 0 -or $name.Count -lt 1 -or $name[0].Trim() -ne $report.avd) { throw 'Only the dedicated Planext4u test AVD is permitted.' }
  $deadline = [DateTimeOffset]::UtcNow.AddMinutes(5)
  do {
    $boot = @(& $adb -s $Device shell getprop sys.boot_completed 2>$null)
    if ($LASTEXITCODE -eq 0 -and $boot.Count -gt 0 -and $boot[0].Trim() -eq '1') { break }
    if ([DateTimeOffset]::UtcNow -ge $deadline) { throw 'Dedicated Android AVD did not finish booting.' }
    Start-Sleep -Seconds 2
  } while ($true)
  $ready = Invoke-WebRequest 'http://127.0.0.1:8082/readyz' -UseBasicParsing -TimeoutSec 10
  if ($ready.StatusCode -ne 200) { throw 'The local gateway must be healthy before native journeys.' }
  $objectReverse = @(& $adb -s $Device reverse --list) | Where-Object { $_ -match '\s+tcp:9000\s+' }
  if ($objectReverse.Count -gt 0 -and $objectReverse[0] -notmatch '\s+tcp:9000\s+tcp:9000$') { throw 'The dedicated AVD has an unexpected object-store reverse mapping.' }
  if ($objectReverse.Count -eq 0) {
    & $adb -s $Device reverse tcp:9000 tcp:9000 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'The dedicated AVD cannot reach the local signed object-store origin.' }
    $addedObjectReverse = $true
  }
  $env:JAVA_HOME=$JavaHome
  $env:ANDROID_HOME=$AndroidSdk
  $env:ANDROID_SDK_ROOT=$AndroidSdk
  $env:GRADLE_USER_HOME=$GradleUserHome
  $env:GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.daemon=false'
  $env:PATH=(Join-Path $FlutterSdk 'bin')+';'+(Join-Path $JavaHome 'bin')+';'+$env:PATH
  $report.source_fingerprint=Source-Fingerprint
  foreach ($app in ($Apps | Select-Object -Unique)) {
    $package = "net.planext4u.$app.dev"
    $installed = @(& $adb -s $Device shell pm path $package)
    if ($installed.Count -gt 0 -and $installed[0].StartsWith('package:')) {
      $cleared = @(& $adb -s $Device shell pm clear $package)
      if ($LASTEXITCODE -ne 0 -or $cleared[0].Trim() -ne 'Success') { throw 'Cannot reset the dedicated synthetic development application.' }
    }
    $entry = [ordered]@{app=$app; started_at=[DateTimeOffset]::UtcNow.ToString('o'); result='IN_PROGRESS'; log="$app.log"}
    $report.results += $entry
    Save-Report
    Write-Output "Running normal Android $app startup against the local API"
    $pickerProcess=$null
    if($VerifyPortableExport){
      $nativeLog=Join-Path $outputDirectory $entry.log
      [IO.File]::WriteAllText($nativeLog,'',[Text.UTF8Encoding]::new($false))
      $pickerProcess=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-File',('"'+(Join-Path $PSScriptRoot 'drive_android_export_picker.ps1')+'"'),'-Adb',('"'+$adb+'"'),'-Device',$Device,'-Role',$app,'-LogFile',('"'+$nativeLog+'"'),'-EvidenceDirectory',('"'+$outputDirectory+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outputDirectory "$app-picker.out.log") -RedirectStandardError (Join-Path $outputDirectory "$app-picker.err.log")
    }
    Push-Location (Join-Path $repository "apps\$app")
    $flutterProcess=$null
    try {
      $nativeLog=Join-Path $outputDirectory $entry.log
      $worker=Join-Path $outputDirectory "$app-worker.ps1"
      $arguments=@('test','--no-pub','integration_test/local_foundation_test.dart','-d',$Device,'--flavor','development','--dart-define=APP_ENV=development','--dart-define=API_BASE_URL=http://10.0.2.2:8082',"--dart-define=VERIFY_PORTABLE_EXPORT=$($VerifyPortableExport.IsPresent.ToString().ToLowerInvariant())",'--reporter','expanded')
      $workerLines=@('$ErrorActionPreference = ''Stop''',('Set-Location -LiteralPath '+(Quote-WorkerArgument (Get-Location).Path)),('& '+(Quote-WorkerArgument $flutter)+' '+(($arguments|ForEach-Object {Quote-WorkerArgument $_}) -join ' ')+' *> '+(Quote-WorkerArgument $nativeLog)),'exit $LASTEXITCODE')
      [IO.File]::WriteAllText($worker,($workerLines -join "`n"),[Text.UTF8Encoding]::new($false))
      $flutterProcess=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-File',('"'+$worker+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outputDirectory "$app-worker.out.log") -RedirectStandardError (Join-Path $outputDirectory "$app-worker.err.log")
      $runDeadline=[DateTimeOffset]::UtcNow.AddMinutes(10)
      while(-not $flutterProcess.WaitForExit(1000)){
        if($pickerProcess -and $pickerProcess.HasExited -and $pickerProcess.ExitCode -ne 0){throw 'The native picker helper failed; the owned Flutter worker is stopped immediately.'}
        if([DateTimeOffset]::UtcNow -ge $runDeadline){throw 'The native role journey exceeded its bounded run budget.'}
      }
      $entry.exit_code=$flutterProcess.ExitCode
      if($VerifyPortableExport -and $entry.exit_code -eq 0){
        if(-not $pickerProcess.WaitForExit(10000)){throw 'Native picker evidence did not finish.'}
        $pickerProof=Get-Content (Join-Path $outputDirectory "$app-picker.json") -Raw | ConvertFrom-Json
        if($pickerProcess.ExitCode -ne 0 -or $pickerProof.result -ne 'PASSED'){throw 'Native picker/readback evidence failed.'}
        $entry.portable_export='PASSED'
        $entry.picker_receipt="$app-picker.json"
      }
    } finally {
      Pop-Location
      if($flutterProcess -and -not $flutterProcess.HasExited){$flutterProcess.Kill($true);$flutterProcess.WaitForExit()}
      if($pickerProcess -and -not $pickerProcess.HasExited){$pickerProcess.Kill($true);$pickerProcess.WaitForExit()}
    }
    $entry.completed_at=[DateTimeOffset]::UtcNow.ToString('o')
    $entry.log_sha256=(Get-FileHash -LiteralPath (Join-Path $outputDirectory $entry.log) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($entry.exit_code -ne 0) { $entry.result='FAILED'; throw "Android $app foundation journey failed; inspect its log." }
    $entry.result='PASSED'
    Save-Report
  }
  $report.source_fingerprint_after=Source-Fingerprint
  $report.source_unchanged=$report.source_fingerprint -eq $report.source_fingerprint_after
  if (-not $report.source_unchanged) { throw 'Mobile sources changed during native verification; rerun stable sources.' }
  $report.result='PASSED'
  $report.note='Real native startup, versioned first-run storage, local synthetic provider login, live profile/session reads and logout/relogin. Vendor exercises native private upload/document submission; rider exercises the normal runtime uploader and four-document collector with real S3/ClamAV and synthetic images. All roles verify secure consent denial readback and independent controller recreation across logout/relogin. Camera/OCR approval, external identity, push, bank, commerce and release signing remain separate acceptance work.'
  Save-Report
} catch {
  $report.result='FAILED'
  $report.failure=$_.Exception.Message
  Save-Report
  throw
} finally {
  if ($addedObjectReverse) { & $adb -s $Device reverse --remove tcp:9000 | Out-Null }
  foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
}
