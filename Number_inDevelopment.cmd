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
