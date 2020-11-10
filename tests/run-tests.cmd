@echo off
set /a total=failed=passed=files=time=0
echo Running all tests in %cd%
for %%T in ("%cd%\*.test") do call :test "%%~fT"

if %failed% equ 0 color a0 

set /a avgTime = time / files

echo.
echo:------------------------------
echo:--- Test files executed: %files%
echo:---         Total tests: %total%
echo:---        Passed tests: %passed%
echo:---        Failed tests: %failed%
echo:---        Average time: %avgTime% ms
echo:------------------------------
echo.

pause >nul
exit


:test
    call "%~dp0tester.cmd" "%~1" 1 || color c0
    set /a  files += 1
    set /a  total += _total
    set /a failed += _failed
    set /a passed += _passed
    set /a   time += _averageTime
exit /b %errorlevel%