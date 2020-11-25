@setlocal enableDelayedExpansion
@call :storeEchoState
@echo off


:main
    REM A minimum of 4 parameters is always required.
    if "%~4"=="" (
        echo.ERROR. Missing parameter^(s^).
        exit /b 4
    )
    
    set "_variable=%~1"
    set "_operand1=%~2"
    set "_operator=%~3"
    set "_operand2=%~4"
    
    REM Do not restrict the precision by default. Only the division will fallback to a default value
    REM to ensure that the algorithm always terminates.
    set "_precision=max"
    if "%~5" neq "" call :readPrecisionParam "%~5"

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

    REM Now both exponents are equal and the addition can be started.
    call :signedAdd sum = "%_operand1.mantissa.integer%" + "%_operand2.mantissa.integer%"
    
    REM save result
    set "@return=!sum!E%_operand1.exponent.integer%"

goto Finish



:Subtraction
    REM If the second operand is zero, the result is equal to the first operand.
    if "%_operand2.zero%"=="true" (
        set "@return=%_operand1.mantissa.integer%E%_operand1.exponent.integer%"
        goto finish
    )
    
    REM invert the second operands sign
    set _newSign=+
    if "%_operand2.mantissa.integer:~0,1%"=="+" set _newSign=-
    set "_operand2.mantissa.integer=%_newSign%%_operand2.mantissa.integer:~1%"

    REM add both numbers, since a - b = a + (-b)
goto Addition



:Multiplication
    REM Add the exponents, because:
    REM a^r * a^s = a^(r+s)
    REM where a = 10; r = operand1.exponent; s = operand2.exponent;
    call :signedAdd _exponent = "%_operand1.exponent.integer%" + "%_operand2.exponent.integer%"
    
    REM Multiply the mantissas, because:
    REM m_1 * 10^r  *  m_2 * 10^s = m_1 * m_2  *  10^r * 10^s
    call :signedMul _mantissa = "%_operand1.mantissa.integer%" * "%_operand2.mantissa.integer%"
    
    REM return both
    set "@return=%_mantissa%E%_exponent%"
goto Finish



:Division
    REM The sign variable is a single flag, where 1 = positive and 0 = negative.
    set /a _sign = 1
    if "%_operand1.mantissa.integer:~0,1%"=="-" set /a "_sign = ^!_sign"
    if "%_operand2.mantissa.integer:~0,1%"=="-" set /a "_sign = ^!_sign"
    
    REM Remove negative sign, because it would show up at each digit.
    set "_operand1.mantissa.integer=%_operand1.mantissa.integer:-=%"
    set "_operand2.mantissa.integer=%_operand2.mantissa.integer:-=%"

    REM Divide the mantissas, because:
    REM ( m_1 * 10^r ) / ( m_2 * 10^s ) = ( m_1 / m_2 ) * ( 10^r / 10^s )
    set /a _int = _operand1.mantissa.integer / _operand2.mantissa.integer
    set "@return=%_int%"
    
    REM By default terminate after a precision of 8 digits.
    if %_precision% equ max (
        set /a _div_precision = 8
    ) else (
        set /a _div_precision = _precision
    )
    
    REM Count the digits of the integer division to get the current precision.
    call :strlen "%@return%"
    set /a _current_precision = %errorlevel%
    
    REM A leading zero does not count for the precision.
    if %@return% equ 0 set /a _current_precision = 0
    
    REM Added decimal places, that need to be compensated by the exponent later on.
    set /a _decP = 0
    
    REM The remainder from the integer division.
    set /a _remainder = _operand1.mantissa.integer - (_int * _operand2.mantissa.integer)

    :div_while
        REM Repeat while the target precision is not reached and there is still a remainder left.
        if %_remainder% NEQ 0 (
            if %_current_precision% LEQ %_div_precision% (
                goto div_do
            )
        )
        goto div_merge
        
        :div_do
            set /a _intR      = (_remainder*10) /          _operand2.mantissa.integer
            set /a _remainder = (_remainder*10) - (_intR * _operand2.mantissa.integer)
            set @return=%@return%%_intR%
            set /a _decP += 1
            set /a _current_precision += 1
    goto div_while
        

    :div_merge
        REM Subtract the exponents, because: a^r / a^s = a^(r-s)
        REM where a = 10; r = operand1.exponent; s = operand2.exponent;
		
        REM i) invert the second exponents sign
        set "_newExponentSign=-"
        if "%_operand2.exponent.integer:~0,1%"=="-" set "_newExponentSign=+"
		call :forceSigns _operand2.exponent.integer
        set "_operand2.exponent.integer=%_newExponentSign%%_operand2.exponent.integer:~1%"
		
        REM ii) add the exponents
        call :signedAdd _exponent = "%_operand1.exponent.integer%" + "%_operand2.exponent.integer%"

        REM Lower the exponent for each added decimal place:
        set /a _decP_shift = -1 * _decP
        call :signedAdd _exponent = "%_exponent%" + "%_decP_shift%"

        REM Set the sign:
        if %_sign% equ 1 (
            set "_sign_string=+"
        ) else (
            set "_sign_string=-"
        )
        
        REM Combine all parts to get the resulting number:
        set "@return=%_sign_string%%@return%E%_exponent%"

