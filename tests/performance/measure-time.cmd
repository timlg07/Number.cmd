@echo off
:main
    set /p "term=Number::measureTime> "
    echo;|set/p "=result: "
    call "%~dp0..\..\Number.cmd" # %term%
    powershell \"time: \" + (Measure-Command {"%~dp0..\..\Number" _ %term%}).TotalMilliseconds.ToString() + \"ms`r`n\"
goto main