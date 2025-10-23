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
    Run-Host "ADB备份器","by static-cast" Cyan,DarkCyan -autoSpace
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
        $excludePath += "/storage/emulated/0/Android/"
    }
    if($skipTWRP){
        Debug-Host "已跳过","/sdcard/TWRP" DarkCyan,Cyan
        $excludePath += "/storage/emulated/0/TWRP/"
    }
    Debug-Host "开始拉取文件..." DarkCyan
    $timer = Start-Timer
    $fileCount = (Pull /storage/emulated/0 $PSScriptRoot -excludePath $excludePath -Info) | Select-Object -Last 1
    $timer = Stop-Timer $timer
    Debug-Host "成功拉取",$fileCount,"个文件,","用时",(Format-Time $timer) DarkCyan,Yellow,DarkCyan,DarkYellow,Cyan
    Exit-Stuck
} 
main > $null
