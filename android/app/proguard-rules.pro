# AndroidX Credential Manager & Google Identity (Sign in with Google)
# CredentialProviderFactory loads CredentialProviderPlayServicesImpl via reflection.
# Without these rules, R8 strips the Play Services credential provider in release APKs
# and CredentialManager throws GetCredentialProviderConfigurationException.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
