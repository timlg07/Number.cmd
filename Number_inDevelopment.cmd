@echo off
	:: Fetch and decode parameters:
	setlocal enableDelayedExpansion

	set "_variable=%~1"
	set "_operand1=%~2"
	set "_operator=%~3"
	set "_operand2=%~4"

	set "@return=NaN"

	call :decode _operand1
	call :decode _operand2


	:: Call the operation function:
	if "%_operator%"=="+" goto Addition

	:: if no function was called:
	echo.ERROR. Unknown operator: "%_operator%".
exit /b 1


:: Splits the String representation of a number in its parts
:: @param {String} variable name
:decode (String %1)
	if "!%~1!"=="NaN" exit /b 1
	
	for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
	
		REM define mantissa
		set "%~1.mantissa.integer=%%D"
		if "%%D"=="0" (
			set "%~1.zero=true"
		) else (
			echo.%%D|find "+"&&set "%~1.positive=true"
			echo.%%D|find "-"&&set "%~1.negative=true"
		)
		REM define exponent
		set "%~1.exponent.integer=%%E"
		if "%%E"=="0" (
			set "%~1.exponent.zero=true"
		) else (
			echo.%%E|find "+"&&set "%~1.exponent.positive=true"
			echo.%%E|find "-"&&set "%~1.exponent.negative=true"
		)
		
	REM hiding the output of `find`
	)>nul 2>&1
exit /b 0