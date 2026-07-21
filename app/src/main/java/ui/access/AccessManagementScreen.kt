package com.example.controlhorario.ui.access

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun AccessManagementScreen(
    viewModel: AccessManagementViewModel,
    currentProfileId: String,
    capabilities: AccessCapabilities,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val catalog = state.catalog
    var selectedEmployeeId by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var selectedRoleId by remember { mutableStateOf("") }
    var selectedStatus by remember { mutableStateOf(ACCESS_STATUS_ACTIVE) }
    var editingProfileId by remember { mutableStateOf<String?>(null) }
    var passwordTarget by remember { mutableStateOf<AccessAccount?>(null) }
    var replacementPassword by remember { mutableStateOf("") }
    var deleteTarget by remember { mutableStateOf<AccessAccount?>(null) }

    LaunchedEffect(catalog?.roles) {
        if (selectedRoleId.isBlank()) selectedRoleId = catalog?.roles?.firstOrNull()?.id.orEmpty()
    }
    LaunchedEffect(state.message) {
        if (state.message.startsWith("Acceso creado") || state.message.startsWith("Acceso actualizado")) {
            selectedEmployeeId = ""
            username = ""
            password = ""
            selectedRoleId = catalog?.roles?.firstOrNull()?.id.orEmpty()
            selectedStatus = ACCESS_STATUS_ACTIVE
            editingProfileId = null
        }
    }

    OSINETScreen {
        OSINETHeader(
            title = "Accesos",
            subtitle = "Cuentas vinculadas a empleados, roles y estado",
        )
        Spacer(Modifier.height(14.dp))

        when {
            state.loading && catalog == null -> CircularProgressIndicator(color = OSINETColors.Green)
            catalog == null -> {
                OSINETCard {
                    Text(state.error.ifBlank { "No fue posible cargar los accesos." }, color = OSINETColors.Danger)
                    OSINETButton("REINTENTAR", onClick = viewModel::refresh)
                }
            }
            else -> {
                val editing = editingProfileId?.let { id -> catalog.accesses.firstOrNull { it.id == id } }
                val occupiedEmployeeIds = catalog.accesses
                    .filter { it.id != editingProfileId }
                    .mapTo(mutableSetOf(), AccessAccount::employeeId)
                val employeeOptions = catalog.employees
                    .filter { employee ->
                        employee.id == selectedEmployeeId ||
                            (employee.id !in occupiedEmployeeIds && employee.profileId.isNullOrBlank())
                    }
                    .sortedWith(compareBy(AccessEmployee::employeeCode, AccessEmployee::fullName))

                if (capabilities.canCreate || editing != null) OSINETCard {
                    Text(
                        if (editing == null) "Crear acceso" else "Editar acceso",
                        color = OSINETColors.TextPrimary,
                        fontWeight = FontWeight.SemiBold,
                    )
                    AccessSelector(
                        label = "Empleado",
                        selectedId = selectedEmployeeId,
                        options = employeeOptions.map { it.id to "${it.employeeCode} · ${it.fullName}" },
                        enabled = !state.busy,
                        onSelected = { selectedEmployeeId = it },
                    )
                    OSINETTextField(
                        value = username,
                        onValueChange = { username = it },
                        label = "Usuario",
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if (editing == null) {
                        OSINETTextField(
                            value = password,
                            onValueChange = { password = it },
                            label = "Contraseña",
                            modifier = Modifier.fillMaxWidth(),
                            visualTransformation = PasswordVisualTransformation(),
                        )
                    }
                    AccessSelector(
                        label = "Rol",
                        selectedId = selectedRoleId,
                        options = catalog.roles.map { it.id to it.name },
                        enabled = !state.busy,
                        onSelected = { selectedRoleId = it },
                    )
                    AccessSelector(
                        label = "Estado",
                        selectedId = selectedStatus,
                        options = if (editing?.id == currentProfileId) {
                            listOf(ACCESS_STATUS_ACTIVE to "Activo")
                        } else {
                            listOf(ACCESS_STATUS_ACTIVE to "Activo", ACCESS_STATUS_INACTIVE to "Inactivo")
                        },
                        enabled = !state.busy,
                        onSelected = { selectedStatus = it },
                    )
                    OSINETButton(
                        text = if (editing == null) "CREAR ACCESO" else "GUARDAR CAMBIOS",
                        enabled = !state.busy,
                        onClick = {
                            if (editing == null) {
                                viewModel.create(
                                    CreateAccessRequest(
                                        employeeId = selectedEmployeeId,
                                        username = username,
                                        password = password,
                                        roleId = selectedRoleId,
                                        status = selectedStatus,
                                    )
                                )
                            } else {
                                viewModel.update(
                                    UpdateAccessRequest(
                                        profileId = editing.id,
                                        employeeId = selectedEmployeeId,
                                        username = username,
                                        roleId = selectedRoleId,
                                        status = selectedStatus,
                                    )
                                )
                            }
                        },
                    )
                    if (editing != null) {
                        OSINETSecondaryButton(
                            text = "Cancelar edición",
                            onClick = {
                                editingProfileId = null
                                selectedEmployeeId = ""
                                username = ""
                                selectedRoleId = catalog.roles.firstOrNull()?.id.orEmpty()
                                selectedStatus = ACCESS_STATUS_ACTIVE
                                viewModel.clearFeedback()
                            },
                        )
                    }
                }

                if (state.message.isNotBlank()) {
                    Spacer(Modifier.height(10.dp))
                    Text(state.message, color = OSINETColors.GreenSoft, modifier = Modifier.fillMaxWidth())
                }
                if (state.error.isNotBlank()) {
                    Spacer(Modifier.height(10.dp))
                    Text(state.error, color = OSINETColors.Danger, modifier = Modifier.fillMaxWidth())
                }
                Spacer(Modifier.height(16.dp))
                Text("Accesos registrados", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))

                if (catalog.accesses.isEmpty()) {
                    OSINETCard { Text("No hay accesos registrados.", color = OSINETColors.TextSecondary) }
                }
                catalog.accesses.sortedBy(AccessAccount::username).forEach { access ->
                    AccessRow(
                        access = access,
                        busy = state.busy,
                        deleteAllowed = AccessManagementPolicy.canDelete(access, currentProfileId, catalog.accesses).allowed,
                        statusChangeAllowed = AccessManagementPolicy.canSetStatus(
                            target = access,
                            status = if (access.isActive) ACCESS_STATUS_INACTIVE else ACCESS_STATUS_ACTIVE,
                            currentProfileId = currentProfileId,
                            accesses = catalog.accesses,
                        ).allowed,
                        canEdit = capabilities.canEdit,
                        canManage = capabilities.canManage,
                        onEdit = {
                            editingProfileId = access.id
                            selectedEmployeeId = access.employeeId
                            username = access.username
                            selectedRoleId = access.roleId
                            selectedStatus = access.status
                            password = ""
                            viewModel.clearFeedback()
                        },
                        onPassword = {
                            passwordTarget = access
                            replacementPassword = ""
                            viewModel.clearFeedback()
                        },
                        onStatus = {
                            viewModel.setStatus(
                                access,
                                if (access.isActive) ACCESS_STATUS_INACTIVE else ACCESS_STATUS_ACTIVE,
                            )
                        },
                        onDelete = { deleteTarget = access },
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }

    passwordTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { if (!state.busy) passwordTarget = null },
            title = { Text("Cambiar contraseña") },
            text = {
                Column {
                    Text("Acceso: ${target.username}")
                    Spacer(Modifier.height(8.dp))
                    OSINETTextField(
                        value = replacementPassword,
                        onValueChange = { replacementPassword = it },
                        label = "Nueva contraseña",
                        modifier = Modifier.fillMaxWidth(),
                        visualTransformation = PasswordVisualTransformation(),
                    )
                }
            },
            confirmButton = {
                TextButton(
                    enabled = !state.busy,
                    onClick = {
                        viewModel.changePassword(target.id, replacementPassword)
                        passwordTarget = null
                        replacementPassword = ""
                    },
                ) { Text("Actualizar") }
            },
            dismissButton = { TextButton(onClick = { passwordTarget = null }) { Text("Cancelar") } },
        )
    }

    deleteTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { if (!state.busy) deleteTarget = null },
            title = { Text("Eliminar acceso") },
            text = { Text("Se eliminará el acceso de ${target.employeeName}. El empleado y sus datos no serán eliminados.") },
            confirmButton = {
                TextButton(
                    enabled = !state.busy,
                    onClick = {
                        viewModel.delete(target)
                        deleteTarget = null
                    },
                ) { Text("Eliminar", color = OSINETColors.Danger) }
            },
            dismissButton = { TextButton(onClick = { deleteTarget = null }) { Text("Cancelar") } },
        )
    }
}

