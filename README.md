# Number.cmd
A new data type for Batch, that can represent large & floating-point numbers and can calculate with those.

# Syntax
```
command  = "Number.cmd ",variable," = ",number," ",operator," ",number;
variable = ("a"|"b"|...|"z"),[variable];
operator = "+"|"-"|"*"|"/";

number   = (integer,"E",integer)|"NaN";
integer  = (sign,digits)|"0";
sign     = "+"|"-";
digits   = ("0"|"1"|...|"9"),[digits];
```
