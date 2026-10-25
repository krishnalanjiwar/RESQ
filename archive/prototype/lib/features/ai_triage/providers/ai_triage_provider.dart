import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_ai_service.dart';
import '../models/triage_result.dart';

final offlineAiServiceProvider = Provider<OfflineAiService>((ref) {
  final service = OfflineAiService();
  service.initializeModel();
  return service;
});

class AiTriageState {
  final bool isEvaluating;
  final TriageResult? lastResult;
  final String? error;

  const AiTriageState({
    this.isEvaluating = false,
    this.lastResult,
    this.error,
  });

  AiTriageState copyWith({
    bool? isEvaluating,
    TriageResult? lastResult,
    String? error,
  }) {
    return AiTriageState(
      isEvaluating: isEvaluating ?? this.isEvaluating,
      lastResult: lastResult ?? this.lastResult,
      error: error ?? this.error,
    );
  }
}

class AiTriageNotifier extends StateNotifier<AiTriageState> {
  final OfflineAiService _service;

  AiTriageNotifier(this._service) : super(const AiTriageState());

  Future<void> runTriage({
    required String symptoms,
    required bool canWalk,
    required bool isBreathing,
    required int respirationRate,
    required bool hasRadialPulse,
    required bool followsCommands,
  }) async {
    state = state.copyWith(isEvaluating: true, error: null);
    try {
      final result = await _service.triageVictim(
        symptoms: symptoms,
        canWalk: canWalk,
        isBreathing: isBreathing,
        respirationRate: respirationRate,
        hasRadialPulse: hasRadialPulse,
        followsCommands: followsCommands,
      );
      state = state.copyWith(isEvaluating: false, lastResult: result);
    } catch (e) {
      state = state.copyWith(isEvaluating: false, error: e.toString());
    }
  }
}

final aiTriageNotifierProvider =
    StateNotifierProvider<AiTriageNotifier, AiTriageState>((ref) {
  final service = ref.watch(offlineAiServiceProvider);
  return AiTriageNotifier(service);
});
