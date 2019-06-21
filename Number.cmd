@echo off
	:: Fetch and decode parameters:
	setlocal enableDelayedExpansion
	
	if "%~4"=="" (
		echo.ERROR. Missing parameter^(s^).
		exit /b 4
	)

	set "_variable=%~1"
	set "_operand1=%~2"
	set "_operator=%~3"
	set "_operand2=%~4"

	set "@return=NaN"

	call :decode _operand1 || ( echo.ERROR. First operand is not a number ^(NaN^).  & exit /b 1 )
	call :decode _operand2 || ( echo.ERROR. Second operand is not a number ^(NaN^). & exit /b 2 )


	:: Call the operation function:
	if "%_operator%"=="+" goto Addition
	if "%_operator%"=="-" goto Subtraction
	if "%_operator%"=="*" goto Multiplication
	if "%_operator%"=="/" goto Division

	:: if no function was called:
	echo.ERROR. Unknown operator: "%_operator%".
exit /b 3



:Addition

	:: make sure both numbers have the same exponent
	:: by decreasing the higher exponent while increasing its mantissa:
	
	if %_operand1.exponent.integer% GTR %_operand2.exponent.integer% (
		REM difference between both exponents
		set /a delta = _operand1.exponent.integer - _operand2.exponent.integer
		REM multiply with 10^delta
		for /L %%i in (1 1 !delta!) do (
			set "_operand1.mantissa.integer=!_operand1.mantissa.integer!0"
		)
		REM decrease the exponent
		set /a _operand1.exponent.integer -= delta
	)

	if %_operand2.exponent.integer% GTR %_operand1.exponent.integer% (
		REM difference between both exponents
		set /a delta = _operand2.exponent.integer - _operand1.exponent.integer
		REM multiply with 10^delta
		for /L %%i in (1 1 !delta!) do (
			set "_operand2.mantissa.integer=!_operand2.mantissa.integer!0"
		)
		REM decrease the exponent
		set /a _operand2.exponent.integer -= delta
	)

	:: Now both exponents are equal and the addition can be started:
	if %_operand1.exponent.integer% EQU %_operand2.exponent.integer% (
	
		REM ISSUE:INT32 :: highest possible positive number: (2^32/2)-1 = 2147483647
		set /a sum = _operand1.mantissa.integer + _operand2.mantissa.integer
		
		REM save result
		set "@return=!sum!E%_operand1.exponent.integer%"
	)

goto Finish



:Subtraction

	REM if second operand is zero, the result is equal to the first operand
	if "%_operand2.zero%"=="true" (
		set "@return=%_operand1%"
		goto finish
	)
	
	REM invert the second operands sign
	set _newSign=+
	if "%_operand2.mantissa.integer:~0,1%"=="+" set _newSign=-
	set "_operand2.mantissa.integer=%_newSign%%_operand2.mantissa.integer:~1%"

	REM add both numbers, since a - b <=> a + (-b)
goto Addition



:Multiplication

	REM add the exponents, because:
	REM a^r * a^s <=> a^(r+s)
	REM a = 10; r = operand1.exponent; s = operand2.exponent;
	set /a _exponent = _operand1.exponent.integer + _operand2.exponent.integer
	REM multiply the mantissas, because:
	REM m_1 * 10^r  *  m_2 * 10^s <=> m_1 * m_2  *  10^r * 10^s
	set /a _mantissa = _operand1.mantissa.integer * _operand2.mantissa.integer
	REM return both
	set "@return=%_mantissa%E%_exponent%"

goto Finish



