@cd ..

call Number x = 4 + 48
call Number x = %x% * -E5
call Number y = 50E5 + 2E5
call Number result = %x% - %y% 
call Number result = %result% / 3000 
call Number result = %result% + 4 "f:."

echo result: %result%

@pause