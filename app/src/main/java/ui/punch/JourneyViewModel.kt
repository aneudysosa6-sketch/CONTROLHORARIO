package com.example.controlhorario.ui.punch

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.attendance.AttendanceSyncScheduler
import com.example.controlhorario.database.JourneyEntity
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.JourneyRepository
import com.example.controlhorario.security.DeviceIdentityManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant

class JourneyViewModel(private val context:Context,private val repository:JourneyRepository,employeeId:Int,workDate:String):ViewModel(){
 val journey:StateFlow<JourneyEntity?> = repository.observe(employeeId,workDate).stateIn(viewModelScope,SharingStarted.WhileSubscribed(5000),null)
 val busy=MutableStateFlow(false);val error=MutableStateFlow("")
 fun record(employee:Employee,workDate:String,action:JourneyAction,onSaved:()->Unit){if(busy.value)return;busy.value=true;error.value="";viewModelScope.launch{runCatching{
   val remoteId=requireNotNull(employee.remoteId){"Empleado pendiente de sincronización remota."};val deviceId=requireNotNull(DeviceIdentityManager(context).deviceId){"Dispositivo no enrolado."}
   repository.recordAction(employee.id,remoteId,employee.nombre,deviceId,workDate,Instant.now().toString(),action,employee.jornadaEnabled)
  }.onSuccess{AttendanceSyncScheduler.enqueue(context);onSaved()}.onFailure{error.value=when(it.message){"ATTENDANCE_DISABLED"->"Tu registro de jornada está deshabilitado.";"ALREADY_FINALIZED"->"La jornada de hoy ya fue finalizada.";else->it.message?:"No fue posible registrar la jornada."}};busy.value=false}}
}

class JourneyViewModelFactory(private val context:Context,private val repository:JourneyRepository,private val employeeId:Int,private val workDate:String):ViewModelProvider.Factory{
 @Suppress("UNCHECKED_CAST") override fun<T:ViewModel>create(modelClass:Class<T>):T=JourneyViewModel(context.applicationContext,repository,employeeId,workDate)as T
}
