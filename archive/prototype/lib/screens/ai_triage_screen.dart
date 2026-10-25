import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../features/ai_triage/models/triage_result.dart';
import '../features/ai_triage/providers/ai_triage_provider.dart';

class AiTriageScreen extends ConsumerStatefulWidget {
  const AiTriageScreen({super.key});

  @override
  ConsumerState<AiTriageScreen> createState() => _AiTriageScreenState();
}

class _AiTriageScreenState extends ConsumerState<AiTriageScreen> {
  final _symptomsController = TextEditingController();
  bool _canWalk = false;
  bool _isBreathing = true;
  double _respirationRate = 18;
  bool _hasRadialPulse = true;
  bool _followsCommands = true;

  Color _getCategoryColor(TriageCategory category) {
    switch (category) {
      case TriageCategory.immediate:
        return AppColors.emergencyRed;
      case TriageCategory.delayed:
        return AppColors.warningOrange;
      case TriageCategory.minimal:
        return AppColors.successGreen;
      case TriageCategory.expectant:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final triageState = ref.watch(aiTriageNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ON-DEVICE AI TRIAGE'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Engine Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.infoBlue.withOpacity(0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.memory, color: AppColors.infoBlue, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Offline LiteRT AI Engine Active',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('100% On-Device • No Internet or Cloud Required',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Symptoms input
            TextField(
              controller: _symptomsController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Observed Injuries / Symptoms',
                hintText: 'e.g., Deep laceration on thigh, heavy bleeding, disoriented',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // START Protocol Quick Parameters
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RAPID PHYSIOLOGICAL VITALS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Is patient able to walk? (Ambulatory)'),
                      value: _canWalk,
                      onChanged: (v) => setState(() => _canWalk = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Is patient breathing spontaneously?'),
                      value: _isBreathing,
                      onChanged: (v) => setState(() => _isBreathing = v),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Respiration Rate (breaths/min):'),
                          Text('${_respirationRate.toInt()}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Slider(
                      min: 0,
                      max: 50,
                      divisions: 50,
                      value: _respirationRate,
                      onChanged: (v) => setState(() => _respirationRate = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Radial Pulse Present? (or Capillary Refill < 2s)'),
                      value: _hasRadialPulse,
                      onChanged: (v) => setState(() => _hasRadialPulse = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Follows simple commands? (Mental Status)'),
                      value: _followsCommands,
                      onChanged: (v) => setState(() => _followsCommands = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Evaluate Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.infoBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.analytics_outlined),
              label: Text(triageState.isEvaluating
                  ? 'ANALYZING ON-DEVICE...'
                  : 'RUN OFFLINE AI TRIAGE'),
              onPressed: triageState.isEvaluating
                  ? null
                  : () {
                      ref.read(aiTriageNotifierProvider.notifier).runTriage(
                            symptoms: _symptomsController.text,
                            canWalk: _canWalk,
                            isBreathing: _isBreathing,
                            respirationRate: _respirationRate.toInt(),
                            hasRadialPulse: _hasRadialPulse,
                            followsCommands: _followsCommands,
                          );
                    },
            ),
            const SizedBox(height: 24),

            // Triage Result Display
            if (triageState.lastResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getCategoryColor(triageState.lastResult!.category).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getCategoryColor(triageState.lastResult!.category),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          triageState.lastResult!.categoryLabel,
                          style: TextStyle(
                            color: _getCategoryColor(triageState.lastResult!.category),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (triageState.lastResult!.requiresEvacuation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('EVACUATION PRIORITY',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      triageState.lastResult!.assessment,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    const Text('RECOMMENDED ACTIONS:',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    const SizedBox(height: 6),
                    ...triageState.lastResult!.recommendedActions.map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppColors.infoBlue)),
                            Expanded(child: Text(action, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
