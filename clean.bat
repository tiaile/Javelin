@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

rem 获取当前脚本目录
set "scriptDir=%~dp0"
cd /d "%scriptDir%"

rem 读取 config.ini 配置（默认记录不存在路径）
set "LOG_NON_EXISTING=1"
if exist config.ini (
    for /f "tokens=2 delims==" %%a in ('type config.ini ^| findstr /i "LogNonExistingPaths"') do (
        set "LOG_NON_EXISTING=%%a"
    )
)

rem 定义存放规则文件的文件夹（可修改）
set "ruleFolder=rules"

rem 检查规则文件夹是否存在
if not exist "%ruleFolder%" (
    echo 错误：规则文件夹 "%ruleFolder%" 不存在. >> clean_log.txt 2>&1
    exit /b 1
)

rem 检查规则文件夹下是否有 txt 文件
dir /b "%ruleFolder%\*.txt" >nul 2>nul
if errorlevel 1 (
    echo 错误：规则文件夹 "%ruleFolder%" 中没有找到任何 .txt 文件. >> clean_log.txt 2>&1
    exit /b 1
)

rem 创建或清空日志文件
set "logFile=clean_log.txt"
> "%logFile%" (
    echo 清理日志 - %date% %time%
    echo ========================
)

rem 遍历规则文件夹中的所有 txt 文件
for %%f in ("%ruleFolder%\*.txt") do (
    echo 正在读取规则文件：%%~nxf >> "%logFile%"
    for /f "usebackq delims=" %%i in ("%%f") do (
        set "line=%%i"
        rem 忽略以 # 开头的注释行
        if not "!line:~0,1!"=="#" (
            rem 去除行首尾空格
            for /f "tokens=*" %%a in ("!line!") do set "line=%%a"
            
            rem 单一路径处理
            set "pathToDel=!line!"
            rem 去掉首尾双引号
            set "pathToDel=!pathToDel:"=!"
            rem 展开环境变量（如 %USERPROFILE%）
            call set "pathToDel=!pathToDel!"
            if exist "!pathToDel!\" (
                rmdir /s /q "!pathToDel!" 2>nul
                if errorlevel 1 (
                    echo 无法清理文件夹：!pathToDel! >> "%logFile%"
                ) else (
                    echo 成功清理路径：!pathToDel! >> "%logFile%"
                )
            ) else (
                if "%LOG_NON_EXISTING%"=="1" (
                    echo 路径不存在：!pathToDel! >> "%logFile%"
                )
            )
        )
    )
)

echo 清理操作完成. >> "%logFile%"
exit /b 0