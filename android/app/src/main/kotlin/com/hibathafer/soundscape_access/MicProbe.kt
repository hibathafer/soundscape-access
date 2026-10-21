package com.hibathafer.soundscape_access

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Slice 2 research probe (round 3 — DECISIVE).
 *
 * Rounds 1-2 showed all public audio SOURCES deliver one mixed signal.
 * This round tests the remaining public-API avenue: DEVICE selection.
 * Android may expose separate physical input devices (AudioDeviceInfo);
 * AudioRecord.setPreferredDevice() can request a specific one, and
 * rec.routedDevice tells us what was actually used — the hard evidence.
 * Also tries stereo capture on UNPROCESSED (bypasses the mixer path).
 */
class MicProbe(
    private val context: Context,
    private val onLevels: (Map<String, Double>) -> Unit
) {
    companion object {
        private const val TAG = "MicProbe"
    }

    private val sampleRate = 16000
    private val running = AtomicBoolean(false)
    private val lastLevels = mutableMapOf<String, Double>()
    private val lock = Any()
    private var records = listOf<AudioRecord>()
    private var workerThreads = listOf<Thread>()
    private var reportThread: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Starts every experiment input the device allows. False only if none. */
    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        if (running.get()) return true
        running.set(true)
        records = emptyList()

        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val inputs = am.getDevices(AudioManager.GET_DEVICES_INPUTS)
        for (d in inputs) {
            Log.i(TAG, "INPUT id=${d.id} type=${d.type} name=${d.productName} " +
                    "sampleRates=${d.sampleRates?.toList()} channelMasks=${d.channelMasks?.toList()}")
        }
        val mics = inputs.filter { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
        Log.i(TAG, "BUILTIN_MIC count=${mics.size}")
        val secondMic = mics.getOrNull(1)

        // Round 4: source x device matrix. The audio policy may respect
        // setPreferredDevice for SOME sources even though it ignored MIC.
        data class Attempt(val label: String, val source: Int)
        val attempts = mutableListOf(
            Attempt("mic", MediaRecorder.AudioSource.MIC),
            Attempt("cam", MediaRecorder.AudioSource.CAMCORDER),
            Attempt("vrc", MediaRecorder.AudioSource.VOICE_RECOGNITION),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            attempts += Attempt("unp", MediaRecorder.AudioSource.UNPROCESSED)
        }
        for (a in attempts) {
            if (secondMic != null) openPreferred(a.label, a.source, secondMic)
            else openPlain(a.label, a.source)
        }
        // Baseline reference: plain MIC with no device preference.
        openPlain("ref", MediaRecorder.AudioSource.MIC)

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
    private fun openAndStart(rec: AudioRecord, label: String, stereo: Boolean): Thread? {
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            Log.i(TAG, "$label: NOT INITIALIZED — skipped")
            rec.release()
            return null
        }
        try {
            rec.startRecording()
        } catch (e: IllegalStateException) {
            Log.i(TAG, "$label: startRecording failed — skipped")
            rec.release()
            return null
        }
        // Hard evidence: which physical device did the OS actually use?
        val routed = rec.routedDevice
        Log.i(TAG, "$label: ROUTED id=${routed?.id} type=${routed?.type} name=${routed?.productName}")
        records = records + rec

        val buf = ShortArray(3200)
        return Thread {
            while (running.get()) {
                val read = rec.read(buf, 0, buf.size)
                if (read > 0) {
                    if (stereo) {
                        var sumL = 0.0; var sumR = 0.0; var n = 0; var i = 0
                        while (i + 1 < read) {
                            val l = buf[i].toDouble(); val r = buf[i + 1].toDouble()
                            sumL += l * l; sumR += r * r; n++; i += 2
                        }
                        if (n > 0) {
                            synchronized(lock) {
                                lastLevels["${label}L"] = rmsToDb(kotlin.math.sqrt(sumL / n))
                                lastLevels["${label}R"] = rmsToDb(kotlin.math.sqrt(sumR / n))
                            }
                        }
                    } else {
                        var sum = 0.0
                        for (i in 0 until read) { val s = buf[i].toDouble(); sum += s * s }
                        synchronized(lock) { lastLevels[label] = rmsToDb(kotlin.math.sqrt(sum / read)) }
                    }
                }
            }
        }.also { it.start() }
    }

    @SuppressLint("MissingPermission")
    private fun openPreferred(label: String, source: Int, device: AudioDeviceInfo) {
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) return
        val rec = try {
            AudioRecord(
                source, sampleRate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf * 2, 3200)
            )
        } catch (e: SecurityException) { return }
        val ok = rec.setPreferredDevice(device)
        Log.i(TAG, "$label: setPreferredDevice(id=${device.id}) -> $ok")
        openAndStart(rec, label, stereo = false)
    }

    @SuppressLint("MissingPermission")
    private fun openPlain(label: String, source: Int) {
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) return
        val rec = try {
            AudioRecord(
                source, sampleRate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf * 2, 3200)
            )
        } catch (e: SecurityException) { return }
        openAndStart(rec, label, stereo = false)
    }

    @SuppressLint("MissingPermission")
    private fun openStereoUnused(label: String, source: Int) {
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) {
            Log.i(TAG, "$label: stereo not supported for source $source — skipped")
            return
        }
        val rec = try {
            AudioRecord(
                source, sampleRate, AudioFormat.CHANNEL_IN_STEREO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(minBuf * 2, 3200)
            )
        } catch (e: SecurityException) { return }
        openAndStart(rec, label, stereo = true)
    }

    private fun rmsToDb(rms: Double): Double =
        if (rms > 1.0) 20.0 * kotlin.math.log10(rms) else -160.0

    // ---- Round 5: one isolated stereo AudioRecord -------------------------
    // Answers a single question: does the stereo stream carry two distinct
    // channels, or is R a copy of L? Nothing else is opened, so there is no
    // concurrent-capture mixer confound. Evidence per tick: L/R RMS, the
    // bit-mismatch frame count, and the RMS of the L-R difference signal.
    @SuppressLint("MissingPermission")
    fun startStereo(): Boolean {
        if (running.get()) {
            Log.i(TAG, "r5: probe already running — stop it first")
            return false
        }
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val unprocSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                am.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"
        var source = if (unprocSupported) MediaRecorder.AudioSource.UNPROCESSED
                     else MediaRecorder.AudioSource.MIC
        Log.i(TAG, "r5: UNPROCESSED supported=$unprocSupported -> source=$source")

        var rec = openStereoRecord(source)
        if (rec == null && source != MediaRecorder.AudioSource.MIC) {
            Log.i(TAG, "r5: UNPROCESSED failed to init — falling back to MIC")
            source = MediaRecorder.AudioSource.MIC
            rec = openStereoRecord(source)
        }
        if (rec == null) {
            Log.i(TAG, "r5: could not open a stereo AudioRecord at all")
            return false
        }

        running.set(true)
        val worker = openAndStartStereo(rec, "st")
        workerThreads = listOfNotNull(worker)
        if (records.isEmpty()) { stop(); return false }

        // Same reporter loop as start() — duplicated on purpose so the
        // round-4 evidence path stays byte-identical and re-runnable.
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

    private fun openStereoRecord(source: Int): AudioRecord? {
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) return null
        val rec = try {
            AudioRecord(
                source, sampleRate, AudioFormat.CHANNEL_IN_STEREO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(minBuf * 4, 16384)
            )
        } catch (e: SecurityException) { return null }
        if (rec.state != AudioRecord.STATE_INITIALIZED) { rec.release(); return null }
        return rec
    }

    private fun openAndStartStereo(rec: AudioRecord, label: String): Thread? {
        try {
            rec.startRecording()
        } catch (e: IllegalStateException) {
            Log.i(TAG, "$label: startRecording failed"); rec.release(); return null
        }
        val routed = rec.routedDevice
        Log.i(TAG, "$label: ROUTED id=${routed?.id} type=${routed?.type} name=${routed?.productName}")
        records = records + rec

        val buf = ShortArray(3200)
        return Thread {
            var frames = 0L
            var mismatches = 0L
            var lastLog = 0L
            while (running.get()) {
                val read = rec.read(buf, 0, buf.size)
                if (read < 2) continue
                var sumL = 0.0; var sumR = 0.0; var sumD = 0.0
                var n = 0; var i = 0
                while (i + 1 < read) {
                    val l = buf[i].toDouble(); val r = buf[i + 1].toDouble()
                    val d = l - r
                    sumL += l * l; sumR += r * r; sumD += d * d
                    if (buf[i] != buf[i + 1]) mismatches++
                    n++; i += 2
                }
                if (n == 0) continue
                frames += n
                val dbL = rmsToDbfs(kotlin.math.sqrt(sumL / n))
                val dbR = rmsToDbfs(kotlin.math.sqrt(sumR / n))
                val dbD = rmsToDbfs(kotlin.math.sqrt(sumD / n))
                synchronized(lock) {
                    lastLevels["${label}L"] = dbL
                    lastLevels["${label}R"] = dbR
                }
                // Locale.US: the device's default locale renders Arabic-Indic
                // digits in logs (seen in probe_log_r4) — keep it parseable.
                val now = System.currentTimeMillis()
                if (now - lastLog >= 200) {
                    lastLog = now
                    val pct = if (frames > 0) mismatches * 100.0 / frames else 0.0
                    Log.i(TAG, "$label: L=${"%.1f".format(Locale.US, dbL)} " +
                            "R=${"%.1f".format(Locale.US, dbR)} " +
                            "dL-R=${"%.1f".format(Locale.US, dbD)} " +
                            "mism=${"%.3f".format(Locale.US, pct)}% ($mismatches/$frames)")
                }
            }
        }.also { it.start() }
    }

    /** Proper dBFS (full scale = 0). Unlike rmsToDb, which reports raw counts. */
    private fun rmsToDbfs(rms: Double): Double {
        if (rms <= 0.0) return -160.0
        val db = 20.0 * kotlin.math.log10(rms / 32768.0)
        return if (db < -160.0) -160.0 else db
    }

    fun stop() {
        if (!running.compareAndSet(true, false)) return
        records.forEach { rec ->
            try { rec.stop() } catch (e: IllegalStateException) {}
            rec.release()
        }
        records = emptyList()
        (workerThreads + listOfNotNull(reportThread)).forEach { it.interrupt() }
        workerThreads = emptyList()
        reportThread = null
    }
}
