package com.example.controlhorario.device
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import android.util.Log
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.database.DeviceEnrollmentEntity
import com.example.controlhorario.security.DeviceIdentityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable fun DeviceEnrollmentScreen(onReady:()->Unit){val context=LocalContext.current;val scope=rememberCoroutineScope();var code by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf("")};val identity=remember{DeviceIdentityManager(context)};val enrollmentEndpoint=stringResource(R.string.device_enrollment_url);val employeeSyncEndpoint=stringResource(R.string.employee_sync_url)
 Column(Modifier.fillMaxSize().padding(24.dp),verticalArrangement=Arrangement.Center,horizontalAlignment=Alignment.CenterHorizontally){Text("Registrar dispositivo",style=MaterialTheme.typography.headlineMedium);Spacer(Modifier.height(8.dp));Text("Ingresa el código temporal generado desde el panel OSINET.");Spacer(Modifier.height(24.dp));if(identity.deviceId==null)OutlinedTextField(code,{code=it.filter(Char::isLetterOrDigit).uppercase().take(16)},Modifier.fillMaxWidth(),label={Text("Código temporal")},singleLine=true,keyboardOptions=KeyboardOptions(capitalization=KeyboardCapitalization.Characters),textStyle=MaterialTheme.typography.bodyLarge.copy(color=Color.Black));if(error.isNotBlank())Text(error,color=MaterialTheme.colorScheme.error,modifier=Modifier.padding(top=12.dp));Spacer(Modifier.height(16.dp));Button(enabled=!busy&&(identity.deviceId!=null||code.length==16),onClick={busy=true;error="";scope.launch{runCatching{withContext(Dispatchers.IO){val client=DeviceEnrollmentClient(enrollmentEndpoint);val result=if(identity.deviceId==null)client.enroll(code,identity).also{identity.completeEnrollment(it.deviceId,it.credential);DatabaseProvider.getDatabase(context).deviceEnrollmentDao().save(DeviceEnrollmentEntity(it.deviceId,identity.installationId,it.expiresAt))}else null;val id=result?.deviceId?:identity.deviceId!!;val credential=result?.credential?:identity.credential()!!;EmployeeSyncRepository(DatabaseProvider.getDatabase(context)).sync(EmployeeSyncClient(employeeSyncEndpoint),id,credential)};DeviceSyncScheduler.start(context);onReady()}.onFailure{Log.e("DeviceEnrollment","Error mostrado en Registrar dispositivo",it);error=deviceEnrollmentErrorMessage(it)};busy=false}}){if(busy)CircularProgressIndicator()else Text(if(identity.deviceId==null)"Registrar y sincronizar" else "Reintentar sincronización")}}
}
