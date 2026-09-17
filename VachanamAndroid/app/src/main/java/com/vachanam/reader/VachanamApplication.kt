package com.vachanam.reader

import android.app.Application
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader

class VachanamApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
        // Initialize PDFBox for Android text extraction
        PDFBoxResourceLoader.init(applicationContext)
    }

    companion object {
        lateinit var instance: VachanamApplication
            private set
    }
}
