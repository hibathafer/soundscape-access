package com.hibathafer.soundscape_access

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * prd.md > Product Decisions > Session must not obstruct phone use — slice 5.
 *
 * This service carries *no* audio of its own. The mic stream stays in Dart,
 * owned by the `record` plugin; what Android 14 withholds from a backgrounded
 * app is the right to read the microphone at all. Holding a foreground service
 * typed `microphone` is what keeps that right while the user is elsewhere, and
 * it doubles as the visible proof that a session is running.
 *
 * So the whole job here is: come up in the foreground with the right type,
 * stay up, and report honestly when we cannot.
 *
 * Design notes:
 * - [startForeground] is called immediately in [onStartCommand], never after
 *   an await: Android 14 allows a microphone-typed service to start only from
 *   the foreground and demands the notification right away.
 * - The declared manifest type must match the type passed here, or Android 14
 *   throws at start. `AndroidManifest.xml` declares `microphone`.
 * - `START_NOT_STICKY`: if the platform kills us anyway, we do not come back
 *   as a zombie claiming a session that Dart has already given up on. Dart
 *   asks [isRunning] when the app returns to the foreground and falls back to
 *   a session in front, with a plain note — the documented fallback.
 */
class MicForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.i(TAG, "stop requested")
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                // FOREGROUND_SERVICE_TYPE_MICROPHONE does not exist before R;
                // every microphone-capable device we target is on R or newer.
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: SecurityException) {
            // Started from the background, or the permission was revoked.
            // Never crash the session over haptics-of-the-mind: report and go.
            Log.w(TAG, "could not enter the foreground: ${e.message}")
            state(false)
            stopSelf()
            return START_NOT_STICKY
        }

        Log.i(TAG, "foreground session up (type=microphone)")
        state(true)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "service destroyed")
        state(false)
        super.onDestroy()
    }

    /** The user swiped the app away: the session's owner is gone, so are we. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopForegroundCompat()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // LOW, not DEFAULT: this is a status line, not something that
            // should make a sound every time a session begins.
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Sound session",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    setShowBadge(false)
                    description = "Shown while the microphone session is running"
                },
            )
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Listening for sounds")
                .setContentText("Soundscape Access is active. Tap to return.")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Listening for sounds")
                .setContentText("Soundscape Access is active.")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .build()
        }
    }

    private fun state(running: Boolean) {
        isRunning = running
        listener?.invoke(running)
    }

    companion object {
        private const val TAG = "MicFgService"
        private const val CHANNEL_ID = "soundscape_session"
        private const val NOTIFICATION_ID = 41

        const val ACTION_STOP = "com.hibathafer.soundscape_access.STOP"

        /** Last known service state, for Dart's `isRunning` query. */
        @Volatile
        var isRunning: Boolean = false
            private set

        /** Set by MainActivity so service death reaches the app while it lives. */
        @Volatile
        var listener: ((Boolean) -> Unit)? = null
    }
}
