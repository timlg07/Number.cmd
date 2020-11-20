@echo off

echo fetching Number.cmd:
curl "https://tim-greller.de/git/number/Number.cmd" > Number.cmd
echo finished.

echo running simple calculations:
call Number x = 4 + 4
call Number y = 270 / 6
echo 4 + 4 = %x%; 270 / 6 = %y%

echo.
del Number.cmd
echo Number.cmd deleted.

pause