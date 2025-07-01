package com.example.eclapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.expresspaygh.api.ExpressPayApi
import com.expresspaygh.api.ExpressPayApi.ExpressPayPaymentCompletionListener
import org.json.JSONObject

class MainActivity: FlutterActivity(), ExpressPayPaymentCompletionListener {
    private val CHANNEL = "com.yourcompany.expresspay"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startExpressPay") {
                val params = call.arguments as? HashMap<String, String>
                if (params != null) {
                    if (pendingResult != null) {
                        // There is already a pending payment
                        result.error("ALREADY_RUNNING", "A payment is already in progress", null)
                        return@setMethodCallHandler
                    }
                    try {
                        pendingResult = result // Store for later use
                        val expressPayApi = ExpressPayApi(this, "https://eclcommerce.ernestchemists.com.gh/api/expresspayment")
                        expressPayApi.setDebugMode(true)
                        expressPayApi.submitAndCheckout(params, this, object : ExpressPayApi.ExpressPayPaymentCompletionListener {
                            override fun onExpressPayPaymentFinished(paymentCompleted: Boolean, errorMessage: String?) {
                                handlePaymentResult(paymentCompleted, errorMessage)
                            }
                        })
                        println("DEBUG: submitAndCheckout called")
                        // Add a submit listener to log the server response
                        expressPayApi.submit(params, this, object : ExpressPayApi.ExpressPaySubmitCompletionListener {
                            override fun onExpressPaySubmitFinished(response: org.json.JSONObject?, errorMessage: String?) {
                                println("ExpressPay SUBMIT server response: " + response?.toString())
                                println("ExpressPay SUBMIT error message: $errorMessage")
                                if (response != null && response.has("token")) {
                                    println("ExpressPay SUBMIT token: " + response.getString("token"))
                                    // Pass through the raw response
                                    if (pendingResult != null) {
                                        pendingResult?.success(response.toString())
                                        pendingResult = null
                                    }
                                } else {
                                    println("ExpressPay SUBMIT: No token in response!")
                                    // Pass through the raw response even if there's no token
                                    if (pendingResult != null) {
                                        pendingResult?.success(response?.toString() ?: "{}")
                                        pendingResult = null
                                    }
                                }
                                // If there is an error message, surface it to Flutter immediately
                                if (errorMessage != null && errorMessage.isNotEmpty()) {
                                    if (pendingResult != null) {
                                        pendingResult?.success(mapOf("success" to false, "message" to errorMessage))
                                        pendingResult = null
                                    }
                                }
                            }
                        })
                    } catch (e: Exception) {
                        println("ERROR: Exception in payment logic: ${e.message}")
                        result.error("UNEXPECTED_ERROR", e.message ?: "An unexpected error occurred", null)
                        pendingResult = null
                    }
                } else {
                    result.error("INVALID_PARAMS", "Params are null or invalid", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handlePaymentResult(paymentCompleted: Boolean, errorMessage: String?) {
        println("DEBUG: handlePaymentResult called with paymentCompleted=$paymentCompleted, errorMessage=$errorMessage")
        val result = pendingResult
        pendingResult = null
        if (result != null) {
            if (paymentCompleted) {
                result.success(mapOf("success" to true))
            } else {
                result.success(mapOf("success" to false, "message" to (errorMessage ?: "Payment failed")))
            }
        }
    }

    // This is called by the SDK when payment is finished
    override fun onExpressPayPaymentFinished(paymentCompleted: Boolean, errorMessage: String?) {
        handlePaymentResult(paymentCompleted, errorMessage)
    }
}