package com.example.controlhorario.ui.employees

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.EmployeeDocumentEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun EmployeeDocumentUploadScreen(
    employee: Employee?,
    viewModel: EmployeeDocumentsViewModel,
    onBack: () -> Unit
) {
    val context = LocalContext.current

    var documentName by remember { mutableStateOf("") }
    var documentType by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    var selectedFileName by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri != null) {
            selectedUri = uri
            selectedFileName = getFileName(context, uri)

            if (documentName.isBlank()) {
                documentName = selectedFileName.substringBeforeLast(".")
            }

            message = "Archivo seleccionado correctamente ✅"
        }
    }

    if (employee == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
        ) {
            Text("Empleado no encontrado")

            Spacer(modifier = Modifier.height(16.dp))

            OutlinedButton(
                onClick = onBack,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("⬅ Volver")
            }
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Agregar documento",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = employee.nombre,
            style = MaterialTheme.typography.titleMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        OSINETTextField(
            value = documentName,
            onValueChange = { documentName = it },
            label = "Nombre del documento",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = documentType,
            onValueChange = { documentType = it },
            label = "Tipo de documento",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = notes,
            onValueChange = { notes = it },
            label = "Observaciones",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedButton(
            onClick = {
                filePickerLauncher.launch("*/*")
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("📎 Seleccionar archivo")
        }

        Spacer(modifier = Modifier.height(10.dp))

        if (selectedFileName.isNotBlank()) {
            Text("Archivo seleccionado:")
            Text(selectedFileName)
            Spacer(modifier = Modifier.height(12.dp))
        }

        if (message.isNotBlank()) {
            Text(message)
            Spacer(modifier = Modifier.height(12.dp))
        }

        OSINETButton(
            text = "💾 Guardar documento",
            onClick = {
                val uri = selectedUri

                if (documentName.isBlank()) {
                    message = "Debes escribir el nombre del documento."
                    return@OSINETButton
                }

                if (documentType.isBlank()) {
                    message = "Debes escribir el tipo de documento."
                    return@OSINETButton
                }

                if (uri == null) {
                    message = "Debes seleccionar un archivo."
                    return@OSINETButton
                }

                val savedFile = copyDocumentToEmployeeFolder(
                    context = context,
                    employeeId = employee.id,
                    uri = uri,
                    originalFileName = selectedFileName
                )

                if (savedFile == null) {
                    message = "No se pudo guardar el archivo."
                    return@OSINETButton
                }

                val uploadedAt = SimpleDateFormat(
                    "yyyy-MM-dd HH:mm:ss",
                    Locale.getDefault()
                ).format(Date())

                val document = EmployeeDocumentEntity(
                    employeeId = employee.id,
                    documentName = documentName.trim(),
                    documentType = documentType.trim(),
                    filePath = savedFile.absolutePath,
                    fileExtension = savedFile.extension,
                    fileSizeBytes = savedFile.length(),
                    uploadedAt = uploadedAt,
                    notes = notes.trim(),
                    isActive = true
                )

                viewModel.saveDocument(document)

                documentName = ""
                documentType = ""
                notes = ""
                selectedUri = null
                selectedFileName = ""

                message = "Documento guardado correctamente ✅"
            }
        )

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}

private fun getFileName(
    context: Context,
    uri: Uri
): String {
    var fileName = "documento_${System.currentTimeMillis()}"

    val cursor = context.contentResolver.query(
        uri,
        null,
        null,
        null,
        null
    )

    cursor?.use {
        val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)

        if (it.moveToFirst() && nameIndex >= 0) {
            fileName = it.getString(nameIndex)
        }
    }

    return fileName
}

private fun copyDocumentToEmployeeFolder(
    context: Context,
    employeeId: Int,
    uri: Uri,
    originalFileName: String
): File? {
    return try {
        val baseFolder = File(
            context.getExternalFilesDir(null),
            "EmployeeDocuments/$employeeId"
        )

        if (!baseFolder.exists()) {
            baseFolder.mkdirs()
        }

        val safeFileName = originalFileName
            .ifBlank { "documento_${System.currentTimeMillis()}" }
            .replace("/", "_")
            .replace("\\", "_")
            .replace(":", "_")

        val destinationFile = File(
            baseFolder,
            "${System.currentTimeMillis()}_$safeFileName"
        )

        context.contentResolver.openInputStream(uri)?.use { input ->
            destinationFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        destinationFile
    } catch (e: Exception) {
        null
    }
}