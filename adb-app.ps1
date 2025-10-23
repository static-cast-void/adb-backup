try{
    . "$($PSScriptRoot.TrimEnd('/','\'))/adb-lib.ps1" -ErrorAction Stop
}catch{
    Write-Host "[ERROR] 找不到或加载失败 adb-lib.ps1" -ForegroundColor Red
    Pause
    return 1
}
try{
    adblib -test
}catch{
    Write-Host "[ERROR] 加载 adb-lib.ps1 时出错" -ForegroundColor Red
    Pause
    return 1
}
function Show-Banner{
    Run-Host "ADB备份应用器","by static-cast" Cyan,DarkCyan -autoSpace
    Run-Host "版本:", "1.1 (11000)" Yellow,DarkYellow -autoSpace
    Run-Host "License:","MIT" Yellow,DarkYellow -autoSpace
    Run-Host "GitHub:","https://github.com/static-cast-void/adb-backup" Yellow,DarkYellow -autoSpace
    Debug-Host "请确保已连接设备并启用USB调试模式" DarkCyan
    Debug-Host "如果设备未连接或未启用USB调试模式, 脚本将无法工作。" DarkCyan
}
function main {
    (chcp 65001 2>&1 ) > $null
    Show-Banner
    Info-Host "开始检查环境..."  
    Info-Host "库文件版本:",(adblib -version),"($(adblib -versionCode))" Green,Yellow,DarkYellow
    if(Test-Command "adb" -Inversion){
        Error-Host "(1) 未找到ADB, 请安装ADB并将其添加到系统PATH中，否则脚本无法运行。" "Red"
        Exit-Stuck
        return 1
    }
    $start_adb = Start-Job -ScriptBlock { # start adb
        adb start-server 2>&1 > $null
    }
    $7zService = $true
    if(Test-Command "7z" -Inversion){
        Error-Host "未找到7z, 无法使用apks自动打包功能，程序将继续。" "Red"
        $7zService = $false
    }
    Get-ADBInfo
    Debug-Host "ADB版本号:",($global:adb.VersionCode) Yellow,DarkYellow
    Debug-Host "ADB版本:",($global:adb.Version) Yellow,DarkYellow
    Debug-Host "ADB安装位置:",($global:adb.Installed) Yellow,DarkYellow
    Start-Stuck
    if($start_adb.State -eq "Running"){
        Info-Host "正在启动adb服务..." Cyan
        $timer = Start-Timer
        Wait-Job $start_adb
        $timer = Stop-Timer $timer
        Info-Host "adb服务已启动","用时",(Format-Time $timer) Cyan,DarkYellow,Yellow
    }
    Info-Host "程序开始运行" Cyan
    Ask-User 
    $timer = Start-Timer
    $Root = "$($PSScriptRoot.TrimEnd('/','\'))\adb-backup"
    Make-Dir $Root
    $AppList = "$Root\Applist"
    Make-Dir $AppList
    $enabled = "$AppList\enabled"
    Make-Dir "$enabled"
    $enabled_package = [string[]](exec "pm list package -e -3 | sed `"s/package://g`"")
    foreach($i in $enabled_package){
        Make-Dir "$enabled\$i"
        [string[]]$path = (exec "pm path $i | sed `"s/package://g`"")
        $BakTimer = Start-Timer
        foreach($p in $path){
            ((Pull $p "$enabled\$i") 2>&1) > $null
        }
        $BakTimer = Stop-Timer $BakTimer
        Info-Host "成功备份","$i","用时",(Format-Time $BakTimer) Cyan,Yellow,DarkYellow,Yellow
        if($7zService -and [bool][int]($path.Count - 1)){
            $subTimer = Start-Timer
            Info-Host "正在处理apks包..."
            ((7z a "$enabled\$i\$i.zip" "$enabled\$i\*" -r -sdel) 2>&1 ) > $null
            (((Rename-Item "$enabled\$i\$i.zip" "$i.apks") 2>&1) > $null)
            $subTimer = Stop-TImer $subTimer
            Info-Host "处理完成","用时",(Format-Time $subTimer) Cyan,DarkYellow,Yellow
        }else{
            Rename-Item "$enabled\$i\base.apk" "$i.apk"
        }
        Debug-Host "存储位置:","$enabled\$i" Cyan,Yellow
    }
    $disabled = "$AppList\disabled"
    Make-Dir "$disabled"
    $disabled_package = [string[]](exec "pm list package -d | sed `"s/package://g`"")
    foreach($i in $disabled_package){
        Make-Dir "$disabled\$i"
        [string[]]$path = (exec "pm path $i | sed `"s/package://g`"")
        $BakTimer = Start-Timer
        foreach($p in $path){
            ((Pull $p "$disabled\$i") 2>&1) > $null
        }
        $BakTimer = Stop-Timer $BakTimer
        Info-Host "成功备份","$i","用时",(Format-Time $BakTimer) Cyan,Yellow,DarkYellow,Yellow
        if($7zService -and [bool][int]($path.Count - 1)){
            $subTimer = Start-Timer
            Info-Host "正在处理apks包..."
            ((7z a"$disabled\$i\$i.zip" "$disabled\$i\*" -r -sdel) 2>&1 ) > $null
            (((Rename-Item "$disabled\$i\$i.zip" "$i.apks") 2>&1) > $null)
            $subTimer = Stop-TImer $subTimer
            Info-Host "处理完成","用时",(Format-Time $subTimer) Cyan,DarkYellow,Yellow
        }else{
            Rename-Item "$disabled\$i\base.apk" "$i.apk"
        }
        Debug-Host "存储位置:","$disabled/$i" Cyan,Yellow
    }
    $timer = Stop-Timer $timer
    Info-Host "应用程序备份成功完成,","用时",(Format-Time $timer) Cyan,DarkYellow,Yellow
}
main
# adb help:
#  -f: see their associated file
#   -a: all known packages (but excluding APEXes)
#   -d: filter to only show disabled packages
#   -e: filter to only show enabled packages
#   -s: filter to only show system packages
#   -3: filter to only show third party packages
#   -i: see the installer for the packages
#   -l: ignored (used for compatibility with older releases)
#   -U: also show the package UID
#   -u: also include uninstalled packages
#   --show-versioncode: also show the version code
#   --apex-only: only show APEX packages
#   --factory-only: only show system packages excluding updates
