package com.example.controlhorario.employeeportal

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.auth.AuthenticatedPrincipal
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale
import java.util.UUID

@Composable fun EmployeeSelfServiceScreen(principal:AuthenticatedPrincipal,onLogout:()->Unit){
 val api=remember(principal.authUid){EmployeePortalApi(principal)};val scope=rememberCoroutineScope();var payload by remember{mutableStateOf<EmployeePortalPayload?>(null)};var loading by remember{mutableStateOf(true)};var error by remember{mutableStateOf("")};var message by remember{mutableStateOf("")};var section by rememberSaveable{mutableStateOf("PERFIL")};var amount by rememberSaveable{mutableStateOf("")};var discount by rememberSaveable{mutableStateOf("")};var reason by rememberSaveable{mutableStateOf("")};var idempotency by rememberSaveable{mutableStateOf(UUID.randomUUID().toString())}
 fun load(){scope.launch{loading=true;error="";runCatching{api.load()}.onSuccess{payload=it}.onFailure{error=it.message?:"No fue posible cargar el portal."};loading=false}};LaunchedEffect(principal.authUid){load()}
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Column{Text("OSINET",style=MaterialTheme.typography.titleLarge,color=Color(0xFF2DD4BF));Text("Portal privado del empleado")};TextButton(onClick=onLogout){Text("Cerrar sesión")}};if(error.isNotBlank())Text(error,color=MaterialTheme.colorScheme.error);if(message.isNotBlank())Text(message,color=Color(0xFF34D399));listOf("PERFIL","GANANCIAS HOY","PRÉSTAMO","SOLICITUD DE PRÉSTAMO").forEach{label->OutlinedButton(onClick={section=label},modifier=Modifier.fillMaxWidth(),colors=if(section==label)ButtonDefaults.outlinedButtonColors(containerColor=Color(0xFF123448))else ButtonDefaults.outlinedButtonColors()){Text(label)}};if(loading)CircularProgressIndicator()else payload?.let{data->when(section){
  "PERFIL"->InfoCard("Mi perfil",listOf("Nombre" to data.profile.optString("nombre"),"Código" to data.profile.optString("codigo"),"Correo" to data.profile.optString("correo","—"),"Teléfono" to data.profile.optString("telefono","—"),"Sucursal" to data.profile.optString("sucursal","—"),"Departamento" to data.profile.optString("departamento","—"),"Puesto" to data.profile.optString("puesto","—"),"Estado" to data.profile.optString("estado")))
  "GANANCIAS HOY"->{val g=data.earnings;InfoCard("Acumulado hasta ayer",listOf("Período" to "${g.optString("periodo_inicio")} — ${g.optString("periodo_fin")}","Corte" to g.optString("corte"),"Pago normal" to currency(g.optDouble("pago_normal")),"Horas extra" to currency(g.optDouble("pago_extra")),"Incentivo" to currency(g.optDouble("incentivo")),"Total" to currency(g.optDouble("total"))))}
  "PRÉSTAMO"->JsonCards("Mis préstamos",data.json.optJSONArray("prestamos")?:JSONArray()){x->listOf("Total" to currency(x.optDouble("monto_total")),"Pendiente" to currency(x.optDouble("pendiente")),"Cuota" to currency(x.optDouble("descuento_periodo")),"Estado" to x.optString("estado"),"Motivo" to x.optString("motivo"),"Descuentos aplicados" to (x.optJSONArray("movimientos")?.length()?:0).toString())}
  else->{OutlinedTextField(amount,{amount=it},label={Text("Monto solicitado")},modifier=Modifier.fillMaxWidth());OutlinedTextField(discount,{discount=it},label={Text("Descuento por período")},modifier=Modifier.fillMaxWidth());OutlinedTextField(reason,{reason=it},label={Text("Motivo")},modifier=Modifier.fillMaxWidth(),minLines=3);Button(onClick={val total=amount.toDoubleOrNull();val quota=discount.toDoubleOrNull();if(total==null||quota==null||total<=0||quota<=0||quota>total||reason.trim().length<3){error="Revisa el monto, la cuota y el motivo."}else scope.launch{loading=true;error="";runCatching{api.requestLoan(total,quota,reason.trim(),idempotency)}.onSuccess{idempotency=UUID.randomUUID().toString();amount="";discount="";reason="";message="Solicitud enviada para revisión.";payload=api.load()}.onFailure{error=it.message?:"No fue posible enviar la solicitud."};loading=false}},modifier=Modifier.fillMaxWidth()){Text("ENVIAR SOLICITUD")};JsonCards("Mis solicitudes",data.json.optJSONArray("solicitudes")?:JSONArray()){x->listOf("Monto" to currency(x.optDouble("monto_solicitado")),"Cuota" to currency(x.optDouble("descuento_periodo")),"Estado" to x.optString("estado"),"Motivo" to x.optString("motivo"))}}
 }}}
}
@Composable private fun InfoCard(title:String,rows:List<Pair<String,String>>){Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(7.dp)){Text(title,style=MaterialTheme.typography.titleMedium);rows.forEach{(k,v)->Text("$k: ${v.ifBlank{"—"}}")}}}}
@Composable private fun JsonCards(title:String,array:JSONArray,rows:(JSONObject)->List<Pair<String,String>>){Text(title,style=MaterialTheme.typography.titleMedium);if(array.length()==0)Text("No hay registros.")else repeat(array.length()){InfoCard("Registro ${it+1}",rows(array.getJSONObject(it)))}}
private fun currency(value:Double)=NumberFormat.getCurrencyInstance(Locale("es","DO")).format(value)
