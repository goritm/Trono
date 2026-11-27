package com.trono.trono

import android.app.Activity
import android.os.CancellationSignal
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/// Native Android Credential Manager "Sign in with Google" sheet helper.
/// Uses `GetSignInWithGoogleOption` (designed for explicit button taps so it
/// always launches the native Android Google account picker without Chrome)
/// and resolves `default_web_client_id` automatically from `google-services.json`.
object TronoGoogleAuth {

    private fun resolveWebClientId(activity: Activity, explicitClientId: String?): String? {
        val clean = explicitClientId?.trim().orEmpty()
        if (clean.isNotEmpty()) return clean
        val resId = activity.resources.getIdentifier(
            "default_web_client_id",
            "string",
            activity.packageName
        )
        if (resId == 0) return null
        return try {
            activity.getString(resId).trim().takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private const val TAG = "TronoGoogleAuth"

    fun signIn(
        activity: Activity,
        explicitClientId: String?,
        hashedNonce: String?,
        onResult: (Map<String, Any>) -> Unit
    ) {
        val clientId = resolveWebClientId(activity, explicitClientId)
        if (clientId == null) {
            Log.w(TAG, "No Google Web Client ID found (explicit or default_web_client_id)")
            onResult(mapOf("status" to "unavailable", "error" to "missing_web_client_id"))
            return
        }

        try {
            val signInWithGoogleOption = GetSignInWithGoogleOption.Builder(clientId)
                .apply {
                    if (!hashedNonce.isNullOrBlank()) {
                        setNonce(hashedNonce)
                    }
                }
                .build()

            val request = GetCredentialRequest.Builder()
                .addCredentialOption(signInWithGoogleOption)
                .build()

            val credentialManager = CredentialManager.create(activity)
            credentialManager.getCredentialAsync(
                context = activity,
                request = request,
                cancellationSignal = CancellationSignal(),
                executor = ContextCompat.getMainExecutor(activity),
                callback = object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                    override fun onResult(result: GetCredentialResponse) {
                        val cred = result.credential
                        if (cred is CustomCredential &&
                            cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                        ) {
                            try {
                                val googleCred = GoogleIdTokenCredential.createFrom(cred.data)
                                val idToken = googleCred.idToken.trim()
                                if (idToken.isNotEmpty()) {
                                    onResult(mapOf("status" to "ok", "idToken" to idToken))
                                    return
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "Failed parsing GoogleIdTokenCredential", e)
                                onResult(mapOf("status" to "unavailable", "error" to "parse_error: ${e.message}"))
                                return
                            }
                        }
                        Log.w(TAG, "Unexpected credential type: ${cred.type}")
                        onResult(mapOf("status" to "unavailable", "error" to "unexpected_credential: ${cred.type}"))
                    }

                    override fun onError(e: GetCredentialException) {
                        if (e is GetCredentialCancellationException) {
                            onResult(mapOf("status" to "cancelled"))
                        } else {
                            val detail = "${e.type}: ${e.errorMessage ?: e.message ?: "unknown"}"
                            Log.w(TAG, "CredentialManager error: $detail", e)
                            onResult(mapOf("status" to "unavailable", "error" to detail))
                        }
                    }
                }
            )
        } catch (e: Exception) {
            val detail = "${e.javaClass.simpleName}: ${e.message ?: "unknown"}"
            Log.w(TAG, "CredentialManager invocation failed: $detail", e)
            onResult(mapOf("status" to "unavailable", "error" to detail))
        }
    }
}
