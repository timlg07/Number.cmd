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

    REM Check for additional parameters and parse them if provided.
    :readParams
    if "%~5" neq "" (
        call :readPrecisionParam "%~5" || call :readFormatParam "%~5"
        shift
        goto readParams
    )

    REM Overwrite the precision if given differently from the format parameter.
    if "%_format.active%"=="true" if defined _format.a if defined _format.b (
        set /a _precision = _format.a + _format.b
    )

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
    @set "_es_filename=%tmp%\number-cmd-echo-state-"
    :storeEchoState_findUniqueFilename
    @set "_es_filename=%_es_filename%%random%"
    @if exist "%_es_filename%" goto storeEchoState_findUniqueFilename
    @echo > "%_es_filename%"
    @find /i "(on)" "%_es_filename%" >nul 2>&1 && (
        set "_echoState=on"
    ) || (
        set "_echoState=off"
    )
    @del "%_es_filename%" 2>nul
@exit /b


:: If the given parameter-text is specifying the precision, it is set.
:: If the parameter is not meant to contain precision information, the errorcode 1 is returned.
:readPrecisionParam String %1
setlocal
    for /f "tokens=1,2* delims=:" %%p in ("%~1") do (
        if /i "%%~p" neq "p" if /i "%%~p" neq "precision" (
            endlocal
            exit /b 1
        )
        
        set /a "_castedPrecision=%%~q"
        if !_castedPrecision! gtr 0 (
            set "_precision=!_castedPrecision!"
        ) else (
            echo Warning: Invalid precision, the precision must be higher than zero. >&2
            endlocal
            exit /b 0
        )
    )
endlocal & set "_precision=%_precision%"
exit /b 0

:: If the given parameter-text is specifying an output format, it is set.
:: If the parameter is not meant to contain format specifications, the errorcode 1 is returned.
:readFormatParam String %1
setlocal
    for /f "tokens=1,2* delims=:" %%f in ("%~1") do (
        if /i "%%~f" neq "f" if /i "%%~f" neq "format" (
            endlocal
            exit /b 1
        )

        set "_format=%%~g"
        set "_format.active=false"
        set "_format.delim="
        set "_format.a="
        set "_format.b="
        set "_format.showPlusSign=default"
    )
    
    REM Set the plus sign flag if requested.
    if "%_format:~0,1%"=="+" (
        set "_format.showPlusSign=true"
        set "_format=%_format:~1%"
    )

    :iterateFormatString
        REM Exit the loop if the whole format string was parsed.
        if "%_format%"=="" (
            if defined _format.delim (
                if "%_format.a%"=="0" if "%_format.b%"=="0" (
                    echo Warning: Invalid format, the combined amount of digits cannot be zero. >&2
                    endlocal
                    exit /b 0
                )
                endlocal & (
                    set "_format.active=true"
                    set "_format.a=%_format.a%"
                    set "_format.b=%_format.b%"
                    set "_format.delim=%_format.delim%"
                    set "_format.showPlusSign=%_format.showPlusSign%"
                )
                exit /b 0
            ) else (
                REM Every format must at least specify a delimeter as floating point.
                echo Warning: Incorrect format string, no floating point symbol provided. >&2
                endlocal
                exit /b 0
            )
        )

        set "current="
        :: Simply parsing the current character with set /a is not possible here, because characters
        :: like "," or "/" have a special meaning and would give a missing operand exception.
        echo."%_format:~0,1%" | findstr /r "\"[0-9]\"">nul && set "current=%_format:~0,1%"

        if not defined current (
            if defined _format.delim (
                echo Warning: Incorrect format string, unexpected "%_format:~0,1%". >&2
                endlocal
                exit /b 0
            ) else (
                set "_format.delim=%_format:~0,1%"
                set "_format=%_format:~1%"
                goto iterateFormatString
            )
        )

        if defined _format.delim (
            set "_format.b=%_format.b%%current%"
        ) else (
            set "_format.a=%_format.a%%current%"
        )
        
        set "_format=%_format:~1%"
    goto iterateFormatString


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


