/// Konfiguracja Supabase (ranking rodzinny).
///
/// Używamy tego samego projektu Supabase co aplikacja „Kalendazyk" — wystarczy
/// dodać w nim osobną tabelę `reading_scores` (SQL w README/DEPLOYMENT).
///
/// Anon key jest *publiczny* (chroniony przez Row-Level Security). Service role
/// key NIGDY nie powinien się tu znaleźć.
class SupabaseConfig {
  static const String url = 'https://tkvxeozttwxxfpvmvvwp.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrdnhlb3p0dHd4eGZwdm12dndwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwODkxNzQsImV4cCI6MjA5NDY2NTE3NH0._fcfp0YXEqb1rE5aEQ4Ci_ojOINqUUVHqabPTUE0GjQ';

  static bool get isConfigured => url.startsWith('https://');
}