goto Finish



:signedAdd VarName %1 = SignedBigInteger %2 + SignedBigInteger %4
    setlocal EnableDelayedExpansion

        set "a=%~2"
        set "b=%~4"
        
        REM If no sign is given explicitly, default to "+":
        call :forceSigns a
        call :forceSigns b
        
        REM Handle all 2^2=4 sign combinations:
        set "signCombination=[%a:~0,1%][%b:~0,1%]"
        
        if "%signCombination%"=="[+][+]" (
            call :unsignedAdd sum = "%a:~1%" + "%b:~1%"
        )
        
        if "%signCombination%"=="[-][-]" (
            call :unsignedAdd sum = "%a:~1%" + "%b:~1%"
            set "sum=-!sum!"
        )
        
        if "%signCombination%"=="[+][-]" (
            call :unsignedSub sum = "%a:~1%" - "%b:~1%"
        )
        
        if "%signCombination%"=="[-][+]" (
            call :unsignedSub sum = "%b:~1%" - "%a:~1%"
        )

    endlocal & set "%~1=%sum%"
exit /b



:unsignedAdd VarName %1 = UnsignedBigInteger %2 + UnsignedBigInteger %4
    setlocal EnableDelayedExpansion
        set /a carry = 0
        set /a index = 1
        
        set "return="
        set "op1=%~2"
        set "op2=%~4"
        
        call :strlen %2
        set /a "op1.len=%errorlevel%"
        call :strlen %4
        set /a "op2.len=%errorlevel%"
        
        REM Exit the loop if index has reached Math.max(operand1.length, operand2.length) + 1
        REM (+1 because of the last carry)
        if %op1.len% GEQ %op2.len% (
            set /a maxIndex = op1.len + 1
        ) else (
            set /a maxIndex = op2.len + 1
        )
        
        :unsignedAdd_while
            REM The current digit is calculated by:
            REM operand1[index] + operand2[index] + carry.
            
            set /a current = carry
            set /a carry = 0
            
            REM If the number has less digits than the current index, it gets ignored.
            if %op1.len% GEQ %index% set /a current += !op1:~-%index%,1!
            if %op2.len% GEQ %index% set /a current += !op2:~-%index%,1!
            
            REM setting the carry:
            if %current% GEQ 10 (
                set /a carry = 1
                set /a current -= 10
            )
            
            REM Adding the current digit to the result:
            set "return=%current%%return%"
            set /a index += 1
            
        if %index% LEQ %maxIndex% goto unsignedAdd_while
    
    endlocal & set "%~1=%return%"
exit /B


