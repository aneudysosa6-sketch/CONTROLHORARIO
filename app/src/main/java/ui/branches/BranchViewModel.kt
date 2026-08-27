package com.example.controlhorario.ui.branches

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.repository.BranchRepository
import com.example.controlhorario.ui.settings.OrganizationLifecycleDecision
import com.example.controlhorario.ui.settings.OrganizationLifecyclePolicy
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class BranchViewModel(
    private val repository: BranchRepository
) : ViewModel() {
    val branches: StateFlow<List<BranchEntity>> = repository.getAllBranches()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _feedback = MutableStateFlow("")
    val feedback = _feedback.asStateFlow()

    fun addBranch(
        name: String,
        code: String,
        address: String,
        city: String,
        province: String,
        phone: String,
        manager: String
    ) {
        if (name.isBlank() || code.isBlank()) {
            _feedback.value = "Nombre y codigo son obligatorios."
            return
        }
        viewModelScope.launch {
            repository.insert(
                BranchEntity(
                    name = name.trim(),
                    code = code.trim(),
                    address = address.trim(),
                    city = city.trim(),
                    province = province.trim(),
                    phone = phone.trim(),
                    manager = manager.trim(),
                    active = true
                )
            )
            _feedback.value = "Sucursal creada."
        }
    }

    fun setBranchActive(branch: BranchEntity, activeDepartmentCount: Int) {
        val activating = !branch.active
        when (val decision = OrganizationLifecyclePolicy.branchStatusChange(activating, activeDepartmentCount)) {
            OrganizationLifecycleDecision.Allowed -> viewModelScope.launch {
                repository.setActive(branch, activating)
                _feedback.value = if (activating) {
                    "Sucursal reactivada. Sus departamentos permanecen en su estado actual."
                } else {
                    "Sucursal desactivada; su historial se conserva."
                }
            }
            is OrganizationLifecycleDecision.Denied -> _feedback.value = decision.message
        }
    }
}