package com.example.controlhorario.ui.punch

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.attendance.AttendanceSyncScheduler
import com.example.controlhorario.database.JourneyEntity
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.JourneyRepository
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.BuildConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant

class JourneyViewModel(
 private val context:Context,
 private val repository:JourneyRepository,
 private val employeeId:Int,
 workDate:String
):ViewModel(){
 val journey:StateFlow<JourneyEntity?> = repository.observe(employeeId,workDate).stateIn(viewModelScope,SharingStarted.WhileSubscribed(5000),null)
 val busy=MutableStateFlow(false)
 val error=MutableStateFlow("")
 private val identity=DeviceIdentityManager(context)
 val isPunchAuthorized=MutableStateFlow(currentAuthorization())

 fun refreshAuthorization(){isPunchAuthorized.value=currentAuthorization()}

 fun record(employee:Employee,workDate:String,action:JourneyAction,onSaved:()->Unit){
  if(busy.value)return
  val deviceId=identity.deviceId
  val authorized=deviceId!=null&&JourneyBiometricGate.isAuthorized(employee.id,deviceId)
  isPunchAuthorized.value=authorized
  logAuth(employee.id,authorized,action)
  if(!authorized){
   error.value="Debe verificar PIN y rostro antes de cada acción."
   return
  }
  busy.value=true
  error.value=""
  viewModelScope.launch{
   var proof:JourneyBiometricProof?=null
   runCatching{
    val remoteId=requireNotNull(employee.remoteId){"Empleado pendiente de sincronizacion remota."}
    val safeDeviceId=requireNotNull(deviceId){"Dispositivo no enrolado."}
    proof=requireNotNull(JourneyBiometricGate.prepareProof(employee.id,safeDeviceId,action)){"BIOMETRIC_PROOF_REQUIRED"}
    val signature=identity.sign("${proof!!.id}|$remoteId|$safeDeviceId|${action.name}|${proof!!.issuedAt}|${proof!!.expiresAt}".toByteArray())
    repository.recordAction(employee.id,remoteId,employee.employeeCode,employee.nombre,safeDeviceId,employee.remoteBranchId,employee.remoteDepartmentId,workDate,Instant.now().toString(),action,employee.jornadaEnabled,proof!!,signature)
   }.onSuccess{localResult->
    val consumed=JourneyBiometricGate.consumeAfterSuccess(requireNotNull(proof).id)
    isPunchAuthorized.value=false
    if(BuildConfig.DEBUG)Log.d("PUNCH_SAVE","employeeId=${employee.id} action=${action.name} localRecordId=${localResult.journey.localId} outboxId=${localResult.outboxId} status=${localResult.journey.status} timestamp=${localResult.journey.updatedAt} syncStatus=${localResult.journey.syncStatus}")
    logAction(employee.id,action,"saved authorizationConsumed=$consumed")
    AttendanceSyncScheduler.enqueue(context)
    onSaved()
   }.onFailure{
    isPunchAuthorized.value=currentAuthorization()
    logAction(employee.id,action,"failed type=${it.javaClass.simpleName}")
    error.value=when(it.message){"ATTENDANCE_DISABLED"->"Tu registro de jornada esta deshabilitado.";"ALREADY_FINALIZED"->"La jornada de hoy ya fue finalizada.";"BIOMETRIC_PROOF_REQUIRED"->"Debe verificar PIN y rostro antes de cada acción.";else->it.message?:"No fue posible registrar la jornada."}
   }
   busy.value=false
  }
 }

 private fun currentAuthorization():Boolean{
  val deviceId=identity.deviceId?:return false
  return JourneyBiometricGate.isAuthorized(employeeId,deviceId)
 }

 private fun logAuth(targetEmployeeId:Int,authorized:Boolean,action:JourneyAction?=null){
  if(BuildConfig.DEBUG)Log.d("PUNCH_AUTH","employeeId=$targetEmployeeId pinVerified=true faceVerified=$authorized authorizedEmployeeId=$employeeId authorizationConsumed=${!authorized} isPunchAuthorized=$authorized action=${action?.name.orEmpty()}")
 }

 private fun logAction(targetEmployeeId:Int,action:JourneyAction,result:String){
  if(BuildConfig.DEBUG)Log.d("PUNCH_ACTION","employeeId=$targetEmployeeId action=${action.name} result=$result")
 }
}

class JourneyViewModelFactory(private val context:Context,private val repository:JourneyRepository,private val employeeId:Int,private val workDate:String):ViewModelProvider.Factory{
 @Suppress("UNCHECKED_CAST") override fun<T:ViewModel>create(modelClass:Class<T>):T=JourneyViewModel(context.applicationContext,repository,employeeId,workDate)as T
}
