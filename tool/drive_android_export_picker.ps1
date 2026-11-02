param(
  [Parameter(Mandatory=$true)][string]$Adb,
  [ValidatePattern('^emulator-[0-9]+$')][string]$Device='emulator-5554',
  [Parameter(Mandatory=$true)][ValidateSet('customer','vendor','rider')][string]$Role,
  [Parameter(Mandatory=$true)][string]$LogFile,
  [Parameter(Mandatory=$true)][string]$EvidenceDirectory
)

# Test-only automation. The exact dedicated AVD, role checkpoint and foreground
# Android DocumentsUI are all required before a key or tap can be sent.
$ErrorActionPreference='Stop'
$name=@(& $Adb -s $Device emu avd name 2>$null)
if($LASTEXITCODE -ne 0 -or $name.Count -lt 1 -or $name[0].Trim() -ne 'planext4u-phase2-api35'){throw 'Only the dedicated synthetic AVD may be automated.'}
$repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
if(-not $evidence.StartsWith($repo+'\build\',[StringComparison]::OrdinalIgnoreCase)){throw 'Picker evidence must stay in the mobile build directory.'}
$report=[ordered]@{check_id='native-document-picker';role=$Role;result='IN_PROGRESS';device=$Device;checks=@()}
$reportPath=Join-Path $evidence "$Role-picker.json"
function Save-PickerReport { [IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false)) }
function Save-PickerObservation($value) { [IO.File]::WriteAllText((Join-Path $evidence "$Role-picker-observation.private.json"),($value|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false)) }
function Assert-TestAVD {
  $current=@(& $Adb -s $Device emu avd name 2>$null)
  if($LASTEXITCODE -ne 0 -or $current.Count -lt 1 -or $current[0].Trim() -ne 'planext4u-phase2-api35'){throw 'The dedicated synthetic AVD is no longer available.'}
}
function Tap-Node($node){
  Assert-TestAVD
  if($node.bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$'){throw 'Picker control has no usable bounds.'}
  $x=[int](([int]$Matches[1]+[int]$Matches[3])/2);$y=[int](([int]$Matches[2]+[int]$Matches[4])/2)
  & $Adb -s $Device shell input tap $x $y | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Picker control could not be selected.'}
}
try {
  Save-PickerReport
  foreach($mode in @('CANCEL','SAVE')){
    $deadline=[DateTimeOffset]::UtcNow.AddMinutes(10)
    $marker="ACCOUNT_EXPORT_PICKER_${mode} ${Role}"
    do {
      [string]$applicationLogText=''
      if(Test-Path -LiteralPath $LogFile){$applicationLogText=[string](Get-Content -LiteralPath $LogFile -Raw)}
      $hasCheckpoint=(-not [string]::IsNullOrEmpty($applicationLogText)) -and $applicationLogText.Contains($marker)
      Save-PickerObservation @{mode=$mode;stage='checkpoint';has_checkpoint=$hasCheckpoint;characters=$applicationLogText.Length;log_path=$LogFile;expected_marker=$marker;observed_at=[DateTimeOffset]::UtcNow.ToString('o')}
      if($hasCheckpoint){break}
      if([DateTimeOffset]::UtcNow -ge $deadline){throw "The application did not request the $mode picker."}
      Start-Sleep -Seconds 2
    }while($true)
    $pickerDeadline=[DateTimeOffset]::UtcNow.AddSeconds(30)
    $fileName=$null
    :PickerWindow do {
      if([DateTimeOffset]::UtcNow -ge $deadline){throw "Timed out waiting for the guarded $mode document picker."}
      if([DateTimeOffset]::UtcNow -ge $pickerDeadline){throw 'The Android document picker did not become usable within the native test budget.'}
      $windowDump=@(& $Adb -s $Device shell dumpsys window 2>$null)
      $focus=($windowDump | Select-String 'mCurrentFocus') -join ' '
      $foreground=($windowDump | Select-String 'mFocusedApp') -join ' '
      Save-PickerObservation @{mode=$mode;stage='activity';focused_documents=($foreground -match 'com\.(google\.android|android)\.documentsui/');observed_at=[DateTimeOffset]::UtcNow.ToString('o')}
      if($focus -match 'Application Not Responding:'){throw 'The dedicated emulator System UI is not responding; restart the test environment before retrying.'}
      if($foreground -notmatch 'com\.(google\.android|android)\.documentsui/'){Start-Sleep -Seconds 1;continue PickerWindow}
      $dumpPath='/sdcard/planext4u-export-'+[Guid]::NewGuid().ToString('N')+'.xml'
      & $Adb -s $Device shell uiautomator dump $dumpPath *> (Join-Path $evidence "$Role-picker-dump.private.log")
      $dumpExit=$LASTEXITCODE
      $raw=(@(& $Adb -s $Device shell cat $dumpPath 2>$null) -join "`n")
      Save-PickerObservation @{mode=$mode;stage='dump';exit_code=$dumpExit;fresh_xml=($raw -like '*<hierarchy*');observed_at=[DateTimeOffset]::UtcNow.ToString('o')}
      # A unique destination prevents a previous window snapshot from being
      # mistaken for this one. Validate the actual new hierarchy and package.
      if($raw -notlike '*<hierarchy*'){Start-Sleep -Seconds 1;continue PickerWindow}
      [xml]$tree=$raw
      $nodes=@($tree.SelectNodes('//node'))
      $documentNodes=@($nodes | Where-Object { $_.package -match '^com\.(google\.android|android)\.documentsui$' })
      Save-PickerObservation @{mode=$mode;stage='nodes';exit_code=$dumpExit;document_nodes=$documentNodes.Count;observed_at=[DateTimeOffset]::UtcNow.ToString('o')}
      if($documentNodes.Count -eq 0){Start-Sleep -Seconds 1;continue PickerWindow}
      if($mode -eq 'CANCEL'){
        # Back first hides the keyboard or goes to a parent folder in
        # DocumentsUI. Keep checking its actual foreground activity; stop
        # immediately once the chooser closes, before any application input.
        for($back=0;$back -lt 6;$back++){
          $pickerFocus=(@(& $Adb -s $Device shell dumpsys window 2>$null)|Select-String 'mFocusedApp') -join ' '
          if($pickerFocus -notmatch 'com\.(google\.android|android)\.documentsui/'){break}
          Assert-TestAVD
          & $Adb -s $Device shell input keyevent 4 | Out-Null
          if($LASTEXITCODE -ne 0){throw 'Cannot cancel the document picker.'}
          Start-Sleep -Milliseconds 400
        }
        $pickerFocus=(@(& $Adb -s $Device shell dumpsys window 2>$null)|Select-String 'mFocusedApp') -join ' '
        if($pickerFocus -match 'com\.(google\.android|android)\.documentsui/'){throw 'DocumentsUI did not close after guarded cancellation.'}
      }else{
        # Existing exports in the folder share the same filename pattern. Read
        # only the actual editable destination, never a file-list title.
        $title=@($documentNodes | Where-Object { $_.class -eq 'android.widget.EditText' -and $_.text -match '^planext4u-account-\d{8}T\d{6}Z\.json$' })
        if($title.Count -ne 1){Start-Sleep -Seconds 1;continue PickerWindow}
        $fileName=[string]$title[0].text
        $save=@($documentNodes | Where-Object { $_.enabled -eq 'true' -and $_.clickable -eq 'true' -and ($_.'resource-id' -match '/action_menu_save$' -or $_.text -match '^(?i:save)$' -or $_.'content-desc' -match '^(?i:save)$') })
        if($save.Count -ne 1){Start-Sleep -Seconds 1;continue PickerWindow}
        Tap-Node $save[0]
      }
      break
    }while($true)
    $confirmed=[DateTimeOffset]::UtcNow.AddSeconds(60)
    do {
      $log=Get-Content -LiteralPath $LogFile -Raw
      if($log -match "ACCOUNT_EXPORT_${mode}_CONFIRMED $Role"){break}
      if([DateTimeOffset]::UtcNow -ge $confirmed){throw "Application did not confirm picker $mode."}
      Start-Sleep -Seconds 1
    }while($true)
    $report.checks+=@{id="system-picker-$($mode.ToLowerInvariant())";result='PASSED'}
    if($mode -eq 'SAVE'){
      $privateFile=Join-Path $evidence "$Role-account-export.private.json"
      & $Adb -s $Device pull "/sdcard/Download/$fileName" $privateFile *> $null
      if($LASTEXITCODE -ne 0){throw 'The saved document could not be read independently from Downloads.'}
      $json=Get-Content -LiteralPath $privateFile -Raw -Encoding utf8
      $value=$json|ConvertFrom-Json
      if($value.schema_version -ne 3 -or -not $value.identity_id -or $value.consent_history.Count -lt 1 -or $value.coverage.excluded.Count -lt 1 -or $null -eq $value.contact_snapshots -or $null -eq $value.deletion_history -or $value.coverage.included -notcontains 'identity.deletion_history' -or $value.coverage.excluded -contains 'deletion_history'){throw 'The independently saved JSON lacks version, identity history or explicit coverage.'}
      if($json -match '"(access_token|refresh_token|provider_subject|device_id|refresh_digest|phone_hash|key_id|request_hash)"\s*:'){throw 'The saved document contains a prohibited credential/device field.'}
      foreach($request in $value.deletion_history){
        $fields=@($request.PSObject.Properties.Name | Sort-Object)
        if(($fields -join ',') -ne 'effective_at,id,reason,requested_at,status' -or $request.status -notin @('SCHEDULED','CANCELLED','COMPLETED')){throw 'The saved deletion history contains unsupported fields or status.'}
      }
      $report.checks+=@{id='independent-document-readback';result='PASSED'}
      $report.file_name=$fileName
      $report.bytes=(Get-Item -LiteralPath $privateFile).Length
      $report.sha256=(Get-FileHash -LiteralPath $privateFile -Algorithm SHA256).Hash.ToLowerInvariant()
      $report.consent_history_records=$value.consent_history.Count
      $report.schema_version=$value.schema_version
      $report.deletion_history_records=$value.deletion_history.Count
    }
    Save-PickerReport
  }
  $report.result='PASSED'
  $report.note='Real system picker cancellation and save, normal application API response, independent file readback. Synthetic dedicated AVD only. Raw export remains private under build; receipt contains no profile/credentials.'
  Save-PickerReport
}catch{
  $report.result='FAILED';$report.failure=$_.Exception.Message;Save-PickerReport
  # End this owned development test process so a failed picker/OS cannot leave
  # Flutter waiting indefinitely for a frame while Android is in the foreground.
  try {
    Assert-TestAVD
    & $Adb -s $Device logcat -d -b events -t 1500 *> (Join-Path $evidence "$Role-picker-events.private.log")
    & $Adb -s $Device logcat -d -b crash -t 300 *> (Join-Path $evidence "$Role-picker-crashes.private.log")
    & $Adb -s $Device shell dumpsys activity lastanr *> (Join-Path $evidence "$Role-picker-anr.private.log")
    $diagnostics=(@(& $Adb -s $Device shell dumpsys window 2>$null)|Select-String 'mCurrentFocus|mFocusedApp') -join "`n"
    [IO.File]::WriteAllText((Join-Path $evidence "$Role-picker-focus.private.txt"),$diagnostics,[Text.UTF8Encoding]::new($false))
    & $Adb -s $Device shell uiautomator dump /sdcard/planext4u-phase2-export-window.xml *> $null
    & $Adb -s $Device pull /sdcard/planext4u-phase2-export-window.xml (Join-Path $evidence "$Role-picker-failure.private.xml") *> $null
    & $Adb -s $Device shell screencap -p /sdcard/planext4u-phase2-export-failure.png *> $null
    & $Adb -s $Device pull /sdcard/planext4u-phase2-export-failure.png (Join-Path $evidence "$Role-picker-failure.private.png") *> $null
    & $Adb -s $Device shell am force-stop "net.planext4u.$Role.dev" *> $null
  } catch {}
  throw
}