:unsignedSub VarName %1 = UnsignedBigInteger %2 - UnsignedBigInteger %4
    setlocal EnableDelayedExpansion
    
        set /a carry = 0
        set /a index = 1
        
        set "return="
        set "op1=%~2"
        set "op2=%~4"
        
        call :strlen %2
        set /a "op1.len=%errorlevel%"
        call :strlen %4
        set /a "op2.len=%errorlevel%"
        
        REM Exit condition of the loop: if index has reached
        REM Math.max(operand1.length, operand2.length) + 1
        REM (+1 because of the last carry)
        if %op1.len% GEQ %op2.len% (
            set /a maxIndex = op1.len + 1
        ) else (
            set /a maxIndex = op2.len + 1
        )
        
        :unsignedSub_while
            REM The current digit is calculated by:
            REM operand1[index] - operand2[index] - carry.
            
            set /a current = -carry
            set /a carry = 0
            
            REM If the number has less digits than the current index, it gets ignored.
            if %op1.len% GEQ %index% set /a current += !op1:~-%index%,1!
            if %op2.len% GEQ %index% set /a current -= !op2:~-%index%,1!
            
            REM Setting the carry:
            if %current% LSS 0 (
                set /a carry = 1
                set /a current += 10
            )
            
            REM Adding the current digit to the result:
            set "return=%current%%return%"
            set /a index += 1
            
        if %index% LEQ %maxIndex% goto unsignedSub_while
        
        :handleNegative
            if %carry% equ 1 (
                set "invbase=1"
                for /L %%i in (1 1 %maxIndex%) do (
                    set "invbase=!invbase!0"
                )
                call :unsignedSub return = "!invbase!" - "%return%"
                set "return=-!return!"
            )

    endlocal & set "%~1=%return%"
exit /B
    

:signedMul VarName %1 = SignedBigInteger %2 * SignedBigInteger %4
    setlocal EnableDelayedExpansion

        set "a=%~2"
        set "b=%~4"
        
        call :forceSigns a
        call :forceSigns b
        
        call :unsignedMul result = "%a:~1%" * "%b:~1%"
        
    endlocal & (
        if "%a:~0,1%"=="%b:~0,1%" (
            set "%~1=+%result%"
        ) else (
            set "%~1=-%result%"
        )
    )
exit /b

:unsignedMul VarName %1 = UnsignedBigInteger %2 * UnsignedBigInteger %4
    setlocal EnableDelayedExpansion
        set "result="
        set "op1=%~2"
        set "op2=%~4"
        set "a_zero="
        
        REM Special cases for 0 and 1:
        if %op1% equ 0 endlocal & set "%~1=0" & exit /b
        if %op2% equ 0 endlocal & set "%~1=0" & exit /b
        if %op1% equ 1 endlocal & set "%~1=%op2%" & exit /b
        if %op2% equ 1 endlocal & set "%~1=%op1%" & exit /b
        
        call :strlen %2
        set /a "op1.lastIndex=%errorlevel% - 1"
        call :strlen %4
        set /a "op2.lastIndex=%errorlevel% - 1"
        
        for /L %%i in (%op1.lastIndex% -1 0) do (
            set "current="
            set "carryj=0"
            
            for /L %%j in (%op2.lastIndex% -1 0) do (
                set /a "currentj=(!op1:~%%i,1! * !op2:~%%j,1!) + !carryj!"
                
                set "carryj=0"
                if !currentj! GEQ 10 (
                    set "carryj=!currentj:~0,1!"
                    set "currentj=!currentj:~1!"
                )
                
                set "current=!currentj!!current!"
            )
            
            call :unsignedAdd result = "!result!" + "!carryj!!current!!a_zero!"
            set "a_zero=!a_zero!0"
        )
        
    endlocal & set "%~1=%result%"
exit /b

:: Returns the length of the given string as exitcode.
:strlen String %1
setlocal EnableDelayedExpansion
    set "s=%~1_"
    set /a len = 0
    for %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
        if "!s:~%%N,1!" NEQ "" ( 
            set /a len += %%N
            set "s=!s:~%%N!"
        )
    )
endlocal & exit /b %len%

:: Adds a plus sign to the given variable's value if it has no sign specified.
:: @param {String} variable name
:forceSigns
    if "!%~1:~0,1!" NEQ "+"  (
    if "!%~1:~0,1!" NEQ "-"  (
        set "%~1=+!%~1!"
    ))
