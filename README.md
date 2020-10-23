# Number.cmd
A new data type for Batch, that can represent large and floating-point numbers and enables calculation with those.

# Syntax
The basic syntax of Number.cmd looks like this:
```
Number <variable-name> = <operand1> <operator> <operand2>
```
with: 
- `<variable-name>` being the plain string of the batch variable that should be set.
- `<operand1>` and `<operand2>` being the two operands of the calculation. They can be either normal integers or numbers in the internally used notation with mantissa and exponent, seperated by an `E`. For example the number `1,23` would be `123E-2` in this notation. If you want, you can write normal integers in this notation as well: `1200` for example would be `12E2`.  
The operands can also be constants like `Number.pi` or `Number.e`.
- `<operator>` should be one of the following mathematical operators: `+`, `-`, `*`, `/`.  

# Examples
```cmd
Number x = 4 + 48
Number x = %x% * -E5
Number y = 50E5 + 2E5
Number result = %x% + %y%
```
Note: In batch files you have to `call Number` to continue execution.

# Exitcodes
```
 0: Success
 1: First operand is not a number (NaN)
 2: Second operand is not a number (NaN)
 3: Unknown operator
 4: Missing parameter(s)
```

# Standard Output
Number.cmd does not write anything to standard output (stdout) by default. If you want the result to be printed, for example when using Number.cmd directly in cmd, you can use `#` instead of a variable-name with an equal-sign.  
The following command for example will output "+8E-1" to the standard output stream:
```cmd
Number # 4 / 5
```
