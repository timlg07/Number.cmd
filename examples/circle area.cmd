@echo off
cd ..
title Circle Area Calculator - Number.cmd Demo

:main
echo:Radius of the circle:
set /p "r= > "

rem calculating the area: A = pi * r^2
call Number r_squared = %r% * %r%
call Number A = Number.pi * %r_squared%

echo:The area of the circle is: %A%.
echo:(A = pi * r^2 = pi * %r_squared% = %A%)
pause
goto main