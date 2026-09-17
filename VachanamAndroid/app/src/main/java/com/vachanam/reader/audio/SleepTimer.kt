package com.vachanam.reader.audio

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SleepTimer(
    private val onTimerExpired: () -> Unit
) {
    private val _remainingSeconds = MutableStateFlow(0)
    val remainingSeconds: StateFlow<Int> = _remainingSeconds.asStateFlow()

    private val _isActive = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = _isActive.asStateFlow()

    private var timerJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    fun start(minutes: Int) {
        cancel()
        if (minutes <= 0) return

        _remainingSeconds.value = minutes * 60
        _isActive.value = true

        timerJob = scope.launch {
            while (_remainingSeconds.value > 0) {
                delay(1000)
                _remainingSeconds.value -= 1
            }
            _isActive.value = false
            onTimerExpired()
        }
    }

    fun cancel() {
        timerJob?.cancel()
        timerJob = null
        _remainingSeconds.value = 0
        _isActive.value = false
    }
}
