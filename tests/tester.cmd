@echo off
setlocal

if not exist "%~1" (
    echo ERROR. No valid test-file provided.
    echo Required parameter:
    echo   A file containing pairs of parameters and their expected output.
    echo   Both strings should be divided by an equal sign.
    echo   Example line: `5 * 7 = +35E0`
)


set /a total=failed=passed=0

echo.
echo:--- Starting tests: %~n1
echo.

for /F "usebackq tokens=1* delims==" %%P in ("%~1") do (
    for /F "usebackq" %%R in (`..\Number # %%P`) do (
        for /F "tokens=* delims= " %%E in ("%%Q") do (
            if "%%R"=="%%E" (
                echo:[ ] test passed: %%P = %%E
                set /a passed += 1
            ) else (
                echo:[!] test failed: %%P; expected: %%E but was: %%R
                set /a failed += 1
            )
            set /a total += 1
        )
    )
)

echo.
echo:--- Tests finished: %~n1
echo:---    Total tests: %total%
echo:---   Passed tests: %passed%
echo:---   Failed tests: %failed%
echo.

endlocal
pause >nul