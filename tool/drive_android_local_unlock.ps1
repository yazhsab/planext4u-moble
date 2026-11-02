param(
 [Parameter(Mandatory=$true)][string]$Adb,
 [Parameter(Mandatory=$true)][string]$LogFile,
 [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
 [ValidatePattern('^emulator-[0-9]+$')][string]$Device='emulator-5554',
 [ValidatePattern('^[0-9]{4}$')][string]$TestPin='2580'
)
$ErrorActionPreference='Stop'
function Assert-TestAVD {
 $name=@(& $Adb -s $Device emu avd name 2>$null)
 if($LASTEXITCODE -ne 0 -or $name.Count -lt 1 -or $name[0].Trim() -ne 'planext4u-phase2-api35'){throw 'Only the dedicated synthetic AVD may be operated.'}
}
Assert-TestAVD
$repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot));$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(-not $evidence.StartsWith($repo+'\build\',[StringComparison]::OrdinalIgnoreCase)){throw 'Evidence must remain in the mobile build directory.'}
$report=[ordered]@{check_id='native-local-device-unlock';result='IN_PROGRESS';checks=@();external_provider_verified=$false;fingerprint_hardware_verified=$false}
function Log-Text {if(Test-Path -LiteralPath $LogFile){return [string](Get-Content -LiteralPath $LogFile -Raw)};return ''}
function Wait-Marker([string]$marker,[int]$Seconds=600) {
 $deadline=[DateTimeOffset]::UtcNow.AddSeconds($Seconds)
 do {
  [string]$log=Log-Text
  if(-not [string]::IsNullOrEmpty($log) -and $log.Contains($marker)){return}
  if($marker -eq 'LOCAL_UNLOCK_ONE_SCREEN_OWNER'){Ensure-Initial-Keyguard}
  if($log -match 'Some tests failed|Test failed|FAILURE:'){throw "Native test failed before $marker"}
  if([DateTimeOffset]::UtcNow -ge $deadline){throw "Native checkpoint missing: $marker"}
  Start-Sleep -Milliseconds 500
 }while($true)
}
function Save-Report {[IO.File]::WriteAllText((Join-Path $evidence 'local-unlock-ui.json'),($report|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))}
function Check([string]$id){$report.checks+=@{id=$id;result='PASSED'};Save-Report}
function Window-Text {return (@(& $Adb -s $Device shell dumpsys window) -join "`n")}
function Assert-Privacy([bool]$expected,[string]$stage) {
 Assert-TestAVD
 $text=Window-Text
 [IO.File]::WriteAllText((Join-Path $evidence "$stage-window.private.txt"),$text,[Text.UTF8Encoding]::new($false))
 $windows=[regex]::Split($text,'(?m)(?=^\s*Window #\d+ Window\{)')
 $owned=@($windows|Where-Object {$_ -match '^\s*Window #\d+ Window\{[^\r\n]*net\.planext4u\.customer\.dev/[^\r\n]*MainActivity' -and $_ -match 'mAttrs='})
 if($owned.Count -ne 1){throw 'The owned app window could not be identified for screen privacy.'}
 $secure=$owned[0] -match '(?m)\bSECURE\b'
 if($secure -ne $expected){throw "Unexpected native screen privacy during $stage"}
 Check "native-screen-privacy-$stage"
}
function Tap-Node($node){
 Assert-TestAVD
 if($node.bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$'){throw 'Native control has no usable bounds.'}
 $x=[int](([int]$Matches[1]+[int]$Matches[3])/2);$y=[int](([int]$Matches[2]+[int]$Matches[4])/2)
 & $Adb -s $Device shell input tap $x $y|Out-Null
 if($LASTEXITCODE -ne 0){throw 'Native control could not be selected.'}
}
$script:initialKeyguardAttempted=$false
function Ensure-Initial-Keyguard {
 if($script:initialKeyguardAttempted){return}
 Assert-TestAVD
 $window=Window-Text
 if($window -notmatch 'mDreamingLockscreen=true' -or
    $window -notmatch '(?m)mCurrentFocus=Window\{[^\r\n]*NotificationShade' -or
    $window -notmatch '(?m)mFocusedApp=[^\r\n]*net\.planext4u\.customer\.dev/'){return}
 $script:initialKeyguardAttempted=$true
 & $Adb -s $Device shell input keyevent 82|Out-Null
 $path='/sdcard/planext4u-unlock-initial-'+[Guid]::NewGuid().ToString('N')+'.xml'
 & $Adb -s $Device shell uiautomator dump $path *> (Join-Path $evidence 'initial-keyguard-dump.private.log')
 $raw=@(& $Adb -s $Device shell cat $path) -join "`n"
 if($raw -notlike '*<hierarchy*'){throw 'Initial synthetic keyguard hierarchy unavailable.'}
 [IO.File]::WriteAllText((Join-Path $evidence 'initial-keyguard.private.xml'),$raw,[Text.UTF8Encoding]::new($false))
 [xml]$tree=$raw
 foreach($digit in $TestPin.ToCharArray()){
  $node=@($tree.SelectNodes('//node')|Where-Object {$_.package -eq 'com.android.systemui' -and $_.'resource-id' -eq "com.android.systemui:id/key$digit"})
  if($node.Count -ne 1){throw 'Known synthetic keyguard digit control unavailable.'};Tap-Node $node[0]
 }
 $enter=@($tree.SelectNodes('//node')|Where-Object {$_.package -eq 'com.android.systemui' -and $_.'resource-id' -eq 'com.android.systemui:id/key_enter'})
 if($enter.Count -ne 1){throw 'Known synthetic keyguard confirmation unavailable.'};Tap-Node $enter[0]
 $deadline=[DateTimeOffset]::UtcNow.AddSeconds(20)
 do {
  if((Window-Text) -match 'mDreamingLockscreen=false'){break}
  if([DateTimeOffset]::UtcNow -ge $deadline){throw 'Initial synthetic keyguard did not unlock.'}
  Start-Sleep -Milliseconds 500
 }while($true)
 $report.initial_keyguard_setup='Observed System UI controls; temporary synthetic PIN; after verified app launch'
 Save-Report
}
function Credential-UI([string]$stage) {
 $deadline=[DateTimeOffset]::UtcNow.AddSeconds(60)
 do {
  Assert-TestAVD
  $focus=([regex]::Matches((Window-Text),'(?m)^\s*(mCurrentFocus|mFocusedApp)=[^\r\n]*')|ForEach-Object {$_.Value}) -join ' '
  if($focus -match 'Application Not Responding:'){throw 'Android UI is not responding.'}
  $path='/sdcard/planext4u-unlock-'+[Guid]::NewGuid().ToString('N')+'.xml'
  & $Adb -s $Device shell uiautomator dump $path *> (Join-Path $evidence 'unlock-dump.private.log')
  $raw=@(& $Adb -s $Device shell cat $path) -join "`n"
  [IO.File]::WriteAllText((Join-Path $evidence "$stage-last-ui.private.xml"),$raw,[Text.UTF8Encoding]::new($false))
  if($raw -like '*<hierarchy*'){
   [xml]$tree=$raw
   $nodes=@($tree.SelectNodes('//node')|Where-Object {$_.package -match '^(com\.android\.systemui|com\.android\.settings|android)$'})
   $pin=@($nodes|Where-Object {$_.enabled -eq 'true' -and ($_.class -eq 'android.widget.EditText' -or $_.'resource-id' -match '/(pinEntry|passwordEntry|lockPassword)$')})
   if($pin.Count -gt 0){
    [IO.File]::WriteAllText((Join-Path $evidence "$stage-credential.private.xml"),$raw,[Text.UTF8Encoding]::new($false))
    return $pin[0]
   }
   $fallback=@($nodes|Where-Object {$_.clickable -eq 'true' -and $_.enabled -eq 'true' -and $_.text -match '(?i)^Use (PIN|screen lock|password|device credential)$'})
   if($fallback.Count -eq 1){Tap-Node $fallback[0]}
  }
  # Android 15 may redact the credential hierarchy. Keyboard input is allowed
  # only when the actual focused System UI BiometricPrompt belongs to this app.
  $window=Window-Text
  if($window -match '(?m)mCurrentFocus=Window\{[^\r\n]*\bBiometricPrompt\}' -and
     $window -match '(?m)mFocusedApp=[^\r\n]*net\.planext4u\.customer\.dev/' -and
     $window -match 'mOwnerUid=\d+[^\r\n]*package=com\.android\.systemui'){
    [IO.File]::WriteAllText((Join-Path $evidence "$stage-focused-credential-window.private.txt"),$window,[Text.UTF8Encoding]::new($false))
    return @{keyboardOnly=$true}
  }
  if([DateTimeOffset]::UtcNow -ge $deadline){throw "Actual Android device credential UI did not appear during $stage"}
  Start-Sleep -Milliseconds 500
 }while($true)
}
try {
 Save-Report
 Wait-Marker 'LOCAL_UNLOCK_ONE_SCREEN_OWNER';Assert-Privacy $true 'one-owner'
 if(([string](Log-Text)).Contains('LOCAL_UNLOCK_NO_SCREEN_OWNERS')){throw 'Screen owner observation arrived after its native phase ended.'}
 Wait-Marker 'LOCAL_UNLOCK_NO_SCREEN_OWNERS';Assert-Privacy $false 'no-owners'
 if(([string](Log-Text)).Contains('LOCAL_UNLOCK_ENABLE_REQUEST')){throw 'Released owner observation arrived after the next phase started.'}
 foreach($stage in @('ENABLE','CANCEL','SUCCESS')){
  Wait-Marker "LOCAL_UNLOCK_${stage}_REQUEST" 90
  $credentialControl=Credential-UI $stage
  if($stage -eq 'ENABLE'){Assert-Privacy $true 'enabled-challenge'}
  if($stage -eq 'CANCEL'){
   for($back=0;$back -lt 5;$back++){
    Assert-TestAVD
    & $Adb -s $Device shell input keyevent 4|Out-Null
    Start-Sleep -Milliseconds 500
    $focus=Window-Text
    if($focus -notmatch '(?m)mCurrentFocus=[^\r\n]*(BiometricPrompt|(com\.android\.systemui|com\.android\.settings)/)'){break}
   }
  }else{
   # The IME changes credential bounds after the snapshot. Do not tap a
   # field that Android already reports focused using stale pre-IME bounds.
   if(-not $credentialControl.keyboardOnly -and $credentialControl.focused -ne 'true'){Tap-Node $credentialControl}
   Start-Sleep -Milliseconds 350
   & $Adb -s $Device shell input text $TestPin|Out-Null
   if($LASTEXITCODE -ne 0){throw 'Synthetic device credential could not be entered.'}
   & $Adb -s $Device shell input keyevent 66|Out-Null
  }
  Wait-Marker "LOCAL_UNLOCK_${stage}_CONFIRMED" 90
  Check "actual-device-credential-$($stage.ToLowerInvariant())"
 }
 Wait-Marker 'LOCAL_UNLOCK_BACKGROUND_REQUEST';Assert-TestAVD
 $focus=Window-Text
 if($focus -notmatch '(?m)mFocusedApp=[^\r\n]*net\.planext4u\.customer\.dev/'){throw 'The owned synthetic app is not foreground before the background drill.'}
 & $Adb -s $Device shell input keyevent 3|Out-Null
 $backgroundDeadline=[DateTimeOffset]::UtcNow.AddSeconds(30)
 do {
  Assert-TestAVD
  $activities=@(& $Adb -s $Device shell dumpsys activity activities) -join "`n"
  [IO.File]::WriteAllText((Join-Path $evidence 'background-activities.private.txt'),$activities,[Text.UTF8Encoding]::new($false))
  $records=[regex]::Split($activities,'(?m)(?=^\s*\* Hist\s+#\d+:\s+ActivityRecord\{)')
  $stopped=@($records|Where-Object {$_ -match '^\s*\* Hist\s+#\d+:\s+ActivityRecord\{[^\r\n]*net\.planext4u\.customer\.dev/[^\r\n]*MainActivity' -and $_ -match '\bstate=STOPPED\b'})
  if($stopped.Count -eq 1){break}
  if([DateTimeOffset]::UtcNow -ge $backgroundDeadline){throw 'The owned activity did not reach actual STOPPED state before returning.'}
  Start-Sleep -Milliseconds 500
 }while($true)
 $report.actual_background_state='STOPPED'
 & $Adb -s $Device shell am start -n net.planext4u.customer.dev/net.planext4u.customer.MainActivity *> (Join-Path $evidence 'unlock-resume.private.log')
 if($LASTEXITCODE -ne 0){throw 'The owned app could not be resumed.'}
 Wait-Marker 'LOCAL_UNLOCK_BACKGROUND_CONFIRMED';Check 'actual-background-return-relocks'
 Wait-Marker 'NATIVE_LOCAL_UNLOCK_CONFIRMED';Check 'native-secure-settings-independent-controller-restart'
 $report.result='PASSED'
}catch{
 $report.result='FAILED';$report.failure=$_.Exception.Message
 try{[IO.File]::WriteAllText((Join-Path $evidence 'failure-window.private.txt'),(Window-Text),[Text.UTF8Encoding]::new($false))}catch{}
 throw
}finally{$report.updated_at=[DateTimeOffset]::UtcNow.ToString('o');Save-Report}
