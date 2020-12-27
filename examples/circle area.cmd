@echo off
cd ..
title Circle Area Calculator - Number.cmd Demo

:main
set /p "r=Radius of the circle: "

rem calculating the area: A = pi * r^2
call Number r_squared = %r% * %r%
call Number A = Number.pi * %r_squared% format:.

echo:The area A of the circle is: %A%
echo:A = pi * %r%^^2 = pi * %r_squared% = %A%
pause
echo:
goto main