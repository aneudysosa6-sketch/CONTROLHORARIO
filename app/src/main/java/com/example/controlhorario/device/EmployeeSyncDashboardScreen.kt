package com.example.controlhorario.device

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.text.DateFormat
import java.util.Date

@Composable fun EmployeeSyncDashboardScreen(viewModel:EmployeeSyncDashboardViewModel,onSync:()->Unit,onBack:()->Unit){
 val state by viewModel.state.collectAsState()
 Column(Modifier.fillMaxSize().padding(24.dp),verticalArrangement=Arrangement.Center){
  Text("Empleados sincronizados",style=MaterialTheme.typography.headlineMedium)
  Spacer(Modifier.height(20.dp))
  Card(Modifier.fillMaxWidth()){
   Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
    Text("Total descargados: ${state.total}",style=MaterialTheme.typography.titleMedium)
    Text("Activos: ${state.active}")
    Text("Inactivos: ${state.inactive}")
    Text("Última sincronización: ${state.lastSyncAt?.let{DateFormat.getDateTimeInstance().format(Date(it))}?:"Nunca"}")
   }
  }
  Spacer(Modifier.height(20.dp))
  Button(onClick=onSync,modifier=Modifier.fillMaxWidth()){Text("Sincronizar ahora")}
  Spacer(Modifier.height(12.dp))
  OutlinedButton(onClick=onBack,modifier=Modifier.fillMaxWidth()){Text("Volver")}
 }
}
