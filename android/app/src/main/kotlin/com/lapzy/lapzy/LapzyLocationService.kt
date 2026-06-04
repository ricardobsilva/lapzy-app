package com.lapzy.lapzy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class LapzyLocationService : Service() {

    companion object {
        const val CHANNEL_ID = "lapzy_race_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.lapzy.lapzy.START_FOREGROUND"
        const val ACTION_STOP = "com.lapzy.lapzy.STOP_FOREGROUND"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRaceService()
            ACTION_STOP -> stopRaceService()
        }
        return START_STICKY
    }

    private fun startRaceService() {
        createNotificationChannel()
        try {
            // API 29+ exige que o tipo de serviço seja passado em startForeground()
            // para que o Android conceda acesso ao GPS em background.
            // Sem o tipo, o GPS fica sujeito a throttling mesmo com o serviço ativo.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        } catch (_: SecurityException) {
            // Permissão de localização não concedida — não deve ocorrer em produção.
            stopSelf()
        }
    }

    private fun stopRaceService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Lapzy Corrida",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mantém o GPS ativo durante a corrida"
            setShowBadge(false)
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Lapzy · Corrida em andamento")
            .setContentText("GPS ativo")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
