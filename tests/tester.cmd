@echo off

if not exist "%~1" (
    echo ERROR. No valid test-file provided.
    echo Required parameter:
    echo   A file containing pairs of parameters and their expected output.
    echo   Both strings should be divided by an equal sign.
    echo   Example line: `5 * 7 = +35E0`
)

set /a _measureTime = 0
if "%~2" neq "" if "%~2" neq "0" if /i "%~2" neq "false" (
    set "_measureTime=%~2"
    set _timeLogFile="%~dp1performance\%~n1.times.log"
    2>nul del %_timeLogFile%
)

set /a _total = _failed = _passed = _totalTime = 0

echo.
echo:--- Starting tests: %~n1
echo.

for /F "usebackq tokens=1* delims==" %%P in ("%~1") do (
        for /F "tokens=* delims= " %%E in ("%%Q") do (
			call :exec_test_case "%%~P" "%%~E"
        )
    )
)

set /a _averageTime = _totalTime / _passed

echo.
echo:--- Tests finished: %~n1
echo:---    Total tests: %_total%
echo:---   Passed tests: %_passed%
echo:---   Failed tests: %_failed%
if %_measureTime% neq 0 (
    echo:---   Average time: %_averageTime% ms
)
echo.

exit /b %_failed%


:exec_test_case (calculation, expected_result)
SETLOCAL ENABLEDELAYEDEXPANSION
	set "t0="
	set "t1="
	
	for /f "tokens=*" %%t in ('ver ^| time') do (
		if not defined t0 (
			set t0=%%t
			set t0=!t0:,=.!
			FOR %%T IN (!t0!) DO (
				SET t0=%%T
			)
		)
	)
	
	for /F "usebackq" %%R in (`"%~dp0..\Number" # %~1`) do (
	    set "result=%%R"
	)
	
	for /f "tokens=*" %%t in ('ver ^| time') do (
		if not defined t1 (
			set t1=%%t
			set t1=!t1:,=.!
			FOR %%T IN (!t1!) DO (
				SET t1=%%T
			)
		)
	)
	
	FOR /F "tokens=1-4 delims=:.," %%A IN ("%t0%") DO (
		SET HoursBefore=%%A
		SET MinutesBefore=%%B
		SET SecondsBefore=%%C
		SET FractBefore=%%D
	)
	FOR /F "tokens=1-4 delims=:.," %%A IN ("%t1%") DO (
		SET HoursAfter=%%A
		SET MinutesAfter=%%B
		SET SecondsAfter=%%C
		SET FractAfter=%%D
	)
	
	FOR %%A IN (HoursAfter MinutesAfter SecondsAfter FractAfter HoursBefore MinutesBefore SecondsBefore FractBefore) DO CALL :RemoveLeadingZero %%A
	
	SET /A Hours   = !HoursAfter!   - !HoursBefore!
	SET /A Minutes = !MinutesAfter! - !MinutesBefore!
	SET /A Seconds = !SecondsAfter! - !SecondsBefore!
	SET /A Fract   = !FractAfter!   - !FractBefore!
	SET /A TimeDif =  100 * !Hours!   + !Minutes!
	SET /A TimeDif =  100 * !TimeDif! + !Seconds!
	SET /A TimeDif = 1000 * !TimeDif! + 10 * !Fract!


	if "%result%"=="%~2" (
        if %_measureTime% neq 0 (
            2>nul (echo.%~1 = %~2 :: %TimeDif% ms >> %_timeLogFile%)
            echo.[ ] test passed: %~1 = %~2; completed in %TimeDif% ms
        ) else (
            echo:[ ] test passed: %~1 = %~2
        )
        set /a _passed += 1
    ) else (
        echo:[!] test failed: %~1; expected: %~2 but was: %result%
        set /a _failed += 1
    )
	
endlocal & (
    set /a _total += 1
    set /a _totalTime += %TimeDif%
	set /a _passed = %_passed%
	set /a _failed = %_failed%
)
exit /b

:RemoveLeadingZero
SET TempVar=!%1!
IF "%TempVar:~0,1%"=="0" SET TempVar=%TempVar:~1%
IF "%TempVar:~0,1%"==""  SET TempVar=0
SET %1=%TempVar%
GOTO:EOF
