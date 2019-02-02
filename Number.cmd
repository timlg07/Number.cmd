@echo off
set "significand=00000000000000000000000000001111"
set "sign=11"
set "exponent=00000000"
call :add "%significand%" "%significand%" 32
echo %@return%
pause&exit

:add n1<bin> n2<bin> length<int>
    setlocal enableDelayedExpansion
        set "n1=%~1"        first number
        set "n2=%~2"        second number
        set "i0=1"          index
        set "r0="           result
        set "cr=0"          current remainder

    :_add_loop
        set "c_n1=!n1:~-%i0%,1!"    current digit of first number
        set "c_n2=!n2:~-%i0%,1!"    current digit of second number
        set "rc=0"                  current result

        if %i0% gtr %~3 (
            endlocal & set "@return=%r0%" & exit /B 0
        )

        set /a "rc  = c_n1 ^ c_n2 ^ cr"
        set /a "cr += c_n1 + c_n2 - rc"

        set "r0=%rc%%r0%"
        if %cr% equ 2 set "cr=1"

        set /a "i0 += 1"
    goto _add_loop
