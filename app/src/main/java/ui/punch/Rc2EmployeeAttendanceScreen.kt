package com.example.controlhorario.ui.punch

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.engine.JourneyStateEngine
import com.example.controlhorario.engine.JourneyStatus
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import java.time.LocalDate

@Composable
fun Rc2EmployeeAttendanceScreen(employee:Employee?,viewModel:JourneyViewModel,onFinish:()->Unit){
 BackHandler(onBack=onFinish);val journey by viewModel.journey.collectAsState();val busy by viewModel.busy.collectAsState();val error by viewModel.error.collectAsState();val status=journey?.status?.let{runCatching{JourneyStatus.valueOf(it)}.getOrNull()}?:JourneyStatus.SIN_INICIAR;val allowed=JourneyStateEngine.allowedActions(status)
 OSINETScreen{OSINETHeader("Registrar jornada","Selecciona una acción permitida");Spacer(Modifier.height(18.dp));OSINETCard{Text(employee?.nombre?:"Empleado no encontrado",color=OSINETColors.TextPrimary,fontWeight=FontWeight.SemiBold);Text("Estado actual: ${statusLabel(status)}",color=OSINETColors.GreenSoft);Text("Trabajado: ${journey?.workedMinutes?:0} min · Pausa: ${journey?.breakMinutes?:0} min",color=OSINETColors.TextSecondary)};Spacer(Modifier.height(14.dp));Text(if(status==JourneyStatus.FINALIZADA)"La jornada de hoy ya fue finalizada." else "Huella verificada. Registra una sola acción.",color=OSINETColors.TextSecondary,textAlign=TextAlign.Center,modifier=Modifier.fillMaxWidth());Spacer(Modifier.height(18.dp))
  actionButton("Iniciar Jornada",JourneyAction.INICIAR,allowed,busy,employee,viewModel,onFinish);Spacer(Modifier.height(10.dp));actionButton("Pausar Jornada",JourneyAction.PAUSAR,allowed,busy,employee,viewModel,onFinish);Spacer(Modifier.height(10.dp));actionButton("Reanudar Jornada",JourneyAction.REANUDAR,allowed,busy,employee,viewModel,onFinish);Spacer(Modifier.height(10.dp));actionButton("Finalizar Jornada",JourneyAction.FINALIZAR,allowed,busy,employee,viewModel,onFinish)
  if(error.isNotBlank()){Spacer(Modifier.height(12.dp));Text(error,color=OSINETColors.Warning,textAlign=TextAlign.Center)};Spacer(Modifier.height(18.dp));OSINETSecondaryButton("Cancelar",onFinish)
 }
}
@Composable private fun actionButton(text:String,action:JourneyAction,allowed:Set<JourneyAction>,busy:Boolean,employee:Employee?,viewModel:JourneyViewModel,onFinish:()->Unit)=OSINETButton(text,{employee?.let{viewModel.record(it,LocalDate.now().toString(),action,onFinish)}},enabled=employee!=null&&!busy&&action in allowed)
private fun statusLabel(status:JourneyStatus)=when(status){JourneyStatus.SIN_INICIAR->"SIN INICIAR";JourneyStatus.EN_CURSO->"EN CURSO";JourneyStatus.EN_PAUSA->"EN PAUSA";JourneyStatus.FINALIZADA->"FINALIZADA"}
