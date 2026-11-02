param(
  [Parameter(Mandatory=$true)][string]$Adb,
  [Parameter(Mandatory=$true)][string]$LogFile,
  [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
  [ValidatePattern('^emulator-[0-9]+$')][string]$Device='emulator-5554'
)
$ErrorActionPreference='Stop'
function Assert-TestAVD {
  $name=@(& $Adb -s $Device emu avd name 2>$null)
  if($LASTEXITCODE -ne 0 -or $name.Count -lt 1 -or $name[0].Trim() -ne 'planext4u-phase2-api35'){throw 'Only the dedicated synthetic AVD may be operated.'}
}
Assert-TestAVD
$repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(-not $evidence.StartsWith($repo+'\build\',[StringComparison]::OrdinalIgnoreCase)){throw 'Evidence must stay within the mobile build directory.'}
$report=[ordered]@{check_id='android-device-access';result='IN_PROGRESS';device=$Device;checks=@();external_provider_verified=$false}
$reportPath=Join-Path $evidence 'device-access-ui.json'
function Save-Report { [IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false)) }
function Wait-Marker([string]$marker) {
  $deadline=[DateTimeOffset]::UtcNow.AddMinutes(10)
  do {
    [string]$log=''
    if(Test-Path -LiteralPath $LogFile){$log=[string](Get-Content -LiteralPath $LogFile -Raw)}
    if(-not [string]::IsNullOrEmpty($log) -and $log.Contains($marker)){return}
    if($log -match 'Some tests failed|Test failed|FAILURE:'){throw "Native test failed before $marker"}
    if([DateTimeOffset]::UtcNow -ge $deadline){throw "Native checkpoint missing: $marker"}
    Start-Sleep -Seconds 1
  }while($true)
}
$oldLocationMode=$null
try {
  Save-Report
  foreach($choice in @('DENY','ALLOW')) {
    Wait-Marker "DEVICE_ACCESS_CAMERA_${choice}_REQUEST"
    $deadline=[DateTimeOffset]::UtcNow.AddSeconds(45)
    do {
      Assert-TestAVD
      $focus=(@(& $Adb -s $Device shell dumpsys window)|Select-String 'mCurrentFocus|mFocusedApp') -join ' '
      if($focus -match 'Application Not Responding:'){throw 'Android UI is not responding.'}
      if($focus -notmatch 'permissioncontroller'){Start-Sleep -Milliseconds 500;continue}
      $path='/sdcard/planext4u-permission-'+[Guid]::NewGuid().ToString('N')+'.xml'
      & $Adb -s $Device shell uiautomator dump $path *> (Join-Path $evidence 'device-access-dump.private.log')
      $raw=@(& $Adb -s $Device shell cat $path) -join "`n"
      if($raw -notlike '*<hierarchy*'){continue}
      [xml]$tree=$raw
      $suffix=if($choice -eq 'DENY'){'/permission_deny_button$'}else{'/permission_allow_foreground_only_button$|/permission_allow_one_time_button$|/permission_allow_button$'}
      $nodes=@($tree.SelectNodes('//node')|Where-Object {$_.package -match '^com\.(google\.android|android)\.permissioncontroller$' -and $_.'resource-id' -match $suffix -and $_.enabled -eq 'true' -and $_.clickable -eq 'true'})
      if($choice -eq 'ALLOW' -and $nodes.Count -gt 1){$nodes=@($nodes|Where-Object {$_.'resource-id' -match '/permission_allow_foreground_only_button$'})}
      if($nodes.Count -eq 1 -and $nodes[0].bounds -match '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$'){
        $x=[int](([int]$Matches[1]+[int]$Matches[3])/2);$y=[int](([int]$Matches[2]+[int]$Matches[4])/2)
        [IO.File]::WriteAllText((Join-Path $evidence "camera-$($choice.ToLowerInvariant()).private.xml"),$raw,[Text.UTF8Encoding]::new($false))
        & $Adb -s $Device shell input tap $x $y|Out-Null
        if($LASTEXITCODE -ne 0){throw 'Could not select the Android permission choice.'}
        break
      }
      if([DateTimeOffset]::UtcNow -ge $deadline){throw 'Expected actual Android permission control was not available.'}
    }while([DateTimeOffset]::UtcNow -lt $deadline)
    Wait-Marker "DEVICE_ACCESS_CAMERA_${choice}_CONFIRMED"
    $report.checks+=@{id="actual-camera-$($choice.ToLowerInvariant())-and-fresh-read";result='PASSED'};Save-Report
  }
  Wait-Marker 'DEVICE_ACCESS_LOCATION_SETTINGS_REQUEST'
  $deadline=[DateTimeOffset]::UtcNow.AddSeconds(45)
  do {
    Assert-TestAVD
    $focus=(@(& $Adb -s $Device shell dumpsys window)|Select-String 'mFocusedApp') -join ' '
    if($focus -match 'com\.android\.settings/'){break}
    if([DateTimeOffset]::UtcNow -ge $deadline){throw 'Actual Android location settings did not open.'}
    Start-Sleep -Milliseconds 500
  }while($true)
  $oldLocationMode=(@(& $Adb -s $Device shell settings get secure location_mode) -join '').Trim()
  if($oldLocationMode -notmatch '^[0-3]$'){throw 'Unexpected synthetic AVD location mode.'}
  if($oldLocationMode -eq '0'){throw 'The dedicated location test must begin with location services enabled.'}
  $report.location_mode_before=[int]$oldLocationMode
  & $Adb -s $Device shell settings put secure location_mode 0|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Could not turn off the synthetic AVD location service.'}
  for($back=0;$back -lt 6;$back++){
    Assert-TestAVD
    $focus=(@(& $Adb -s $Device shell dumpsys window)|Select-String 'mFocusedApp') -join ' '
    if($focus -notmatch 'com\.android\.settings/'){break}
    & $Adb -s $Device shell input keyevent 4|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Could not return from Android settings.'}
    Start-Sleep -Milliseconds 500
  }
  $focus=(@(& $Adb -s $Device shell dumpsys window)|Select-String 'mFocusedApp') -join ' '
  if($focus -notmatch 'net\.planext4u\.customer\.dev/'){throw 'Settings did not return to the owned synthetic app.'}
  Wait-Marker 'DEVICE_ACCESS_LOCATION_SETTINGS_RETURN_CONFIRMED'
  $report.checks+=@{id='actual-system-settings-open-service-change-return-reread';result='PASSED'}
  Assert-TestAVD
  $screen='/sdcard/planext4u-device-access-'+[Guid]::NewGuid().ToString('N')+'.png'
  & $Adb -s $Device shell screencap -p $screen|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Could not capture the returned permission screen.'}
  & $Adb -s $Device pull $screen (Join-Path $evidence 'device-permissions.png') *> $null
  if($LASTEXITCODE -ne 0){throw 'Could not retain the native permission screenshot.'}
  $report.screenshot_sha256=(Get-FileHash -LiteralPath (Join-Path $evidence 'device-permissions.png')).Hash.ToLowerInvariant()
  Wait-Marker 'NATIVE_DEVICE_ACCESS_CONFIRMED'
  $report.result='PASSED'
}catch{$report.result='FAILED';$report.failure=$_.Exception.Message;throw}
finally{
  if($null -ne $oldLocationMode){Assert-TestAVD;& $Adb -s $Device shell settings put secure location_mode $oldLocationMode|Out-Null}
  $report.updated_at=[DateTimeOffset]::UtcNow.ToString('o');Save-Report
}
