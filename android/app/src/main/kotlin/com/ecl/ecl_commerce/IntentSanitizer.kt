package com.ecl.ecl_commerce

import android.content.Intent
import android.net.Uri

/**
 * Prevents intent redirection by never forwarding untrusted [Intent] instances.
 * Only whitelisted extras and actions are copied into a new explicit intent.
 */
object IntentSanitizer {

    private val ALLOWED_MAIN_ACTIONS = setOf(
        Intent.ACTION_MAIN,
        "OPEN_ORDER_TRACKING",
        "OPEN_NOTIFICATIONS",
    )

    private const val NOTIFICATION_PAYLOAD_KEY = "notification_payload"
    private const val MAX_PAYLOAD_LENGTH = 4096

    /**
     * Builds a safe explicit intent for [MainActivity], copying only vetted fields.
     */
    fun sanitizeMainActivityIntent(
        packageName: String,
        mainActivityClass: Class<*>,
        incoming: Intent?,
    ): Intent {
        val safe = Intent(mainActivityClass).apply {
            setPackage(packageName)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = Intent.ACTION_MAIN
        }

        if (incoming == null) {
            return safe
        }

        incoming.component?.let { component ->
            if (component.packageName != packageName ||
                component.className != mainActivityClass.name
            ) {
                return safe
            }
        }

        incoming.action?.let { action ->
            if (action in ALLOWED_MAIN_ACTIONS) {
                safe.action = action
            }
        }

        incoming.getStringExtra(NOTIFICATION_PAYLOAD_KEY)
            ?.takeIf { isValidNotificationPayload(it) }
            ?.let { safe.putExtra(NOTIFICATION_PAYLOAD_KEY, it) }

        return safe
    }

    /**
     * Strips redirect / selector fields that must not be propagated to other components.
     */
    fun sanitizeActivityResultIntent(incoming: Intent?): Intent? {
        if (incoming == null) return null

        val clean = Intent()
        copyAllowedStringExtra(
            incoming,
            clean,
            "com.expresspaygh.api.ExpressPayBrowserSwitchActivity.ORDER_ID",
        )
        copyAllowedStringExtra(
            incoming,
            clean,
            "com.expresspaygh.api.ExpressPayBrowserSwitchActivity.TOKEN",
        )
        copyAllowedStringExtra(
            incoming,
            clean,
            "com.expresspaygh.api.ExpressPayBrowserSwitchActivity.ERROR_MESSAGE",
        )
        return clean
    }

    private fun copyAllowedStringExtra(
        from: Intent,
        to: Intent,
        key: String,
    ) {
        from.getStringExtra(key)?.takeIf { it.length <= 2048 }?.let { value ->
            to.putExtra(key, value)
        }
    }

    private fun isValidNotificationPayload(payload: String): Boolean {
        if (payload.isEmpty() || payload.length > MAX_PAYLOAD_LENGTH) {
            return false
        }
        return payload.none { char ->
            char.isISOControl() && char != '\n' && char != '\r' && char != '\t'
        }
    }

    /** Validates ExpressPay deep-link URIs if a dedicated handler is added later. */
    fun isValidExpressPayCallbackUri(packageName: String, uri: Uri?): Boolean {
        if (uri == null) return false
        val expectedScheme = "$packageName.expresspaygh"
        return uri.scheme == expectedScheme && uri.host.isNullOrEmpty()
    }
}
