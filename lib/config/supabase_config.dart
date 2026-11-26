/// Public Supabase client configuration for Trono V2.
///
/// Uses ONLY the public project URL and modern publishable key (never any
/// secret or service_role key). Access control is enforced strictly by
/// Postgres Row-Level Security (RLS).
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cxibpwmcnehnaaowpumx.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_OIH6txKAU7ZoaY2Tnu7qYg_L60cxWma',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
