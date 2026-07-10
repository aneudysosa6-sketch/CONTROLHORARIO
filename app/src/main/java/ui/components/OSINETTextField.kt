package com.example.controlhorario.ui.components

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.VisualTransformation

@Composable
fun OSINETTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = modifier,
        singleLine = true,
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = OSINETColors.TextPrimary,
            unfocusedTextColor = OSINETColors.TextPrimary,
            disabledTextColor = OSINETColors.TextSecondary,
            cursorColor = OSINETColors.Green,
            focusedContainerColor = OSINETColors.Surface,
            unfocusedContainerColor = OSINETColors.Surface,
            disabledContainerColor = OSINETColors.SurfaceAlt,
            focusedBorderColor = OSINETColors.Green,
            unfocusedBorderColor = OSINETColors.Border,
            focusedLabelColor = OSINETColors.GreenSoft,
            unfocusedLabelColor = OSINETColors.TextSecondary,
            focusedPlaceholderColor = OSINETColors.TextSecondary,
            unfocusedPlaceholderColor = OSINETColors.TextSecondary,
            errorTextColor = Color.White,
            errorBorderColor = OSINETColors.Danger,
            errorLabelColor = OSINETColors.Danger
        )
    )
}
