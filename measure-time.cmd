@echo off
:main
    set /p "term=Number::measureTime> "
    echo result:
    call "%~dp0Number.cmd" # %term%
    echo time:
    powershell Measure-Command {"%~dp0Number" x = %term%}
goto main