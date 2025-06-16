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

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startExpressPay" -> {
                handleSubmitAndCheckout(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleSubmitAndCheckout(call: MethodCall, result: Result) {
        if (expressPayApi == null) {
            result.error("NOT_INITIALIZED", "ExpressPay API not initialized", null)
            return
        }

        val params = createParamsMap(call)
        pendingResult = result
        currentRequestCode = REQUEST_CODE_SUBMIT_AND_CHECKOUT

        expressPayApi?.submit(params, activity!!, object : ExpressPayApi.ExpressPaySubmitCompletionListener {
            override fun onExpressPaySubmitFinished(response: org.json.JSONObject?, errorMessage: String?) {
                println("ExpressPay SUBMIT server response: " + response?.toString())
                println("ExpressPay SUBMIT error message: $errorMessage")
                
                // Create a result map with all the response data
                val resultMap = HashMap<String, Any?>()
                
                if (response != null) {
                    // Copy all fields from the response
                    val iterator = response.keys()
                    while (iterator.hasNext()) {
                        val key = iterator.next()
                        resultMap[key] = response.get(key)
                    }
                    
                    // Ensure success is set based on status
                    resultMap["success"] = response.optInt("status", 0) == 1
                    
                    println("ExpressPay SUBMIT processed response: $resultMap")
                } else {
                    resultMap["success"] = false
                    resultMap["message"] = errorMessage ?: "No response from server"
                }
                
                // Pass through the result map
                if (pendingResult != null) {
                    pendingResult?.success(resultMap)
                    pendingResult = null
                }
            }
        })
    }

    private fun createParamsMap(call: MethodCall): HashMap<String, String> {
        val params = HashMap<String, String>()

        call.argument<String>("currency")?.let { params["currency"] = it }
        call.argument<String>("amount")?.let { params["amount"] = it }
        call.argument<String>("order_id")?.let { params["order_id"] = it }
        call.argument<String>("order_desc")?.let { params["order_desc"] = it }
        call.argument<String>("account_number")?.let { params["account_number"] = it }
        call.argument<String>("email")?.let { params["email"] = it }
        call.argument<String>("redirect_url")?.let { params["redirect_url"] = it }
        call.argument<String>("order_img_url")?.let { params["order_img_url"] = it }
        call.argument<String>("first_name")?.let { params["first_name"] = it }
        call.argument<String>("last_name")?.let { params["last_name"] = it }
        call.argument<String>("phone_number")?.let { params["phone_number"] = it }

        return params
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