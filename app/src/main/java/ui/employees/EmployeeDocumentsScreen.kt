package com.example.controlhorario.ui.employees

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.model.Employee

@Composable
fun EmployeeDocumentsScreen(
    employee: Employee?,
    viewModel: EmployeeDocumentsViewModel,
    onUploadDocument: () -> Unit,
    onPreviewDocument: (Int) -> Unit,
    onShareDocument: (Int) -> Unit,
    onDeleteDocument: (Int) -> Unit,
    onBack: () -> Unit
) {
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

    LaunchedEffect(employee.id) {
        viewModel.loadDocuments(employee.id)
    }

    val documents by viewModel.documents.collectAsState()
    val message by viewModel.message.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "📁 Documentos del empleado",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = employee.nombre,
            style = MaterialTheme.typography.titleMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        if (message.isNotBlank()) {
            Text(message, color = Color(0xFF4CAF50))
            Spacer(modifier = Modifier.height(10.dp))
        }

        if (documents.isEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF111111)
                )
            ) {
                Column(
                    modifier = Modifier.padding(20.dp)
                ) {
                    Text(
                        text = "No existen documentos registrados.",
                        color = Color.White
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    Text(
                        text = "Pulsa Agregar documento para comenzar.",
                        color = Color.LightGray
                    )
                }
            }
        } else {
            documents.forEach { document ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color(0xFF111111)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp)
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = "📄 ${document.documentName}",
                                color = Color.White,
                                modifier = Modifier.weight(1f)
                            )

                            Text(
                                text = document.documentType,
                                color = Color(0xFF4CAF50)
                            )
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Text(
                            text = "Fecha: ${document.uploadedAt}",
                            color = Color.LightGray
                        )

                        Text(
                            text = "Extensión: ${document.fileExtension}",
                            color = Color.LightGray
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = "👁 Ver",
                                color = Color(0xFF2196F3),
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable {
                                        onPreviewDocument(document.id)
                                    }
                            )

                            Text(
                                text = "📤 Compartir",
                                color = Color(0xFF4CAF50),
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable {
                                        onShareDocument(document.id)
                                    }
                            )

                            Text(
                                text = "🗑 Eliminar",
                                color = Color.Red,
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable {
                                        onDeleteDocument(document.id)
                                    }
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedButton(
            onClick = onUploadDocument,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("➕ Agregar documento")
        }

        Spacer(modifier = Modifier.height(10.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}