exit /b

:: Adds a plus sign to the given variables value if it has no sign specified and is not zero.
:: Does the same as :forceSigns, but does not change the variable if its value is only zero.
:: @param {String} variable name
:forceSignsExceptZero VarName %1
    if "!%~1:0=!" NEQ "" call :forceSigns "%~1"
exit /b

:: Removes all leading zeros from a signed number while keeping its sign.
:: The first character of the number has to be the sign.
:trimLeadingZeros VarName %1
    for /f "tokens=* delims=0" %%n in ("!%~1:~1!") do set "%~1=!%~1:~0,1!%%n"
exit /b

:storeEchoState
    @echo > "%tmp%\number-cmd-echo-state"
    @find /i "(on)" "%tmp%\number-cmd-echo-state" >nul 2>&1 && (
        set "_echoState=on"
    ) || (
        set "_echoState=off"
    )
    @del "%tmp%\number-cmd-echo-state" 2>nul
@exit /b


:: If the given parameter-text is specifying the precision, it is set.
:readPrecisionParam String %1
    for /f "tokens=1,2* delims=:" %%p in ("%~1") do (
        if /i "%%~p" neq "p" if /i "%%~p" neq "precision" (
            echo.WARNING. Invalid argument, please specify the precision properly.
            exit /b 1
        )
        
        set /a "_castedPrecision=%%~q"
        if !_castedPrecision! gtr 0 (
            set "_precision=!_castedPrecision!"
        )
    )
exit /b


:: Splits the String representation of a number in its parts
:: @param {String} variable name
:decode String %1
    if "!%~1!"=="NaN" exit /b 1
    
    REM check for static constants
    if /i "!%~1:~0,7!"=="Number." (
        REM 2.71828182845904523536028747135266249775724709369995
        if /i "!%~1:~7!"=="e"  set "%~1=+271828182E-8"
        REM 3.141592653589793238462643383279502884197169399375105820974944
        if /i "!%~1:~7!"=="pi" set "%~1=+314159265E-8"
        REM 1.618033988749894848204586834365638117720309179805762862135448
        if /i "!%~1:~7!"=="phi" set "%~1=+161803398E-8"
    )
    
    REM if only E^x is given the mantissa is 1; this is needed here so the for is executed in this case, too
    if /i "!%~1:~0,1!"=="E"  set "%~1=+1!%~1!"
    
    REM splits the number up and sets the variables
    for /F "delims=eE tokens=1,2" %%D in ("!%~1!") do (
    
        REM define mantissa
        set "%~1.mantissa.integer=%%D"
        
        REM if only E^x is given the mantissa is 1
        if /i "!%~1:~0,2!"=="+E" set "%~1.mantissa.integer=+1"
        if /i "!%~1:~0,2!"=="-E" set "%~1.mantissa.integer=-1"
        
        REM if no sign is given and the number is not zero, it's assumed to be positive
        call :forceSignsExceptZero "%~1.mantissa.integer"
        
        REM check for only zeros
        set "%~1.mantissa.integer.abs=!%~1.mantissa.integer:-=!"
        set "%~1.mantissa.integer.abs=!%~1.mantissa.integer.abs:+=!"
        if "!%~1.mantissa.integer.abs:0=!"=="" (
            set "%~1.zero=true"
            set "%~1.mantissa.integer=0"
        ) else (
            call :trimLeadingZeros "%~1.mantissa.integer"
        )
        
        REM define exponent
        set "%~1.exponent.integer=%%E"
        if "%%E"=="" (
            if /i "!%~1:~-1!"=="E" (
                set "%~1.exponent.integer=1"
            ) else (
                set "%~1.exponent.integer=0"
            )
        )
        
        REM If no sign is given the exponent is assumed to be positive.
        call :forceSigns "%~1.exponent.integer"
        
        REM check for only zeros
        set "%~1.exponent.integer.abs=!%~1.exponent.integer:~1!"
        if "!%~1.exponent.integer.abs:0=!"=="" (
            set "%~1.exponent.zero=true"
            set "%~1.exponent.integer=0"
        ) else (
            call :trimLeadingZeros "%~1.exponent.integer"
        )
    )
