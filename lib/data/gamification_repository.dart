import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

const _kQuizCorrectKey = 'quiz_correct_total';

/// Łączna liczba poprawnych odpowiedzi w quizach (źródło XP za quizy).
class QuizScoreController extends Notifier<int> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  int build() => _prefs.getInt(_kQuizCorrectKey) ?? 0;

  /// Dodaje liczbę poprawnych odpowiedzi z ukończonego quizu.
  Future<void> addCorrect(int correct) async {
    if (correct <= 0) return;
    final next = state + correct;
    state = next;
    await _prefs.setInt(_kQuizCorrectKey, next);
  }
}

final quizScoreProvider =
    NotifierProvider<QuizScoreController, int>(QuizScoreController.new);
