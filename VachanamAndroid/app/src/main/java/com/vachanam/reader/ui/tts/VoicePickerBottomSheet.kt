package com.vachanam.reader.ui.tts

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.tts.TTSController
import com.vachanam.reader.ui.theme.SlateCharcoal
import com.vachanam.reader.ui.theme.SurfaceElevated
import com.vachanam.reader.ui.theme.VibrantTeal
import com.vachanam.reader.ui.theme.WarmAmber

data class VoiceDisplayInfo(
    val id: String,
    val displayName: String,
    val description: String,
    val tag: String,
    val gender: String = "Neutral"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoicePickerBottomSheet(
    ttsController: TTSController,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val selectedModelId by ttsController.selectedModelId.collectAsState()
    val selectedVoice by ttsController.selectedVoice.collectAsState()
    val installedVoiceItems by ttsController.systemAdapter.installedVoiceItems.collectAsState()

    val kokoroVoices = remember {
        listOf(
            VoiceDisplayInfo("af_heart", "Heart (Female)", "American Female · Warm & expressive prosody", "Kokoro", "Female"),
            VoiceDisplayInfo("af_bella", "Bella (Female)", "American Female · Natural conversational tone", "Kokoro", "Female"),
            VoiceDisplayInfo("am_adam", "Adam (Male)", "American Male · Clear & steady narration", "Kokoro", "Male"),
            VoiceDisplayInfo("am_michael", "Michael (Male)", "American Male · Authoritative & deep", "Kokoro", "Male"),
            VoiceDisplayInfo("bf_emma", "Emma (Female)", "British Female · Crisp & elegant articulation", "Kokoro", "Female"),
            VoiceDisplayInfo("bm_george", "George (Male)", "British Male · Rich narration depth", "Kokoro", "Male")
        )
    }

    val systemVoices = remember(installedVoiceItems) {
        if (installedVoiceItems.isNotEmpty()) {
            installedVoiceItems.map { item ->
                val genderStr = when (item.gender) {
                    com.vachanam.reader.tts.AndroidSystemAdapter.Gender.MALE -> "Male"
                    com.vachanam.reader.tts.AndroidSystemAdapter.Gender.FEMALE -> "Female"
                    com.vachanam.reader.tts.AndroidSystemAdapter.Gender.NEUTRAL -> "Neutral"
                }
                VoiceDisplayInfo(
                    id = item.id,
                    displayName = item.displayName,
                    description = item.description,
                    tag = "System",
                    gender = genderStr
                )
            }
        } else {
            listOf(
                VoiceDisplayInfo("default", "System Default Voice", "Device default speech synthesizer voice", "System", "Neutral"),
                VoiceDisplayInfo("en-us-x-sfg", "Natural Female 1 (Warm)", "Android high-definition female voice", "System", "Female"),
                VoiceDisplayInfo("en-us-x-tpd", "Natural Male 1 (Deep Baritone)", "Android high-definition male voice", "System", "Male")
            )
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SlateCharcoal,
        modifier = modifier
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Speech Engine & Voices",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        text = "Select speech engine and speaker voice profiles",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.6f)
                    )
                }
                IconButton(onClick = onDismiss) {
                    Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = Color.White)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                // Section 1: TTS Models
                item {
                    Text(
                        text = "Active TTS Model",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = WarmAmber
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    // Model 1: Android System TTS
                    val isSystemSelected = selectedModelId == "android_system"
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .clickable { ttsController.selectModel("android_system") },
                        color = if (isSystemSelected) SurfaceElevated else Color.White.copy(alpha = 0.05f),
                        border = if (isSystemSelected) androidx.compose.foundation.BorderStroke(1.5.dp, WarmAmber) else null
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = "Android System TTS",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 16.sp,
                                        color = Color.White
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(Color(0xFF2E7D32).copy(alpha = 0.3f))
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(text = "● Ready", color = Color(0xFF81C784), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "Zero-download offline speech synthesis using device voices with word karaoke highlighting.",
                                    fontSize = 12.sp,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                            if (isSystemSelected) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = "Selected",
                                    tint = WarmAmber,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Model 2: Kokoro 82M Neural
                    val isKokoroSelected = selectedModelId == "kokoro_82m"
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .clickable { ttsController.selectModel("kokoro_82m") },
                        color = if (isKokoroSelected) SurfaceElevated else Color.White.copy(alpha = 0.05f),
                        border = if (isKokoroSelected) androidx.compose.foundation.BorderStroke(1.5.dp, WarmAmber) else null
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = "Kokoro 82M (Neural)",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 16.sp,
                                        color = Color.White
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(VibrantTeal.copy(alpha = 0.25f))
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(text = "☁ ONNX Neural", color = VibrantTeal, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "Frontier lightweight 82M neural model (~86 MB) with human-like prosody and intonation.",
                                    fontSize = 12.sp,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                            if (isKokoroSelected) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = "Selected",
                                    tint = WarmAmber,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                        }
                    }

                    if (isKokoroSelected) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(0xFF0D47A1).copy(alpha = 0.35f))
                                .padding(10.dp)
                        ) {
                            Text(
                                text = "💡 Kokoro voice personas (Heart, Bella, Adam, Michael, Emma, George) are mapped to expressive neural styles on your device until standalone ONNX weights (~86 MB) are downloaded.",
                                fontSize = 11.sp,
                                color = Color(0xFF90CAF9)
                            )
                        }
                    }
                }

                // Section 2: Voice Profiles
                item {
                    Text(
                        text = if (selectedModelId == "kokoro_82m") "Kokoro Neural Voice Profiles" else "System Voice Profiles",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = WarmAmber
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }

                val activeVoices = if (selectedModelId == "kokoro_82m") kokoroVoices else systemVoices

                items(activeVoices) { voiceInfo ->
                    val isVoiceSelected = selectedVoice == voiceInfo.id || (selectedVoice == null && voiceInfo.id == activeVoices.first().id)

                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .clickable {
                                ttsController.selectVoice(voiceInfo.id)
                                ttsController.previewVoice(voiceInfo.id)
                            },
                        color = if (isVoiceSelected) SurfaceElevated else Color.White.copy(alpha = 0.04f),
                        border = if (isVoiceSelected) androidx.compose.foundation.BorderStroke(1.dp, VibrantTeal) else null
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.RecordVoiceOver,
                                    contentDescription = null,
                                    tint = if (isVoiceSelected) VibrantTeal else Color.White.copy(alpha = 0.5f),
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = voiceInfo.displayName,
                                            fontSize = 15.sp,
                                            fontWeight = if (isVoiceSelected) FontWeight.Bold else FontWeight.Normal,
                                            color = Color.White
                                        )
                                        if (voiceInfo.gender.isNotEmpty() && voiceInfo.gender != "Neutral") {
                                            Spacer(modifier = Modifier.width(8.dp))
                                            val badgeColor = if (voiceInfo.gender == "Male") Color(0xFF29B6F6) else Color(0xFFEC407A)
                                            Box(
                                                modifier = Modifier
                                                    .clip(RoundedCornerShape(4.dp))
                                                    .background(badgeColor.copy(alpha = 0.2f))
                                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                                            ) {
                                                Text(
                                                    text = voiceInfo.gender,
                                                    color = badgeColor,
                                                    fontSize = 10.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    maxLines = 1,
                                                    softWrap = false
                                                )
                                            }
                                        }
                                    }
                                    Text(
                                        text = voiceInfo.description,
                                        fontSize = 11.sp,
                                        color = Color.White.copy(alpha = 0.6f)
                                    )
                                }
                            }

                            Row(verticalAlignment = Alignment.CenterVertically) {
                                IconButton(
                                    onClick = { ttsController.previewVoice(voiceInfo.id) },
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                                        contentDescription = "Preview voice",
                                        tint = WarmAmber,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }

                                if (isVoiceSelected) {
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Icon(
                                        imageVector = Icons.Default.Check,
                                        contentDescription = "Selected",
                                        tint = VibrantTeal,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        }
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(24.dp))
                }
            }
        }
    }
}
