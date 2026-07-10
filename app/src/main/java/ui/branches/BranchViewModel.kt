package com.example.controlhorario.ui.branches

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.repository.BranchRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class BranchViewModel(
    private val repository: BranchRepository
) : ViewModel() {

    val branches: StateFlow<List<BranchEntity>> =
        repository.getAllBranches()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    fun addBranch(
        name: String,
        code: String,
        address: String,
        city: String,
        province: String,
        phone: String,
        manager: String
    ) {
        if (name.isBlank() || code.isBlank()) return

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
        }
    }

    fun deleteBranch(branch: BranchEntity) {
        viewModelScope.launch {
            repository.delete(branch)
        }
    }
}