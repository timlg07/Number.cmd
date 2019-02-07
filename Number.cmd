@echo off & setlocal enableDelayedExpansion

:MAIN params<>

    set "var_name=%~1"
    set "operand_0=%~2"
    set "operator=%~3"
    set "operand_1=%~4"

    if not defined operand_0 goto SYNTAX

    if "%operator%"=="+" goto ADD

goto SET

:SYNTAX
    echo.Syntax error.
exit /B 1

:ADD
    if not defined operand_1 goto SYNTAX
exit /B 0


:SET
    for /F "tokens=1,2 delims=Ee" %%D in ("%operand_0%") do (
        set "_d=%%D"
        set "_e=%%E"
    )

    if not defined _e set /a _e = 0

    for /F "tokens=1,2 delims=." %%A in ("%_d%") do (
        set "_d.a=%%A"
        set "_d.b=%%B"
    )
    set "_d.s=0"
    if "%_d.a:~0,1%"=="-" (
        set "_d.s=1"
        set "_d.a=%_d.a:~1%"
    )
    cmd /K "exit /B %_d.a%"
    set "_d.a=%errorlevel%"
    if %_d.a% equ 0 set "_d.a="

    :set_while_0
    if defined _d.b (
        set "_d.a=%_d.a%!_d.b:~0,1!"
        set "_d.b=!_d.b:~1!"
        set /a _e -= 1
        goto set_while_0
    )

    set "_e.s=0"
    if %_e% lss 0 (
        set "_e.s=1"
        set "_e=%_e:~1%"
    )

    if not defined _d.a set "_d.a=0"

    call :save %var_name% %_d.s% %_d.a% %_e.s% %_e%
exit /B 0


:SAVE
    md "%TMP%\numbers\" >nul 2>&1
    echo.%~2_%~3_%~4_%~5>%TMP%\numbers\%~1.num
exit /B 0
