package com.trono.trono

import android.app.Activity
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/// Native Android Credential Manager Google One-Tap helper.
/// Resolves `default_web_client_id` automatically from `google-services.json`
/// (or an explicit client ID passed from Flutter) and returns a signed Google
/// ID token for `Supabase.auth.signInWithIdToken(...)`.
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

    fun signIn(
        activity: Activity,
        explicitClientId: String?,
        hashedNonce: String?,
        onResult: (Map<String, Any>) -> Unit
    ) {
        val clientId = resolveWebClientId(activity, explicitClientId)
        if (clientId == null) {
            onResult(mapOf("status" to "unavailable"))
            return
        }

        try {
            val googleIdOption = GetGoogleIdOption.Builder()
                .setFilterByAuthorizedAccounts(false)
                .setServerClientId(clientId)
                .apply {
                    if (!hashedNonce.isNullOrBlank()) {
                        setNonce(hashedNonce)
                    }
                }
                .build()

            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleIdOption)
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
                            } catch (_: Exception) {
                            }
                        }
                        onResult(mapOf("status" to "unavailable"))
                    }

                    override fun onError(e: GetCredentialException) {
                        if (e is GetCredentialCancellationException) {
                            onResult(mapOf("status" to "cancelled"))
                        } else {
                            onResult(mapOf("status" to "unavailable"))
                        }
                    }
                }
            )
        } catch (_: Exception) {
            onResult(mapOf("status" to "unavailable"))
        }
    }
}
