package com.example.controlhorario.engine

import java.time.Duration
import java.time.Instant

data class JourneyIncidentEvaluation(val type:String,val severity:String,val minutes:Int)
object JourneyIncidentEngine{
 const val LATE_TOLERANCE_MINUTES=15
 fun evaluateLate(expectedAt:String?,actualAt:String):JourneyIncidentEvaluation?{if(expectedAt.isNullOrBlank())return null;val minutes=runCatching{Duration.between(Instant.parse(expectedAt),Instant.parse(actualAt)).toMinutes().toInt()}.getOrNull()?:return null;return if(minutes>=LATE_TOLERANCE_MINUTES)JourneyIncidentEvaluation("TARDANZA","MEDIA",minutes)else null}
}
