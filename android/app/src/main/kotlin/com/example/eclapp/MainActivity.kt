package com.example.eclapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.expresspaygh.api.ExpressPayApi
import com.expresspaygh.api.ExpressPayApi.ExpressPayPaymentCompletionListener
import org.json.JSONObject
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class MainActivity: FlutterActivity(), ExpressPayPaymentCompletionListener {
    private val CHANNEL = "com.yourcompany.expresspay"
    private val NOTIFICATION_CHANNEL = "ecl_notifications"
    private var pendingResult: MethodChannel.Result? = null
    private var notificationPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        println("🔧 Android: MainActivity configureFlutterEngine called")
        
        // Set up notification channel
        println("🔧 Android: Setting up notification method channel...")
        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
        val notificationChannel = MethodChannel(binaryMessenger, NOTIFICATION_CHANNEL)
        notificationChannel.setMethodCallHandler { call, result ->
            println("🔧 Android: Received method call: ${call.method}")
            when (call.method) {
                "requestPermissions" -> {
                    println("🔧 Android: Handling requestPermissions")
                    // Permissions are handled automatically on Android 13+
                    result.success("Permissions requested successfully")
                }
                "test" -> {
                    println("🔧 Android: Handling test method")
                    result.success("Android method channel is working!")
                }
                "showNotification" -> {
                    println("🔧 Android: Handling showNotification")
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val payload = call.argument<String>("payload")
                    
                    println("🔧 Android: Showing notification - ID: $id, Title: $title, Body: $body")
                    showNotification(id, title, body, payload)
                    result.success(null)
                }
                "cancelAllNotifications" -> {
                    println("🔧 Android: Handling cancelAllNotifications")
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancelAll()
                    result.success(null)
                }
                "areNotificationsEnabled" -> {
                    println("🔧 Android: Handling areNotificationsEnabled")
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val enabled = notificationManager.areNotificationsEnabled()
                    result.success(enabled)
                }
                "getNotificationPayload" -> {
                    println("🔧 Android: Handling getNotificationPayload")
                    result.success(notificationPayload)
                }
                "onNotificationOpened" -> {
                    println("🔧 Android: Handling onNotificationOpened")
                    // This is called from Android side, no need to do anything here
                    result.success(null)
                }
                else -> {
                    println("🔧 Android: Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
        println("🔧 Android: Notification method channel setup complete")
        
        val expressPayChannel = MethodChannel(binaryMessenger, CHANNEL)
        expressPayChannel.setMethodCallHandler { call, result ->
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
    
    // Handle when app is opened from notification
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        println("🔧 Android: onNewIntent called")
        
        val payload = intent.getStringExtra("notification_payload")
        val action = intent.action
        
        println("🔧 Android: Intent action: $action")
        println("🔧 Android: Received notification payload: $payload")
        
        if (payload != null) {
            notificationPayload = payload
            
            // Immediately send the payload to Flutter with action
            try {
                val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
                if (binaryMessenger != null) {
                    val notificationChannel = MethodChannel(binaryMessenger, NOTIFICATION_CHANNEL)
                    val data = mapOf(
                        "payload" to payload,
                        "action" to (action ?: "OPEN_NOTIFICATIONS")
                    )
                    // Use invokeMethod with null result for faster execution
                    notificationChannel.invokeMethod("onNotificationOpened", data, null)
                    println("🔧 Android: Sent payload to Flutter immediately with action: $action")
                } else {
                    println("🔧 Android: binaryMessenger is null, cannot send payload to Flutter")
                }
            } catch (e: Exception) {
                println("🔧 Android: Error sending payload to Flutter: $e")
            }
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ecl_notifications",
                "ECL Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for ECL Pharmacy App"
                enableLights(true)
                enableVibration(true)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun showNotification(id: Int, title: String, body: String, payload: String?) {
        createNotificationChannel()
        
        // Create optimized intent for faster app launch
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notification_payload", payload)
            
            // Add specific action for faster routing
            if (payload != null && payload.contains("order_placed")) {
                action = "OPEN_ORDER_TRACKING"
            } else if (payload != null && payload.contains("test")) {
                action = "OPEN_NOTIFICATIONS"
            } else {
                action = "OPEN_NOTIFICATIONS"
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            id, // Use unique ID for each notification
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "ecl_notifications")
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setColor(0xFF22C55E.toInt()) // Green color
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(id, notification)
    }
}