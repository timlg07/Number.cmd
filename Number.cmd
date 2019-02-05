@echo off
set "$executedTasks=0"

:MAIN params<>
    ::process: %1
    if [%1]==[] goto END

    echo.%~1|findstr /i "^/new:" >nul && call :NEW "%~1"

    shift
goto MAIN


:END
    if %$executedTasks% equ 0 goto HELP
exit
