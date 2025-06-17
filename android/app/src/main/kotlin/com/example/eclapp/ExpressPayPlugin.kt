package com.example.eclapp

import android.app.Activity
import android.content.Intent
import androidx.annotation.NonNull
import com.expresspaygh.api.ExpressPayApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.util.HashMap
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.util.Log
import okhttp3.MediaType
import okhttp3.RequestBody
import okhttp3.ResponseBody
import java.util.concurrent.TimeUnit
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

class ExpressPayPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var expressPayApi: ExpressPayApi? = null
    private var pendingResult: Result? = null
    private var currentRequestCode: Int = 0

    companion object {
        private const val REQUEST_CODE_SUBMIT_AND_CHECKOUT = 1001
        private const val REQUEST_CODE_CHECKOUT = 1002
        private const val REQUEST_CODE_CHECKOUT_WITH_TOKEN = 1003
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.yourcompany.expresspay")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        if (call.method == "startExpressPay") {
            val params = call.arguments as? Map<String, String>
            if (params == null) {
                result.error("INVALID_ARGUMENTS", "Arguments are required", null)
                return
            }

            // Create a coroutine scope for the API call
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val client = OkHttpClient.Builder()
                        .connectTimeout(30, TimeUnit.SECONDS)
                        .readTimeout(30, TimeUnit.SECONDS)
                        .writeTimeout(30, TimeUnit.SECONDS)
                        .build()

                    val jsonBody = JSONObject(params).toString()
                    val requestBody = jsonBody.toRequestBody("application/json".toMediaType())

                    val request = Request.Builder()
                        .url("https://eclcommerce.ernestchemists.com.gh/api/expresspayment")
                        .post(requestBody)
                        .header("Accept", "application/json")
                        .build()

                    val response = client.newCall(request).execute()
                    val responseBody = response.body?.string()

                    withContext(Dispatchers.Main) {
                        if (response.isSuccessful && responseBody != null) {
                            try {
                                val jsonResponse = JSONObject(responseBody)
                                result.success(jsonResponse.toString())
                            } catch (e: Exception) {
                                Log.e("ExpressPayPlugin", "Error parsing response: ${e.message}")
                                result.error("PARSE_ERROR", "Error parsing response", e.message)
                            }
                        } else {
                            Log.e("ExpressPayPlugin", "API call failed: ${response.code}")
                            result.error("API_ERROR", "API call failed", "Status code: ${response.code}")
                        }
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        Log.e("ExpressPayPlugin", "Error making API call: ${e.message}")
                        result.error("API_ERROR", "Error making API call", e.message)
                    }
                }
            }
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (expressPayApi != null && activity != null && pendingResult != null &&
            (requestCode == REQUEST_CODE_SUBMIT_AND_CHECKOUT ||
                    requestCode == REQUEST_CODE_CHECKOUT ||
                    requestCode == REQUEST_CODE_CHECKOUT_WITH_TOKEN)) {

            expressPayApi?.onActivityResult(activity!!, requestCode, resultCode, data)

            // We handle callback results in their respective listeners
            // This is just to make sure we catch any unhandled results
            if (requestCode != currentRequestCode) {
                val resultMap = HashMap<String, Any?>()
                resultMap["success"] = false
                resultMap["message"] = "Payment cancelled or failed"

                activity?.runOnUiThread {
                    pendingResult?.success(resultMap)
                    pendingResult = null
                }
            }

            return true
        }
        return false
    }
}