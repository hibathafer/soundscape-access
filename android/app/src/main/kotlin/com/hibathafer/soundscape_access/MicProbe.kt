package com.hibathafer.soundscape_access

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Slice 2 research probe (round 2) — spec.md > Decisions and Open Issues.
 *
 * Round 1 (MIC + CAMCORDER) showed both sources reading the same mixed
 * signal (~0 dB apart during loud near-field sound). Round 2 widens the
 * search for ANY separately-addressable signal:
 *
 *  - VOICE_RECOGNITION: often routed to a different physical mic and/or
 *    with different processing than MIC.
 *  - UNPROCESSED (API 24+): bypasses AGC/noise-suppression entirely —
 *    AGC may have been flattening the round-1 difference.
 *  - STEREO capture (CHANNEL_IN_STEREO): left/right channels of ONE
 *    AudioRecord sometimes come from two different physical mics.
 *
 * Each source opens independently; failures are skipped and simply do
 * not appear in the reported map (the Dart panel shows what exists).
 */
class MicProbe(private val onLevels: (Map<String, Double>) -> Unit) {

    private val sampleRate = 16000
    private val running = AtomicBoolean(false)
    private val lastLevels = mutableMapOf<String, Double>()
    private val lock = Any()
    private var records = listOf<AudioRecord>()
    private var workerThreads = listOf<Thread>()
    private var reportThread: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private data class Input(val label: String, val source: Int, val stereo: Boolean = false)

    private fun inputs(): List<Input> {
        val list = mutableListOf(
            Input("top", MediaRecorder.AudioSource.CAMCORDER),
            Input("bottom", MediaRecorder.AudioSource.MIC),
            Input("stereoLR", MediaRecorder.AudioSource.MIC, stereo = true),
            Input("vrec", MediaRecorder.AudioSource.VOICE_RECOGNITION),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            list += Input("unproc", MediaRecorder.AudioSource.UNPROCESSED)
        }
        return list
    }

    /** Starts every input that the device allows. False only if none worked. */
    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        if (running.get()) return true
        running.set(true)
        records = emptyList()

        workerThreads = inputs().mapNotNull { input -> openAndRun(input) }

        if (records.isEmpty()) {
            stop()
            return false
        }

        reportThread = Thread {
            while (running.get()) {
                val snapshot: Map<String, Double>
                synchronized(lock) { snapshot = HashMap(lastLevels) }
                if (snapshot.isNotEmpty()) {
                    mainHandler.post { onLevels(snapshot) }
                }
                try {
                    Thread.sleep(100)
                } catch (e: InterruptedException) {
                    break
                }
            }
        }.also { it.start() }
        return true
    }

    @SuppressLint("MissingPermission")
    private fun openAndRun(input: Input): Thread? {
        val channelMask =
            if (input.stereo) AudioFormat.CHANNEL_IN_STEREO else AudioFormat.CHANNEL_IN_MONO
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, channelMask, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) return null
        val bufSize = maxOf(minBuf * 2, 3200)
        val rec = try {
            AudioRecord(
                input.source, sampleRate, channelMask,
                AudioFormat.ENCODING_PCM_16BIT, bufSize
            )
        } catch (e: SecurityException) {
            return null
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            return null
        }
        try {
            rec.startRecording()
        } catch (e: IllegalStateException) {
            rec.release()
            return null
        }
        records = records + rec

        return Thread {
            val buf = ShortArray(bufSize / 2)
            while (running.get()) {
                val read = rec.read(buf, 0, buf.size)
                if (read > 0) {
                    if (input.stereo) {
                        // Interleaved L,R — compute one RMS per channel.
                        var sumL = 0.0
                        var sumR = 0.0
                        var n = 0
                        var i = 0
                        while (i + 1 < read) {
                            val l = buf[i].toDouble()
                            val r = buf[i + 1].toDouble()
                            sumL += l * l
                            sumR += r * r
                            n++
                            i += 2
                        }
                        if (n > 0) {
                            val dbL = rmsToDb(kotlin.math.sqrt(sumL / n))
                            val dbR = rmsToDb(kotlin.math.sqrt(sumR / n))
                            synchronized(lock) {
                                lastLevels["stL"] = dbL
                                lastLevels["stR"] = dbR
                            }
                        }
                    } else {
                        var sum = 0.0
                        for (i in 0 until read) {
                            val s = buf[i].toDouble()
                            sum += s * s
                        }
                        val db = rmsToDb(kotlin.math.sqrt(sum / read))
                        synchronized(lock) { lastLevels[input.label] = db }
                    }
                }
            }
        }.also { it.start() }
    }

    private fun rmsToDb(rms: Double): Double =
        if (rms > 1.0) 20.0 * kotlin.math.log10(rms) else -160.0

    fun stop() {
        if (!running.compareAndSet(true, false)) return
        records.forEach { rec ->
            try {
                rec.stop()
            } catch (e: IllegalStateException) {
            }
            rec.release()
        }
        records = emptyList()
        (workerThreads + listOfNotNull(reportThread)).forEach { it.interrupt() }
        workerThreads = emptyList()
        reportThread = null
    }
}