@Composable
private fun AccessSelector(
    label: String,
    selectedId: String,
    options: List<Pair<String, String>>,
    enabled: Boolean,
    onSelected: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = options.firstOrNull { it.first == selectedId }?.second ?: "Seleccionar"
    Box(Modifier.fillMaxWidth()) {
        OutlinedButton(
            onClick = { expanded = true },
            enabled = enabled && options.isNotEmpty(),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("$label: $selectedLabel", modifier = Modifier.fillMaxWidth())
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (id, title) ->
                DropdownMenuItem(
                    text = { Text(title) },
                    onClick = {
                        expanded = false
                        onSelected(id)
                    },
                )
            }
        }
    }
}

@Composable
private fun AccessRow(
    access: AccessAccount,
    busy: Boolean,
    deleteAllowed: Boolean,
    statusChangeAllowed: Boolean,
    canEdit: Boolean,
    canManage: Boolean,
    onEdit: () -> Unit,
    onPassword: () -> Unit,
    onStatus: () -> Unit,
    onDelete: () -> Unit,
) {
    OSINETCard {
        AccessValue("Usuario", access.username)
        AccessValue(
            "Empleado",
            listOf(access.employeeCode, access.employeeName).filter(String::isNotBlank).joinToString(" · ")
                .ifBlank { "Empleado no vinculado" },
        )
        AccessValue("Rol", access.roleName)
        AccessValue("Estado", if (access.isActive) "Activo" else "Inactivo")
        AccessValue("Último acceso", access.lastSignInAt ?: "Nunca")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onEdit, enabled = !busy && canEdit, modifier = Modifier.weight(1f)) { Text("Editar") }
            OutlinedButton(onClick = onPassword, enabled = !busy && canManage, modifier = Modifier.weight(1f)) { Text("Cambiar contraseña") }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onStatus, enabled = !busy && canManage && statusChangeAllowed, modifier = Modifier.weight(1f)) {
                Text(if (access.isActive) "Desactivar" else "Activar")
            }
            OutlinedButton(onClick = onDelete, enabled = !busy && canManage && deleteAllowed, modifier = Modifier.weight(1f)) {
                Text("Eliminar", color = if (canManage && deleteAllowed) OSINETColors.Danger else OSINETColors.TextSecondary)
            }
        }
    }
}

@Composable
private fun AccessValue(label: String, value: String) {
    Text(label, color = OSINETColors.TextSecondary)
    Text(value.ifBlank { "—" }, color = OSINETColors.TextPrimary, fontWeight = FontWeight.Medium)
}
