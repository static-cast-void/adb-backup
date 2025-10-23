function Trim-Path{
    param(
        [string]$Path
    )
    return ($Path.Trim().TrimEnd('/','\').Trim())
}
function Get-Percentage{
    param(
        $now,
        $total,
        [switch]$NoAutoFormat
    )
    $percentage = ($now/$total * 100)
    if($NoAutoFormat){
        return $percentage
    }
    $percentage = [int]$percentage
    $percentage = "$percentage %"
    return $percentage
}
function exec(){
    param(
        [string]$cmd
    )
    if($global:cd){
        return (adb shell "cd `"$global:cd`";$cmd" 2>&1)
    }
    return (adb shell "$cmd" 2>&1)
}
function Test-Command{
    param(
        [string]$Command,
        [switch]$Inversion
    )
    return [bool](Get-Command "$Command" -ErrorAction SilentlyContinue) -xor $Inversion
}
function cd(){
    param(
        [string]$Path,
        [switch]$Linux
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        if((exec "cd $Path") -ne ""){return $false}
        if($Path.Trim() -eq ""){
            $global:cd = "/storage/emulated/0"
            return $true
        }
        $global:cd = $Path
        return $true
    }else{
        try{
            Set-Location $Path
            return $true
        }catch{
            return $false
        }
    }
}
function Test-InUSBDebugging{
    param(
        [switch]$Inversion
    )
    return (((exec "whoami") -eq "shell") -or ((exec "whoami") -eq "root")) -xor $Inversion
}
function Get-ADBInfo{
    [string[]]$adb = (adb version)
    $global:adb = [PSCustomObject]@{
        VersionCode = $adb[0].Substring(("Android Debug Bridge version ").Length)
        Version = $adb[1].Substring(("Version ").Length)
        Installed = $adb[2].Substring(("Installed as ").Length)
        Running = $adb[3].Substring(("Running on ").Length)
    }
}

function dirname {
    param (
        [string]$Path,
        [switch]$Linux
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        return [string](exec "echo '`$(dirname `"$Path`")'")
    }
    return (Split-Path $Path)
}
function basename{
    param (
        [string]$Path,
        [switch]$Linux
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        return [string](exec "echo '`$(basename `"$Path`")'")
    }
    return (Split-Path $Path -Leaf)
}
function Run-Host{
    param (
        [string[]]$msg,
        [string[]]$Color,
        [switch]$autoSpace,
        [switch]$NoNewLine,
        [switch]$UseLastColor
    )
    $counter = 0
    $col = "White"
    foreach($i in $msg){
        $counter++
        $tmp_col = $false
        try{
            Write-Host -ForegroundColor $Color[$counter-1] -NoNewline
            $tmp_col = $true
        }catch{
            $tmp_col = $false
        }
        if($counter -le $Color.Count -and $tmp_col){
            $col = $Color[$counter-1]
            Write-Host "$i" -NoNewline -ForegroundColor $col
        }else{
            if($UseLastColor){
                Write-Host "$i" -NoNewline -ForegroundColor $col
            }else{
                Write-Host "$i" -NoNewline
            }
        }
        if(($counter -ne $msg.count) -and $autoSpace){
            Write-Host " " -NoNewline
        }
    }
    Write-Host -NoNewline:$NoNewLine
}
function Error-Host {
    param (
        [string[]]$msg,
        [string[]]$Color,
        [switch]$NoNewLine,
        [switch]$UseLastColor
    )
    Run-Host -msg (@("[ERROR]") + $msg) -color (@("Red") + $Color) -autoSpace -NoNewLine:$NoNewLine -UseLastColor:$UseLastColor
}
function Debug-Host {
    param (
        [string[]]$msg,
        [string[]]$Color,
        [switch]$NoNewLine,
        [switch]$UseLastColor
    )
    Run-Host -msg (@("[DEBUG]") + $msg) -color (@("Magenta") + $Color) -autoSpace -NoNewLine:$NoNewLine -UseLastColor:$UseLastColor
}
function Info-Host{
    param (
        [string[]]$msg,
        [string[]]$Color,
        [switch]$NoNewLine,
        [switch]$UseLastColor,
        [switch]$enforcingUseLastColor 
    )
    if($Color -and !$enforcingUseLastColor){
        Run-Host -msg (@("[INFO]") + $msg) -color (@("DarkCyan") + $Color) -autoSpace -NoNewLine:$NoNewLine -UseLastColor:$UseLastColor
    }else{
        Run-Host -msg (@("[INFO]") + $msg) -color DarkCyan,Cyan -autoSpace -NoNewLine:$NoNewLine -UseLastColor
    }
}
function Exit-Stuck(){
    Run-Host "[点击","Enter","退出]" Yellow,Cyan,Yellow -NoNewLine -autoSpace
    Read-Host > $null
}
function start-Stuck(){
    Run-Host "[点击","Enter","开始]" Yellow,Cyan,Yellow -NoNewLine -autoSpace
    Read-Host > $null
}
function Convert-RelativePath{
    param(
        [string]$Path,
        [switch]$Linux
    )
    $FlagProcessed = $false
    $Path = (Trim-Path $Path)
    if($Linux){
        $Path = $Path.Replace('\','/')
        if($Path.StartsWith('~/')){
            $relative = $Path.Substring(2)
            $Path = "/storage/emulated/0/$relative"
            $FlagProcessed = $true
        }elseif($Path.StartsWith('./')){
            $relative = $Path.Substring(2)
            $Path = "$global:cd/$relative"
            $FlagProcessed = $true
        }elseif($Path.StartsWith('../')){
            $relative = $Path.Substring(3)
            $Path = "$(dirname $global:cd -Linux)/$relative"
            $FlagProcessed = $true
        }elseif($Path.Equals(".")){
            $Path = "$global:cd"
            $FlagProcessed = $true
        }elseif($Path.Equals("..")){
            $Path = "$(dirname $global:cd -Linux)"
            $FlagProcessed = $true
        }elseif($Path.Equals("~")){
            $Path = "/storage/emulated/0"
            $FlagProcessed = $true
        }
        if(!$FlagProcessed -and !$Path.StartsWith('/')){
            $Path = "$global:cd/$Path"
        }
        $Path = (Trim-Path $Path)
        return $Path
    }
    $Path = $Path.Replace('/','\')
    if($Path.StartsWith('~\')){
        $relative = $Path.Substring(2)
        $Path = "$env:USERPROFILE\$relative"
        $FlagProcessed = $true
    }elseif($Path.StartsWith('.\')){
        $relative = $Path.Substring(2)
        $Path = "$(Get-Location)\$relative"
        $FlagProcessed = $true
    }elseif($Path.StartsWith('..\')){
        $relative = $Path.Substring(3)
        $Path = "$(dirname (Get-Location))\$relative"        
        $FlagProcessed = $true
    }elseif($Path.Equals(".")){
        $Path = "$(Get-Location)"
        $FlagProcessed = $true
    }elseif($Path.Equals("..")){
        $Path = "$(dirname (Get-Location))"
        $FlagProcessed = $true
    }elseif($Path.Equals("~")){
        $Path = "$env:USERPROFILE"
        $FlagProcessed = $true
    }
    if(!$FlagProcessed -and ($Path -notmatch "^[a-zA-Z]\:")){
        $Path = "$(Get-Location)\$Path"
    }
    $Path = (Trim-Path $Path)
    return $Path
}
function Test-Exists{
    param (
        [string]$Path,
        [switch]$Linux,
        [switch]$Inversion
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        return ([bool][int](exec "test -e '$Path' && echo 1 || echo 0") -xor $Inversion)
    }
    return ((Test-Path $Path -PathType Any) -xor $Inversion)
}
function Test-File{
    param (
        [string]$Path,
        [switch]$Linux,
        [switch]$Inversion
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        return ([bool][int](exec "test -f '$Path' && echo 1 || echo 0") -xor $Inversion)
    }
    return ((Test-Path $Path -PathType Leaf) -xor $Inversion)
}
function Test-Dir{
    param (
        [string]$Path,
        [switch]$Linux,
        [switch]$Inversion
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        return ([bool][int](exec "test -d '$Path' && echo 1 || echo 0") -xor $Inversion)
    }
    return ((Test-Path $Path -PathType Container) -xor $Inversion)
}
function List-Path {
    param(
        [string]$Path,
        [switch]$onlyDir,
        [switch]$onlyFile,
        [switch]$Linux
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        if(Test-Dir $Path -Linux -Inversion){
            return $null
        }
        if($onlyDir){
            [string[]]$result = (exec "cd '$Path';ls -d1 */ | sed 's/\///g'")
            if($result -eq "ls: */: No such file or directory" ){
                return $null
            }
            return $result
        }
        if($onlyFile){
            return [string[]](exec "cd '$Path';ls -1p | grep -v '/$'")
        }
        $result = (exec "cd '$Path';ls -1")
        return [string[]]$result.Split("`n")
    }
    if(($Path.Trim() -ne "") -and (Test-Dir $Path -Inversion)){
        return $null
    }
    if($onlyDir){
        return (Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }
    if($onlyFile){
        return (Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }
    return (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
}
function Make-Dir {
    param (
        [string]$Path,
        [switch]$Linux
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        ((exec "mkdir -p '$Path'") 2>&1 ) > $null
        return
    }
    New-Item -Path "$Path" -ItemType Directory -Force -ErrorAction SilentlyContinue > $null
}
function Make-File {
    param (
        [string]$Path,
        [switch]$Linux
    )
    $Path = (Trim-Path $Path)
    if($Linux){
        ((exec "mkdir -p '$(dirname $Path -Linux)'") 2>&1 ) > $null
        ((exec "touch '$Path'") 2>&1 ) > $null
        return
    }
    New-Item -Path "$Path" -ItemType File -Force -ErrorAction SilentlyContinue > $null
}
function Is-Include {
    param (
        [string]$match,
        [string[]]$target,
        [switch]$start,
        [switch]$end,
        [switch]$fullmatch,
        [switch]$Linux,
        [switch]$Inversion
    )
    foreach($i in $target){
        $i = (Trim-Path $i)
        if($Linux){
            $i += '/'
        }else{
            $i += '\'
        }
        if($start){
            if($match.StartsWith($i)){ return ($true -xor $Inversion) }
        }
        if($end){
            if($match.EndsWith($i)){ return ($true -xor $Inversion) }
        }
        if($match -eq $i){ return ($true -xor $Inversion) }
    }
    return ($false -xor $Inversion)
}
function New-IONativeError {
    return [PSCustomObject]@{
        winNotDir = $false
        winNotFile = $false
        winConflictingNeeds = $false
        winNotExists = $false
        linuxNotDir = $false
        linuxNotFile = $false
        linuxConflictingNeeds = $false
        linuxNotExists = $false
    }
}
function IONativeSecurityGuard{
    param(
        [string]$winPath = $null,
        [string]$linuxPath = $null,
        [switch]$winDir,
        [switch]$winFile,
        [switch]$winExists,
        [switch]$linuxDir,
        [switch]$linuxFile,
        [switch]$linuxExists,
        [switch]$Inversion
    )
    $IONativeErrorObject = New-IONativeError
    $seriousError = $false
    $skipWin = $false
    $skipLinux = $false
    # Conflicting combinations
    if($winDir -and $winFile){
        $seriousError = $true
        $skipWin = $true
        $IONativeErrorObject.winConflictingNeeds = $true
    }
    if($linuxDir -and $linuxFile){
        $seriousError = $true
        $skipLinux = $true
        $IONativeErrorObject.linuxConflictingNeeds = $true
    }
    if($winPath -and !$skipWin){
        $winPath = (Convert-RelativePath $winPath)
        if($winDir){
            if((Test-Exists $winPath) -and (Test-Dir $winPath -Inversion)){
                $seriousError = $true
                $IONativeErrorObject.winNotDir = $true
            }elseif(Test-Exists $winPath -Inversion) {
                Make-Dir $winPath
            }
        }
        if($winFile){
            if((Test-Exists $winPath) -and (Test-File $winPath -Inversion)){
                $seriousError = $true
                $IONativeErrorObject.winNotFile = $true
            }elseif(Test-Exists $winPath -Inversion) {
                Make-File $winPath
            }
        }
        if($winExists){
            if(Test-Exists $winPath -Inversion){
                $seriousError = $true
                $IONativeErrorObject.winNotExists = $true
            }
        }
    }
    if($linuxPath -and !$skipLinux){
        $linuxPath = (Convert-RelativePath $linuxPath -Linux)
        if($linuxDir){
            if((Test-Exists $linuxPath -Linux) -and (Test-Dir $linuxPath -Inversion -Linux)){
                $seriousError = $true
                $IONativeErrorObject.linuxNotDir = $true
            }elseif(Test-Exists $linuxPath -Inversion -Linux) {
                Make-Dir $linuxPath -Linux
            }
        }
        if($linuxFile){
            if((Test-Exists $linuxPath -Linux) -and (Test-File $linuxPath -Inversion -Linux)){
                $seriousError = $true
                $IONativeErrorObject.linuxNotFile = $true
            }elseif(Test-Exists $linuxPath -Inversion -Linux) {
                Make-File $linuxPath -Linux
            }
        }
        if($linuxExists){
            if(Test-Exists $linuxPath -Inversion -Linux){
                $seriousError = $true
                $IONativeErrorObject.linuxNotExists = $true
            }
        }
    }
    if($seriousError){
        return $IONativeErrorObject
    }else{
        return $null
    }
}
function Pull-FileNative{
    param (
        [string]$fromPath, # Android Style
        [string]$toPath, # Windows Style
        [switch]$Info
    )
    [string[]]$files = List-Path "$fromPath" -Linux -onlyFile
    if($Info){
        $c = 0
        foreach($i in $files){
            $c++
            $tmpTimer = Start-Timer
            Make-File "$toPath\$i"
            (adb pull "$fromPath/$i" "$toPath\$i" 2>&1) > $null
            $tmpTimer = Stop-Timer $tmpTimer
            Info-Host "成功拉取","$i","($(Get-Percentage $c $files.Count), $c/$($files.Count))","用时",(Format-Time $tmpTimer) Cyan,Yellow,DarkCyan,DarkYellow,Yellow
            Info-Host "储存地点:","$toPath" Cyan,Yellow
        }
        return $files.Count
    }
    foreach($i in $files){
        (adb pull "$fromPath/$i" "$toPath\" 2>&1) > $null
    }
}
function Pull-File{
    param (
        [string]$fromPath, # Android Style
        [string]$toPath, # Windows Style
        [switch]$Info
    )
    $FromPath = (Trim-Path $FromPath)
    $toPath = (Trim-Path $toPath)
    $fromPath = (Convert-RelativePath $fromPath -Linux)
    $toPath = (Convert-RelativePath $toPath)
    $nativeSecurity = IONativeSecurityGuard -linuxPath $fromPath -winPath $toPath -winDir -linuxDir
    if($nativeSecurity){
        if($nativeSecurity.linuxNotDir){
            Error-Host "$fromPath","不是目录" Yellow,Red
        }
        if($nativeSecurity.winNotDir){
            Error-Host "$toPath","不是目录" Yellow,Red
        }
        return $null
    }
    if($Info){
        return Pull-FileNative $fromPath $toPath -Info
    }
    Pull-FileNative $fromPath $toPath
}
function PullNative{
    param (
        [string]$fromPath, # Android Style
        [string]$toPath, # Windows Style
        [string[]]$excludePath,
        [switch]$Info
    )
    $autoQueue = New-Object System.Collections.Queue
    [string[]]$rootDir = List-Path "$fromPath" -Linux -onlyDir
    foreach($i in $rootDir){
        $autoQueue.Enqueue("$fromPath/$i")
    }
    $count = 0
    while([bool][int]$autoQueue.Count){
        [string]$now = $autoQueue.Dequeue()
        if(Is-Include -target $excludePath -match $now -start -Linux){
            continue
        }
        [string[]]$rootDir = List-Path "$now" -Linux -onlyDir
        foreach($i in $rootDir){
            $autoQueue.Enqueue("$now/$i")
        }
        $relativeAsWindows = $now.Substring($fromPath.Length).TrimStart('/').Replace('/','\')
        $absoluteWindows = "$toPath\$relativeAsWindows"
        Make-Dir "$absoluteWindows"
        if($Info){
            $count += Pull-FileNative $now $absoluteWindows -Info
            continue
        }
        Pull-FileNative $now $absoluteWindows
    }
    if($Info){
        return $count
    }
}
function Pull {
    param (
        [string]$fromPath, # Android Style
        [string]$toPath, # Windows Style
        [string[]]$excludePath,
        [switch]$Info
    )
    $FromPath = (Trim-Path $FromPath)
    $toPath = (Trim-Path $toPath)
    $fromPath = (Convert-RelativePath $fromPath -Linux)
    $toPath = (Convert-RelativePath $toPath)
    # fucking user input
    $nativeSecurity = IONativeSecurityGuard -linuxPath $fromPath -winPath $toPath -winDir -linuxExists
    if($nativeSecurity){
        if($nativeSecurity.linuxNotExists){
            Error-Host "$fromPath","不存在" Yellow,Red
        }
        if($nativeSecurity.winNotDir){
            Error-Host "$toPath","不是目录" Yellow,Red
        }
        return $null
    }
    if(Test-File $fromPath -Linux){
        return (adb pull "$fromPath" "$toPath\" 2>&1)
    }
    if($Info){
        return PullNative $fromPath $toPath -excludePath $excludePath -Info
    }
    PullNative $fromPath $toPath -excludePath $excludePath
}
function Push-FileNative{
    param (
        [string]$fromPath, # Windows Style
        [string]$toPath,  # Android Style
        [switch]$Info
    )
    [string[]]$files = (List-Path "$fromPath" -onlyFile)
    if($Info){
        $c = 0
        foreach($i in $files){
            $c++
            $tmpTimer = Start-Timer
            Make-File "$toPath/$i" -Linux
            (adb push "$fromPath\$i" "$toPath/$i" 2>&1) > $null
            $tmpTimer = Stop-Timer $tmpTimer
            Info-Host "成功推送","$i","($(Get-Percentage $c $files.Count), $c/$($files.Count))","用时",(Format-Time $tmpTimer) Cyan,Yellow,DarkCyan,DarkYellow,Yellow
            Info-Host "储存地点:","$toPath" Cyan,Yellow
        }
        return $files.Count
    }
    foreach($i in $files){
        (adb push "$fromPath\$i" "$toPath/" 2>&1) > $null
    }
}
function Push-File{
    param (
        [string]$fromPath, # Windows Style
        [string]$toPath, # Android Style
        [switch]$Info
    )
    $FromPath = (Trim-Path $FromPath)
    $toPath = (Trim-Path $toPath)
    $fromPath = (Convert-RelativePath $fromPath)
    $toPath = (Convert-RelativePath $toPath -Linux)
    $nativeSecurity = IONativeSecurityGuard -linuxPath $toPath -winPath $fromPath -winDir -linuxDir
    if($nativeSecurity){
        if($nativeSecurity.linuxNotDir){
            Error-Host "$fromPath","不是目录" Yellow,Red
        }
        if($nativeSecurity.winNotDir){
            Error-Host "$toPath","不是目录" Yellow,Red
        }
        return $null
    }
    if($Info){
        return Push-FileNative $fromPath $toPath -Info
    }
    Push-FileNative $fromPath $toPath
}
function PushNative{
    param (
        [string]$fromPath, # Windows Style
        [string]$toPath, # Android Style
        [string[]]$excludePath,
        [switch]$Info
    )
    $autoQueue = New-Object System.Collections.Queue
    [string[]]$rootDir = List-Path "$fromPath" -onlyDir
    foreach($i in $rootDir){
        $autoQueue.Enqueue("$fromPath\$i")
    }
    $count = 0
    while([bool][int]$autoQueue.Count){
        [string]$now = $autoQueue.Dequeue()
        [string[]]$rootDir = List-Path "$now" -onlyDir
        foreach($i in $rootDir){
            $autoQueue.Enqueue("$now\$i")
        }
        $relativeAsLinux = $now.Substring($fromPath.Length).TrimStart('\').Replace('\','/')
        $absoluteLinux = "$toPath/$relativeAsLinux"
        Make-Dir "$absoluteLinux" -Linux
        if($Info){
            $count += Push-FileNative $now $absoluteLinux -Info
            continue
        }
        Push-FileNative $now $absoluteLinux
    }
    if($Info){
        return $count
    }
}
function Push {
    param (
        [string]$fromPath, # Windows Style
        [string]$toPath, # Android Style
        [string[]]$excludePath,
        [switch]$Info
    )
    $FromPath = (Trim-Path $FromPath)
    $toPath = (Trim-Path $toPath)
    $fromPath = (Convert-RelativePath $fromPath)
    $toPath = (Convert-RelativePath $toPath -Linux)
    # fucking user input
    $nativeSecurity = IONativeSecurityGuard -linuxPath $toPath -winPath $fromPath -winDir -linuxDir
    if($nativeSecurity){
        if($nativeSecurity.linuxNotExists){
            Error-Host "$fromPath","不存在" Yellow,Red
        }
        if($nativeSecurity.winNotDir){
            Error-Host "$toPath","不是目录" Yellow,Red
        }
        return $null
    }
    if(Test-File $fromPath){
        return (adb push "$fromPath" "$toPath/" 2>&1)
    }
    if($Info){
        return PushNative $fromPath $toPath -excludePath $excludePath -Info
    }
    PushNative $fromPath $toPath -excludePath $excludePath
}
function Start-Timer{
    return (Get-Date)
}
function Stop-Timer{
    param(
        $TimeSpan
    )
    return (Get-Date)-$TimeSpan
}
function Format-Time{
    param(
        $duration
    )
    if ($duration.Hours -gt 0) {
        if($duration.Hours -le 9){
            $output += "0$($duration.Hours):"
        }else{
            $output += "$($duration.Hours):"
        }
    }
    if ($duration.Minutes -le 9) {
        $output += "0$($duration.Minutes):"
    }else{
        $output += "$($duration.Minutes):"
    }
    $sec = [math]::Round($duration.Seconds)
    if($sec -le 9){
        $output += "0$sec"
    }else{
        $output += "$sec"
    }
    return $output
}
function Ask-User {
    param (
        [switch]$str,
        [switch]$yesOrNo,
        [switch]$number,
        [switch]$positiveNumber,
        [switch]$negativeNumber,
        [switch]$rangeNumber,
        [switch]$twoOptions,
        [switch]$equalString,
        [string]$targetString,
        [string]$option1,
        [string]$option2,
        [int64]$fromNumber = 0,
        [int64]$toNumber = 0,
        [switch]$untilValid,
        [scriptblock]$startAction = $null,
        [scriptblock]$failedAction = $null
    )
    if($str){
        if($startAction){ . $startAction }
        return [string](Read-Host)
    }
    [string]$in = $null
    if($twoOptions){
        while ($true){
            if($startAction){ . $startAction }
            $in = Read-Host
            if(($in -eq $option1) -or ($in -eq $option2)){
                return $in
            }
            if($failedAction){ . $failedAction }
            if (-not $untilValid) { return $null }
        }
    }
    if($equalString){
        while ($true){
            if($startAction){ . $startAction }
            $in = Read-Host
            if($targetString -eq $in){
                return $in
            }
            if($failedAction){ . $failedAction }
            if (-not $untilValid) { return $false }
        }
    }
    if($number -or ($positiveNumber -and $negativeNumber)){
        while ($true){
            if($startAction){ . $startAction }
            $in = Read-Host
            try{
                $ans = [int64]$in
                return $ans
            }catch{
                $ans = $null
            }
            if($failedAction){ . $failedAction }
            if (-not $untilValid) { return $null }
        }
    }
    if($negativeNumber){
        while ($true){
            if($startAction){ . $startAction }
            $in = Read-Host
            try{
                $ans = [int64]$in
                if($ans -lt 0){
                    return $ans
                }
                $ans = $null
            }catch{
                $ans = $null
            }
            if($failedAction){ . $failedAction }
            if (-not $untilValid) { return $null }
        }
    }
    if($positiveNumber){
        while ($true){
            if($startAction){ . $startAction }
            $in = Read-Host
            try{
                $ans = [int64]$in
                if($ans -gt 0){
                    return $ans
                }
                $ans = $null
            }catch{
                $ans = $null
            }
            if($failedAction){ . $failedAction }
            if (-not $untilValid) { return $null }
        }
    }
    if($rangeNumber){
        while ($true){
            if($startAction){ . $startAction }
            $in = Read-Host
            try{
                $ans = [int64]$in
                if(($ans -ge $fromNumber) -and ($ans -le $toNumber)){
                    return $ans
                }
                $ans = $null
            }catch{
                $ans = $null
            }
            if($failedAction){ . $failedAction }
            if (-not $untilValid) { return $null }
        }
    }
    while ($true){
        if($startAction){ . $startAction }
        $in = Read-Host
        if ($in -ieq 'Y' -or $in -ieq 'Yes') { return $true }
        if ($in -ieq 'N' -or $in -ieq 'No') { return $false }
        if($failedAction){ . $failedAction }
        if (-not $untilValid) { return $null }
    }
}
function adblib{
    param(
        [switch]$test,
        [switch]$version,
        [switch]$versionCode,
        [switch]$description
    )
    if($test){
        return
    }
    if($version){
        return "1.1"
    }
    if($versionCode){
        return 11000
    }
    if($description){
        return "
            Fixed an issue with ADB's UTF-8 support on Windows. 
            However, performance is 3~6 times slower than adb-official.
        "
    }
}
$null = Register-EngineEvent PowerShell.Exiting -Action {
    Debug-Host "再点一次退出。"
    Exit-Stuck
    exit 1
}
function main{
    Error-Host "此脚本为支持库，为其他脚本提供运行环境，不支持直接运行。" DarkYellow
    Exit-Stuck
}
$runtime = [string[]](Get-PSCallStack)
if($runtime.Count -le 1){
    main > $null
}
