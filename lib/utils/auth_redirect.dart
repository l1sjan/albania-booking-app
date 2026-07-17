/// Identifies Supabase's implicit-flow password recovery callback.
///
/// Supabase redirects browser clients with the recovery event in the URL
/// fragment, before Flutter has built its first screen.
bool isPasswordRecoveryCallback(Uri uri) {
  if (uri.queryParameters['type'] == 'recovery') return true;
  if (uri.fragment.isEmpty) return false;

  return Uri.splitQueryString(uri.fragment)['type'] == 'recovery';
}
