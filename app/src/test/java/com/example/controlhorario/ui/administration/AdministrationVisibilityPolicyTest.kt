package com.example.controlhorario.ui.administration

import org.junit.Assert.assertEquals
import org.junit.Test

class AdministrationVisibilityPolicyTest {
    @Test
    fun `only sections authorized by the server are shown`() {
        val visible = AdministrationVisibilityPolicy.visibleSections(setOf("empresa", "usuarios", "seguridad"))

        assertEquals(
            listOf(
                AdministrationSection.COMPANY,
                AdministrationSection.USERS,
                AdministrationSection.SECURITY,
            ),
            visible,
        )
    }

    @Test
    fun `administrator can receive all ten categories`() {
        val allowed = AdministrationSection.entries.mapTo(mutableSetOf()) { it.wireName }

        assertEquals(10, AdministrationVisibilityPolicy.visibleSections(allowed).size)
    }
}