exit /b 0



:: Optimizes the String representation of a number
:: @param {String} variable name
:optimize String %1
    setlocal EnableDelayedExpansion
        REM splits up the number
        for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
            set "_mantissa=%%D"
            set "_exponent=%%E"
        )
       
       :addPositiveSigns
            REM if mantissa or exponent has no sign, it gets a positive sign:
            REM (zero treatment is done afterwards anyways, so there is no need for extra checks.)
            call :forceSigns _mantissa
            call :forceSigns _exponent
       
       :zeroTreatment
            set "_mantissa.abs=%_mantissa:~1%"
            set "_exponent.abs=%_exponent:~1%"

            REM In case the mantissa is zero, it makes sense if the exponent is also zero.
            if "%_mantissa.abs:0=%"=="" (
                REM no further optimization needed
                endlocal & set "%~1=0E0"
                exit /b 0
            )

            REM deal with exponent consisting of multiple zeros:
            if "%_exponent.abs:0=%"=="" (
                set "_exponent=0"
            )
       
       :removeLeadingZerosFromMantissa
            if "%_mantissa:~1,1%"=="0" (
                set "_mantissa=%_mantissa:~0,1%%_mantissa:~2%"
                goto removeLeadingZerosFromMantissa
            )
           
       :removeLeadingZerosFromExponent
            if "%_exponent:~1,1%"=="0" (
                set "_exponent=%_exponent:~0,1%%_exponent:~2%"
                goto removeLeadingZerosFromExponent
            )

       :removeTrailingZeros
            REM Removes the last zero and increases the exponent:
            if "%_mantissa:~-1%"=="0" (

                REM Important: Using set /a at this point destroys formatting like adding a plus sign and
                REM            could cause strange behaviour if redundant leading zeros are not removed so
                REM            that the exponent gets treated as octal number.
                set /a _exponent += 1

                set "_mantissa=%_mantissa:~0,-1%"

                REM next iteration of the do-while-loop, which stops at the first non-zero value
                goto removeTrailingZeros
            )
            
        :adjustPrecision
            REM Make no adjustments if the precision should be as high as possible.
            if %_precision% equ max goto reenforceExponentSign
        
            REM The precision is the amount of digits. (1 character is the sign).
            call :strlen "%_mantissa%"
            set /a _current_precision = %errorlevel% - 1
            
            :reducePrecision
            REM Reduce the precision value and then remove the last digit. 
            REM This way it can be decided if rounding is necessary or not.
            set /a _current_precision -= 1

            if %_current_precision% GEQ %_precision% (
                REM Increase the exponent to multiply the number by 10 while removing the last digit.
                set /a _exponent += 1
                set "_lastdigit=%_mantissa:~-1,1%"
                set "_mantissa=%_mantissa:~0,-1%"
                
                REM If the precisions do not match, continue with the reduction.
                if %_current_precision% NEQ %_precision% goto reducePrecision
                
                REM Round up, if the cut-off digit was greater than 5.
                if "!_lastdigit!" geq "5" (
                    call :unsignedAdd tmp_mantissa = !_mantissa:~1! + 1
                    set "_mantissa=!_mantissa:~0,1!!tmp_mantissa!"
                    set "tmp_mantissa="
                )
                
                REM Redo the optimizations after the number was changed.
                goto zeroTreatment
            )
        
        :reenforceExponentSign
        REM Re-enforce the sign after the usage of set /a.
        call :forceSignsExceptZero _exponent
       
    REM combines the number again
    endlocal & set "%~1=%_mantissa%E%_exponent%"
exit /b


:Finish
    call :optimize @return
    
    REM output result only when requested by '#' as variable name
    if "%_variable%"=="#" echo.%@return%
    
    REM restore echo state
    echo %_echoState%
    
    @endlocal &(
        REM altering variable
        set "%_variable%=%@return%"
    )
@exit /B 0
