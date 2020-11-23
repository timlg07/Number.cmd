@echo off & cd..
:loop
set /p "input=Number.cmd>"
call Number # %input%
goto loop

