@echo off

if not exist "%~1" (
    echo ERROR. No valid test-file provided.
    echo Required parameter:
    echo   A file containing pairs of parameters and their expected output.
    echo   Both strings should be divided by an equal sign.
    echo   Example line: `5 * 7 = +35E0`
)

set _timeLogFile="%~dp1performance\%~n1.times.log"
2>nul del %_timeLogFile%

set /a _measureTime = 0
if "%~2" neq "" set "_measureTime=%~2"

set /a _total = _failed = _passed = _totalTime = 0

echo.
echo:--- Starting tests: %~n1
echo.

for /F "usebackq tokens=1* delims==" %%P in ("%~1") do (
    for /F "usebackq" %%R in (`"%~dp0..\Number" # %%P`) do (
        for /F "tokens=* delims= " %%E in ("%%Q") do (
            if "%%R"=="%%E" (
                if %_measureTime% neq 0 (
                    for /F "usebackq tokens=1,2 delims=.," %%t in (`powershell -command "(Measure-Command {"%~dp0..\Number" _ %%P%}).TotalMilliseconds.ToString()"`) do (
                        echo.[ ] test passed: %%P = %%E; completed in %%t,%%u ms
                        set /a _totalTime += %%t
                        2>nul (echo.%%P = %%E :: %%t,%%u ms >> %_timeLogFile%)
                    )
                ) else (
                    echo:[ ] test passed: %%P = %%E
                )
                set /a _passed += 1
            ) else (
                echo:[!] test failed: %%P; expected: %%E but was: %%R
                set /a _failed += 1
            )
            set /a _total += 1
        )
    )
)

set /a _averageTime = _totalTime / _passed

echo.
echo:--- Tests finished: %~n1
echo:---    Total tests: %_total%
echo:---   Passed tests: %_passed%
echo:---   Failed tests: %_failed%
echo:---   Average time: %_averageTime% ms
echo.

exit /b %_failed%