:enforceOutputFormat String %1
if not "%_format.active%"=="true" exit /b 1
setlocal

    REM Split the number in sign, mantissa and exponent.
    for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
        set "_mantissa=%%D"
        set "_exponent=%%E"
    )

    if "%_mantissa%" neq "0" (
        set "_sign=%_mantissa:~0,1%"
        set "_mantissa=%_mantissa:~1%"
    ) else (
        REM Add a plus sign even if the number is zero.
        if "%_format.showPlusSign%"=="true" (
            set "_sign=+"
        )
    )

    REM Decide whether to show or hide the sign.
    if "%_format.showPlusSign%" neq "true" if "%_sign%"=="+" (
        set "_sign="
    )

    REM Count the digits of the mantissa to get the actual precision.
    call :strlen "%_mantissa%"
    set /a _actual_precision = %errorlevel%

    REM If required and possible, set the dynamic format option depending 
    REM on the other format option and the actual-precision.
    if defined _format.a (
        if not defined _format.b (
            set /a _format.b = _actual_precision - _format.a
            if !_format.b! lss 0 set /a _format.b = 0
        )
    ) else (
        if defined _format.b (
            set /a _format.a = _actual_precision - _format.b
            if !_format.a! lss 0 set /a _format.a = 0
        ) else (
            REM Special case: completely dynamic formatting without exponent output.
            goto adjustFormatPerExponent
        )
    )

    REM If actual_precision < requested_precision, append trailing zeros until both precisions are equal.
    set /a _precisionDelta = _format.a + _format.b - _actual_precision
    for /l %%i in (1 1 !_precisionDelta!) do set "_mantissa=!_mantissa!0"
    set /a _exponent -= _precisionDelta
    
    REM Split up the mantissa in the first and second part.
    set "_mantissa.a=!_mantissa:~0,%_format.a%!"
    set "_mantissa.b=!_mantissa:~%_format.a%,%_format.b%!"

    REM The floating delimiter is omitted if actual-precision = format.a, 
    REM but not if actual-precision = format.b, where the first part is represented as a zero.
    if "%_mantissa.a%"=="" set "_mantissa.a=0"
    if "%_mantissa.b%"=="" set "_format.delim="

    REM Increase the exponent as format.b digits are pulled to the right of the floating point.
    set /a _exponent += _format.b

    REM Special case: Exponent can and should be zero, if the whole number is zero.
    if "%_mantissa:0=%"=="" set /a _exponent = 0

endlocal & set "%~1=%_sign%%_mantissa.a%%_format.delim%%_mantissa.b%E%_exponent%"
exit /b

:adjustFormatPerExponent
    REM Case 1: Positive exponent => Add zeros and display only part A.
    if %_exponent% gtr 0 (
        for /l %%i in (1 1 %_exponent%) do set "_mantissa=!_mantissa!0"
        set /a _exponent = 0
    )

    REM Case 2: Negative exponent => Move the last (-1 * _exponent) digits from part A to part B.
    call :strlen "%_mantissa%"
    set /a _mantissaLength = %errorlevel%
    if %_exponent% lss 0 (
        REM Append additional leading zeros if necessary.
        set /a "_missingDecimals = -1 * (_exponent + _mantissaLength)"
        for /l %%i in (1 1 !_missingDecimals!) do set "_mantissa=0!_mantissa!"

        set "_mantissa.a=!_mantissa:~0,%_exponent%!"
        set "_mantissa.b=!_mantissa:~%_exponent%!"
        set /a _exponent = 0
        set "_split=true"
    )

    REM Case 3 & final behaviour for all cases: exponent == 0 and gets omited.
    if %_exponent% equ 0 (
        if defined _split (
            if "%_mantissa.a%"=="" set "_mantissa.a=0"
            set "_r=%_sign%!_mantissa.a!%_format.delim%%_mantissa.b%"
        ) else (
            set "_r=%_sign%%_mantissa%"
        )
    )
endlocal & set "%~1=%_r%"
exit /b


:Finish
    call :optimize @return
    call :enforceOutputFormat @return
    
    REM output result only when requested by '#' as variable name
    if "%_variable%"=="#" echo.%@return%
    
    REM restore echo state
    echo %_echoState%
    
    @endlocal &(
        REM altering variable
        set "%_variable%=%@return%"
    )
@exit /B 0
