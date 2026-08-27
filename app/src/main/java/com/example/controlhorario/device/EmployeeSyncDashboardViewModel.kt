package com.example.controlhorario.device

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.DeviceEnrollmentDao
import com.example.controlhorario.database.EmployeeDao
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

data class EmployeeSyncDashboardState(val total:Int=0,val active:Int=0,val inactive:Int=0,val lastSyncAt:Long?=null)

class EmployeeSyncDashboardViewModel(employeeDao:EmployeeDao,enrollmentDao:DeviceEnrollmentDao):ViewModel(){
 val state=combine(employeeDao.observeSyncedTotal(),employeeDao.observeSyncedActive(),employeeDao.observeSyncedInactive(),enrollmentDao.observeCurrent()){total,active,inactive,enrollment->
  EmployeeSyncDashboardState(total,active,inactive,enrollment?.lastEmployeeSyncAt)
 }.stateIn(viewModelScope,SharingStarted.WhileSubscribed(5_000),EmployeeSyncDashboardState())
}

class EmployeeSyncDashboardViewModelFactory(private val employeeDao:EmployeeDao,private val enrollmentDao:DeviceEnrollmentDao):ViewModelProvider.Factory{
 @Suppress("UNCHECKED_CAST") override fun<T:ViewModel>create(modelClass:Class<T>):T=EmployeeSyncDashboardViewModel(employeeDao,enrollmentDao) as T
}
