package com.example.controlhorario.ui.branches

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETTextField

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BranchScreen(
    viewModel: BranchViewModel,
    onBack: () -> Unit
) {
    val branches by viewModel.branches.collectAsState()

    var name by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var province by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var manager by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Sucursales") }
            )
        }
    ) { padding ->

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {

            item {
                OSINETTextField(name, { name = it }, "Nombre de la sucursal", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(code, { code = it }, "Código", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(address, { address = it }, "Dirección", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(city, { city = it }, "Ciudad", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(province, { province = it }, "Provincia", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(phone, { phone = it }, "Teléfono", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(manager, { manager = it }, "Encargado", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(12.dp))

                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        viewModel.addBranch(
                            name = name,
                            code = code,
                            address = address,
                            city = city,
                            province = province,
                            phone = phone,
                            manager = manager
                        )

                        name = ""
                        code = ""
                        address = ""
                        city = ""
                        province = ""
                        phone = ""
                        manager = ""
                    }
                ) {
                    Text("Guardar sucursal")
                }

                Spacer(modifier = Modifier.height(12.dp))

                OutlinedButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onBack
                ) {
                    Text("⬅ Volver")
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text("Sucursales registradas")

                Spacer(modifier = Modifier.height(8.dp))
            }

            items(branches) { branch ->

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    elevation = CardDefaults.cardElevation(3.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp)
                    ) {
                        Text("${branch.name} (${branch.code})")
                        Text("${branch.city}, ${branch.province}")
                        Text(branch.address)
                        Text("Tel: ${branch.phone}")
                        Text("Encargado: ${branch.manager}")

                        Spacer(modifier = Modifier.height(8.dp))

                        Button(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = {
                                viewModel.deleteBranch(branch)
                            }
                        ) {
                            Text("Eliminar")
                        }
                    }
                }
            }
        }
    }
}
