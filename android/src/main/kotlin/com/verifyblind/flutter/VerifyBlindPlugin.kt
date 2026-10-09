package com.verifyblind.flutter

import android.app.Activity
import android.content.Context
import com.verifyblind.sdk.VerifyBlindAndroidSDK
import com.verifyblind.sdk.VerifyBlindConfig
import com.verifyblind.sdk.VerifyBlindException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Thin bridge to `com.verifyblind:verifyblind-android`. No crypto or network code here.
 *
 * One native [VerifyBlindAndroidSDK] per Dart `VerifyBlind` object (keyed by its id), kept alive
 * between `startAuthentication` and `checkVerificationResult`, because the SDK holds the
 * temporary key pair in memory. Nothing from the result is logged.
 */
class VerifyBlindPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private var activity: Activity? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val sdks = mutableMapOf<Int, VerifyBlindAndroidSDK>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        sdks.clear()
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startAuthentication" -> startAuthentication(call, result)
            "checkVerificationResult" -> checkVerificationResult(call, result)
            "dispose" -> {
                call.argument<Int>("id")?.let { sdks.remove(it) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startAuthentication(call: MethodCall, result: Result) {
        val sdk = try {
            sdkFor(call)
        } catch (e: Exception) {
            result.error(INVALID_ARGUMENT, e.message ?: "Invalid config", null)
            return
        }
        val context: Context = activity ?: appContext ?: run {
            result.error("UNKNOWN", "No Android context", null)
            return
        }
        val validations = call.argument<Map<String, Any?>>("validations")?.nonNull()
        val customData = call.argument<Map<String, Any?>>("customData")?.nonNull()
        val returnUrl = call.argument<String>("returnUrl")

        scope.launch {
            try {
                val r = sdk.startAuthentication(
                    context = context,
                    validations = validations,
                    customData = customData,
                    returnUrl = returnUrl
                )
                result.success(r.nonce)
            } catch (e: VerifyBlindException) {
                result.error(e.code.name, e.message, errorDetails(e))
            } catch (e: Exception) {
                result.error("UNKNOWN", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private fun checkVerificationResult(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id")
        val nonce = call.argument<String>("nonce")
        if (id == null || nonce.isNullOrEmpty()) {
            result.error(INVALID_ARGUMENT, "id and nonce are required", null)
            return
        }
        // No instance (startAuthentication not called on this client, or the process was
        // restarted) → the key pair is gone; same as the native SDK: nothing to decrypt yet.
        val sdk = sdks[id] ?: run {
            result.success(null)
            return
        }
        scope.launch {
            try {
                result.success(sdk.checkVerificationResult(nonce))
            } catch (e: VerifyBlindException) {
                result.error(e.code.name, e.message, errorDetails(e))
            } catch (e: Exception) {
                result.error("UNKNOWN", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private fun sdkFor(call: MethodCall): VerifyBlindAndroidSDK {
        val id = call.argument<Int>("id") ?: throw IllegalArgumentException("id is required")
        sdks[id]?.let { return it }
        val c = call.argument<Map<String, Any?>>("config")
            ?: throw IllegalArgumentException("config is required")
        @Suppress("UNCHECKED_CAST")
        val pins = (c["certificatePins"] as? List<Any?>)?.filterIsInstance<String>()
        val config = VerifyBlindConfig(
            partnerBackendUrl = c["partnerBackendUrl"] as? String ?: "",
            generateEndpoint = c["generateEndpoint"] as? String ?: ".",
            verifyblindAppLinkBase = c["verifyblindAppLinkBase"] as? String
                ?: "https://app.verifyblind.com/request",
            verifyblindApiUrl = c["verifyblindApiUrl"] as? String ?: "https://api.verifyblind.com",
            skipSecurityChecks = c["skipSecurityChecks"] as? Boolean ?: false,
            certificatePins = pins?.takeIf { it.isNotEmpty() }
        )
        return VerifyBlindAndroidSDK(config).also { sdks[id] = it }
    }

    private fun errorDetails(e: VerifyBlindException): Map<String, Any?> =
        mapOf("cancelReason" to e.cancelReason)

    private fun Map<String, Any?>.nonNull(): Map<String, Any> {
        val out = mutableMapOf<String, Any>()
        for ((k, v) in this) if (v != null) out[k] = v
        return out
    }

    companion object {
        const val CHANNEL = "com.verifyblind/flutter"
        private const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    }
}
