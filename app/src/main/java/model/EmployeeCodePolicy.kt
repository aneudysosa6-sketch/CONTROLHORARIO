package com.example.controlhorario.model

object EmployeeCodePolicy{
 const val LENGTH=5
 const val ERROR="El código debe contener exactamente 5 dígitos."
 fun sanitizeInput(value:String)=value.filter(Char::isDigit).take(LENGTH)
 fun isValid(value:String)=value.length==LENGTH&&value.all(Char::isDigit)
 fun append(current:String,digit:String)=if(digit.length==1&&digit[0].isDigit())sanitizeInput(current+digit)else current
}
