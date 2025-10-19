function Test-Command{
    param(
        [string]$Command,
        [switch]$Inversion
    )
    return [bool](Get-Command "$Command" -ErrorAction SilentlyContinue) -xor $Inversion
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
function Show-Banner{
    Run-Host "ADB备份恢复器","by static-cast" Cyan,DarkCyan -autoSpace
    Run-Host "版本:", "1.0 (10000)" Yellow,DarkYellow -autoSpace
    Run-Host "License:","MIT" Yellow,DarkYellow -autoSpace
    Run-Host "GitHub:","https://github.com/static-cast-void/adb-backup" Yellow,DarkYellow -autoSpace
    Debug-Host "请确保已连接设备并启用USB调试模式" DarkCyan
    Debug-Host "如果设备未连接或未启用USB调试模式, 脚本将无法工作。" DarkCyan
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
function exec(){
    param(
        [string]$cmd
    )
    if($global:cd){
        return (adb shell "cd `"$global:cd`";$cmd" 2>&1)
    }
    return (adb shell "$cmd" 2>&1)
}
function pull {
    param (
        [string]$FromPath,
        [string]$toPath
    )
    return (adb pull "$fromPath" "$toPath" 2>&1 )
}
function push {
    param (
        [string]$FromPath,
        [string]$toPath
    )
    return (adb push "$fromPath" "$toPath")
}
function cd(){
    param(
        [string]$Path,
        [switch]$Linux
    )
    if($Linux){
        if((exec "cd $Path") -ne ""){return $false}
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
function dirname {
    param (
        [string]$Path,
        [switch]$Linux
    )
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
    if($Linux){
        return [string](exec "echo '`$(basename `"$Path`")'")
    }
    return (Split-Path $Path -Leaf)
}
function List-Path {
    param(
        [string]$Path,
        [switch]$onlyDir,
        [switch]$onlyFile
    )
    
    if(-not (Test-Path $Path)){
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
    if($Linux){
        ((exec "mkdir -p '$(dirname $Path -Linux)'") 2>&1 ) > $null
        ((exec "touch '$Path'") 2>&1 ) > $null
        return
    }
    New-Item -Path "$Path" -ItemType File -Force -ErrorAction SilentlyContinue > $null
}
function Test-Exists{
    param (
        [string]$Path,
        [switch]$Linux
    )
    if($Linux){
        return [bool][int](exec "test -e '$Path' && echo 1 || echo 0")
    }
    return Test-Path $Path -PathType Any
}
function Test-File{
    param (
        [string]$Path,
        [switch]$Linux
    )
    if($Linux){
        return [bool][int](exec "test -f '$Path' && echo 1 || echo 0")
    }
    return Test-Path $Path -PathType Leaf
}
function Test-Dir{
    param (
        [string]$Path,
        [switch]$Linux
    )
    if($Linux){
        return [bool][int](exec "test -d '$Path' && echo 1 || echo 0")
    }
    return Test-Path $Path -PathType Container
}
function Is-Include {
    param (
        [string]$match,
        [string[]]$target,
        [switch]$start,
        [switch]$end,
        [switch]$fullmatch
    )
    foreach($i in $target){
        $i = $i.TrimEnd('/','\')
        $i = $i + '\'
        if($start){
            if($match.StartsWith($i)){ return $true }
        }
        if($end){
            if($match.EndsWith($i)){ return $true }
        }
        if($match -eq $i){ return $true }
    }
    return $false
}
function Make-Structure{
    param(
        [string]$FromPath, # Windows-style path
        [string]$ToPath, # Android linux-style path
        [string[]]$excludePath
    )
    $counter = 0
    $queue = New-Object System.Collections.Queue
    $FromPath = $FromPath.TrimEnd('\','/')
    $ToPath = $ToPath.TrimEnd('\','/').Replace('\','/')
    $queue.Enqueue($FromPath)
    while([bool][int64]$queue.Count){
        [string]$now = $queue.Dequeue()
        $now.TrimEnd('\','/')
        if(Is-Include "$now\" -start -target $excludePath){ continue }
        $counter++
        [string]$relative = $now.Substring($FromPath.Length).TrimStart('/','\')
        [string]$relativeLinuxStyle = $relative.Replace('\','/')
        [string]$linuxPath = ("$ToPath/$relativeLinuxStyle").TrimEnd('\','/')
        Make-Dir "$linuxPath" -Linux
        Info-Host "[$counter]","成功创造结构:","$linuxPath" DarkYellow,Cyan,Yellow  
        [string[]]$newDir = (List-Path $now -onlyDir)
        foreach($i in $newDir){
            $queue.Enqueue("$now\$i")
        }
    }
    return $counter
}
function Start-Push{
    param(
        [string]$FromPath, # Windows-style path
        [string]$ToPath, # Android linux-style path
        [string[]]$excludePath
    )
    $counter = 0
    $queue = New-Object System.Collections.Queue
    $FromPath = $FromPath.TrimEnd('\','/')
    $ToPath = $ToPath.TrimEnd('\','/').Replace('\','/')
    $queue.Enqueue($FromPath)
    while([bool][int64]$queue.Count){
        [string]$now = $queue.Dequeue()
        $now.TrimEnd('\','/')
        if(Is-Include "$now\" -start -target $excludePath){ continue }
        [string]$relative = $now.Substring($FromPath.Length).TrimStart('/','\')
        [string]$relativeLinuxStyle = $relative.Replace('\','/')
        [string]$linuxPath = ("$ToPath/$relativeLinuxStyle").TrimEnd('\','/')
        [string[]]$fileList = (List-Path $now -onlyFile)
        foreach($i in $fileList){
            $counter++
            Make-File "$linuxPath/$i" -Linux
            $output = ((push "$now\$i" "$linuxPath/$i") 2>&1 )
            Info-Host "[$counter]","成功推送文件:","$linuxPath/$i" DarkYellow,Cyan,Yellow 
            Debug-Host "$output" Cyan
        }
        
        [string[]]$newDir = (List-Path $now -onlyDir)
        foreach($i in $newDir){
            $queue.Enqueue("$now\$i")
        }
    }
    return $counter
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
function main {
    (chcp 65001 2>&1 ) > $null
    Show-Banner
    Info-Host "开始检查环境..."  
    if(Test-Command "adb" -Inversion){
        Error-Host "(1) 未找到ADB, 请安装ADB并将其添加到系统PATH中，否则脚本无法运行。" "Red"
        Exit-Stuck
        return 1
    }
    $start_adb = Start-Job -ScriptBlock { # start adb
        adb start-server 2>&1 > $null
    }
    Get-ADBInfo
    Debug-Host "ADB版本号:",($global:adb.VersionCode) Yellow,DarkYellow
    Debug-Host "ADB版本:",($global:adb.Version) Yellow,DarkYellow
    Debug-Host "ADB安装位置:",($global:adb.Installed) Yellow,DarkYellow
    Wait-Job $start_adb
    if(Test-InUSBDebugging -Inversion){
        Error-Host "(2) 设备未连接, 请检查连接并启用USB调试模式。" "Red"
        Exit-Stuck
        return 2
    }
    Info-Host "设备已连接" Cyan  
    [bool]$skipAndroid = Ask-User -yesOrNo -startAction{
        Info-Host "是否要跳过","/sdcard/Android","文件夹?","(推荐)","(y/n) " Yellow,Cyan,Yellow,DarkCyan,Green -NoNewLine  
    } -failedAction {
        Info-Host "无效输入, 自动选择 y 。"  
        return $true
    }
    [bool]$skipTWRP = Ask-User -yesOrNo -startAction{
        Info-Host "是否要跳过","/sdcard/TWRP","文件夹?","(如有)","(y/n) " Yellow,Cyan,Yellow,DarkCyan,Green -NoNewLine  
    } -failedAction {
        Info-Host "无效输入, 自动选择 y 。" 
        return $true
    }
    [string[]]$excludePath = @()
    if($skipAndroid){
        Debug-Host "已跳过","/sdcard/Android" DarkCyan,Cyan  
        $excludePath += "$($PSScriptRoot.TrimEnd('\','/'))\Android\"
    }
    if($skipTWRP){
        Debug-Host "已跳过","/sdcard/TWRP" DarkCyan,Cyan 
        $excludePath += "$($PSScriptRoot.TrimEnd('\','/'))\TWRP\"
    }
    Debug-Host "开始建立结构..." DarkCyan
    $timer = Start-Timer
    $dirCount = (Make-Structure $PSScriptRoot /storage/emulated/0 -excludePath $excludePath) | Select-Object -Last 1
    $timer = Stop-Timer $timer
    Debug-Host "成功建立",$dirCount,"个结构,","用时",(Format-Time $timer) DarkCyan,Yellow,DarkCyan,DarkYellow,Cyan
    Debug-Host "开始推送文件..." DarkCyan
    $timer = Start-Timer
    $fileCount = (Start-Push $PSScriptRoot /storage/emulated/0 -excludePath $excludePath) | Select-Object -Last 1
    $timer = Stop-Timer $timer
    Debug-Host "成功推送",$fileCount,"个文件,","用时",(Format-Time $timer) DarkCyan,Yellow,DarkCyan,DarkYellow,Cyan
    Exit-Stuck
} 
main > $null
