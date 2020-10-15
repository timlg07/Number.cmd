@setlocal enableDelayedExpansion
@call :storeEchoState
@echo off


:main
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

    REM Now both exponents are equal and the addition can be started.
    call :signedAdd sum = "%_operand1.mantissa.integer%" + "%_operand2.mantissa.integer%"
    
    REM save result
    set "@return=!sum!E%_operand1.exponent.integer%"

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
    call :signedAdd _exponent = "%_operand1.exponent.integer%" + "%_operand2.exponent.integer%"
    REM multiply the mantissas, because:
    REM m_1 * 10^r  *  m_2 * 10^s <=> m_1 * m_2  *  10^r * 10^s
    call :signedMul _mantissa = "%_operand1.mantissa.integer%" * "%_operand2.mantissa.integer%"
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
    if %@return% equ 0 set "@return="
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
    REM i) invert the second exponents sign
    set "_newExponentSign=+"
    if "%_operand2.exponent.integer:~0,1%"=="+" set "_newExponentSign=-"
    set "_operand2.exponent.integer=%_newExponentSign%%_operand2.exponent.integer:~1%"
    REM ii) add the exponents
    call :signedAdd _exponent = "%_operand1.exponent.integer%" + "%_operand2.exponent.integer%"
    REM lower the exponent for each added decimal place
    call :signedAdd _exponent = "%_exponent%" + "-%_decP%"
    REM set sign
    set /a @return *= _sign
    REM return
    set @return=%@return%E%_exponent%

goto Finish



:signedAdd <VarName>%1 = <SignedBigInteger>%2 + <SignedBigInteger>%4
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



:unsignedAdd <VarName>%1 = <UnsignedBigInteger>%2 + <UnsignedBigInteger>%4
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
        
        REM exit condition for the loop: if index has reached
        REM Math.max( operand1.length, operand2.length ) + 1
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
            
            REM adding the current digit:
            set "return=%current%%return%"
            set /a index += 1
            

        if %index% LEQ %maxIndex% goto unsignedAdd_while
    
    endlocal & set "%~1=%return%"
exit /B
    




:unsignedSub <VarName>%1 = <UnsignedBigInteger>%2 - <UnsignedBigInteger>%4
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
        
        REM exit condition for the loop: if index has reached
        REM Math.max( operand1.length, operand2.length ) + 1
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
            
            REM setting the carry:
            if %current% LSS 0 (
                set /a carry = 1
                set /a current += 10
            )
            
            REM adding the current digit:
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
    

:signedMul <VarName>%1 = <SignedBigInteger>%2 * <SignedBigInteger>%4
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

:unsignedMul <VarName>%1 = <UnsignedBigInteger>%2 * <UnsignedBigInteger>%4
    setlocal EnableDelayedExpansion
        set "result="
        set "op1=%~2"
        set "op2=%~4"
        set "a_zero="
        
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


:strlen <String>%1
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

:: Adds a plus sign to the given variables value if it has no sign specified.
:: @param {String} variable name
:forceSigns <VarName>%1 <Boolean>%2
    if "!%~1:~0,1!" NEQ "+"  (
    if "!%~1:~0,1!" NEQ "-"  (
        set "%~1=+!%~1!"
    ))
exit /b

:: Adds a plus sign to the given variables value if it has no sign specified and is not zero.
:: Does the same as :forceSigns, but does not change the variable if its value is only zero.
:: @param {String} variable name
:forceSignsExceptZero <VarName>%1
    if "!%~1:0=!" NEQ "" call :forceSigns "%~1"
exit /b

:: Removes all leading zeros from a signed number while keeping its sign.
:: The first character of the number has to be the sign.
:trimLeadingZeros <VarName>%1
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
        REM 1.618033988749894848204586834365638117720309179805762862135448 -> INT32
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
        
        REM if no sign is given and the number is not zero, it's assumed to be positive
        call :forceSignsExceptZero "%~1.exponent.integer"
        
        REM check for only zeros
        set "%~1.exponent.integer.abs=!%~1.exponent.integer:-=!"
        set "%~1.exponent.integer.abs=!%~1.exponent.integer.abs:+=!"
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
:optimize <String>%1
    setlocal EnableDelayedExpansion
       REM splits up the number
       for /F "delims=E tokens=1,2" %%D in ("!%~1!") do (
           set "_mantissa=%%D"
           set "_exponent=%%E"
       )
       set "_mantissa.abs=%_mantissa:-=%"
       set "_mantissa.abs=%_mantissa.abs:+=%"
       set "_exponent.abs=%_exponent:-=%"
       set "_exponent.abs=%_exponent.abs:+=%"
       
       :zeroTreatment
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
       
       :removeTrailingZeros
           REM removes the last zero and increases the exponent
           if "%_mantissa:~-1%"=="0" (
               set /a _exponent += 1
               set "_mantissa=%_mantissa:~0,-1%"
               REM next iteration of the do-while-loop, which stops at the first non-zero value
               goto removeTrailingZeros
           )
       
       :addPositiveSigns
           REM if mantissa has no sign, it gets a positive sign
           if "%_mantissa.abs%"=="%_mantissa%" (
               set "_mantissa=+%_mantissa%"
           )
           
           REM if exponent is not zero and has no sign, it gets a positive sign
           if not "%_exponent%"=="0"  (
           if "%_exponent.abs%"=="%_exponent%" (
               set "_exponent=+%_exponent%"
           ))
           
       :removeLeadingZerosFromMantissa
           if "%_mantissa:~1,1%"=="0" (
               set "_mantissa=%_mantissa:~0,1%%_mantissa:~2%"
               goto removeLeadingZerosFromMantissa
           )
           
       :removeLeadingZerosFromExponent
           if not "%_exponent%"=="0" (
               if "%_exponent:~1,1%"=="0" (
                   set "_exponent=%_exponent:~0,1%%_exponent:~2%"
                   goto removeLeadingZerosFromExponent
               )
           )
       
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