:Division

	REM remove negative sign, because it would show up at each digit
	set /a _sign = +1
	if "%_operand1.mantissa.integer:~0,1%"=="-" set /a _sign *= -1
	if "%_operand2.mantissa.integer:~0,1%"=="-" set /a _sign *= -1
	set "_operand1.mantissa.integer=%_operand1.mantissa.integer:-=%"
	set "_operand2.mantissa.integer=%_operand2.mantissa.integer:-=%"

	REM divide the mantissas, because:
	REM ( m_1 * 10^r ) / ( m_2 * 10^s ) <=> ( m_1 / m_2 ) * ( 10^r / 10^s )
	REM <<the following uncommented code is mainly from Batch_Tools/3-2-division.cmd>>
	set /a _int = _operand1.mantissa.integer / _operand2.mantissa.integer
	set "@return=%_int%"
	if %@return%==0 set "@return="
	set /a _remainder = _operand1.mantissa.integer - ( _int * _operand2.mantissa.integer )
	set /a _decP = 0
	:div_LOOP
		set /a _intR      = (_remainder*10) /           _operand2.mantissa.integer
		set /a _remainder = (_remainder*10) - ( _intR * _operand2.mantissa.integer )
		set @return=%@return%%_intR%
		set /a _decP += 1
		
		if %_remainder% NEQ 0 (
		if %_decP% LSS 7 (
			goto div_LOOP
		))
	
	REM subtract the exponents, because:
	REM a^r / a^s <=> a^(r-s)
	REM a = 10; r = operand1.exponent; s = operand2.exponent;
	set /a _exponent = _operand1.exponent.integer - _operand2.exponent.integer
	REM lower the exponent for each added decimal place
	set /a _exponent -= _decP
	REM set sign
	set /a @return *= _sign
	REM return
	set @return=%@return%E%_exponent%

goto Finish





:: Splits the String representation of a number in its parts
:: @param {String} variable name
:decode <String>%1
	if "!%~1!"=="NaN" exit /b 1
	
	REM check for static constants
	if /i "!%~1:~0,7!"=="Number." (
		REM 2.71828182845904523536028747135266249775724709369995 -> INT32
		if /i "!%~1:~7!"=="e"  set "%~1=+271828182E-8"
		REM 3.141592653589793238462643383279502884197169399375105820974944 -> INT32
		if /i "!%~1:~7!"=="pi" set "%~1=+314159265E-8"
	)
	
	REM if only E^x is given the mantissa is 1; this is needed here so the for is executed in this case, too
	if "!%~1:~0,1!"=="E"  set "%~1=+1!%~1!"
	
	REM splits the number up and sets the variables
	for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
	
		REM define mantissa
		set "%~1.mantissa.integer=%%D"
		
		REM if only E^x is given the mantissa is 1
		if "!%~1:~0,2!"=="+E" set "%~1.mantissa.integer=+1"
		if "!%~1:~0,2!"=="-E" set "%~1.mantissa.integer=-1"
		
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



:: Optimizes the String representation of a number
:: @param {String} variable name
:optimize <String>%1
	REM splits up the number
	for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
		set "_mantissa=%%D"
		set "_exponent=%%E"
	)
	
	:zeroTreatment
		REM In case the mantissa is zero, it makes sense if the exponent is also zero.
		if "%_mantissa:0=%"=="" (
			REM no further optimization needed
			set "@return=0E0"
			exit /b 0
		)
	
	:removeTrailingZeros
		REM removes the last zero and increases the exponent
		REM (but only if the number isn't zero)
		if "%_mantissa:~-1%"=="0" (
		if not "%_mantissa:0=%"=="" (
			set /a _exponent += 1
			set "_mantissa=%_mantissa:~0,-1%"
			REM next iteration of the do-while-loop, which stops at the first non-zero value
			goto removeTrailingZeros
		))
	
	:addPositiveSigns
		REM if mantissa is not zero and has no sign, it gets a positive sign
		if "%_mantissa:0=%"   NEQ ""  (
		if "%_mantissa:~0,1%" NEQ "-" (
		if "%_mantissa:~0,1%" NEQ "+" (
			set "_mantissa=+%_mantissa%"
		)))
		
		REM if exponent is not zero and has no sign, it gets a positive sign
		if "%_exponent:0=%"   NEQ ""  (
		if "%_exponent:~0,1%" NEQ "-" (
		if "%_exponent:~0,1%" NEQ "+" (
			set "_exponent=+%_exponent%"
		)))
	
	:concatenate
		REM combines the number again
		set "@return=%_mantissa%E%_exponent%"
	
exit /b


:Finish
	call :optimize @return
	
	echo.%@return%
	endlocal &(
		REM altering variable
		set "%_variable%=%@return%"
	)
exit /B 0