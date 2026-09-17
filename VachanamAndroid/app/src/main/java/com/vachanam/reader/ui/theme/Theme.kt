package com.vachanam.reader.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = WarmAmber,
    onPrimary = Color.Black,
    primaryContainer = SurfaceElevated,
    onPrimaryContainer = WarmAmber,
    secondary = VibrantTeal,
    onSecondary = Color.Black,
    secondaryContainer = SurfaceElevated,
    onSecondaryContainer = VibrantTeal,
    background = DeepNavy,
    onBackground = TextPrimaryDark,
    surface = SlateCharcoal,
    onSurface = TextPrimaryDark,
    surfaceVariant = SurfaceElevated,
    onSurfaceVariant = TextSecondaryDark,
    error = SoftRed,
    onError = Color.White
)

@Composable
fun VachanamTheme(
    content: @Composable () -> Unit
) {
    val colorScheme = DarkColorScheme
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = DeepNavy.toArgb()
            window.navigationBarColor = DeepNavy.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = false
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
