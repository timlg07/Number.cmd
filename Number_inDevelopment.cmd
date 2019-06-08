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
:decode <String>%1
	if "!%~1!"=="NaN" exit /b 1

	
	for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
	
		REM define mantissa
		set "%~1.mantissa.integer=%%D"
		
		REM if no sign is given and the number is not zero, it's assumed to be positive
		if "!%~1.mantissa.integer:~0,1!" NEQ "+"  (
		if "!%~1.mantissa.integer:~0,1!" NEQ "-"  (
		if "!%~1.mantissa.integer:0=!" NEQ "" (
			set "%~1.mantissa.integer=+!%~1.mantissa.integer!"
		)))
		
		REM check for only zeros
		if "!%~1.mantissa.integer:0=!"=="" (
			set "%~1.zero=true"
			set "%~1.mantissa.integer=0"
		) else (
			REM remove leading zeros
			for /f "tokens=* delims=0" %%n in ("!%~1.mantissa.integer:~1!") do set "%~1.mantissa.integer=!%~1.mantissa.integer:~0,1!%%n"
		)
		
		
		REM define exponent
		set "%~1.exponent.integer=%%E"
		if "%%E"=="" (
			if "!%~1:~-1!"=="E" (
				set "%~1.exponent.integer=1"
			) else (
				set "%~1.exponent.integer=0"
			)
		)
		
		REM if no sign is given and the number is not zero, it's assumed to be positive
		if "!%~1.exponent.integer:~0,1!" NEQ "+"  (
		if "!%~1.exponent.integer:~0,1!" NEQ "-"  (
		if "!%~1.exponent.integer:0=!" NEQ "" (
			set "%~1.exponent.integer=+!%~1.exponent.integer!"
		)))
		
		REM check for only zeros
		if "!%~1.exponent.integer:0=!"=="" (
			set "%~1.exponent.zero=true"
			set "%~1.exponent.integer=0"
		) else (
			REM remove leading zeros
			for /f "tokens=* delims=0" %%n in ("!%~1.exponent.integer:~1!") do set "%~1.exponent.integer=!%~1.exponent.integer:~0,1!%%n"
		)
		
	)
exit /b 0