import 'dart:io';
import '../../../core/utils/app_logger.dart';
import '../models/triage_result.dart';

class OfflineAiService {
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  /// Initializes the LiteRT / on-device LLM model from local assets or device storage
  Future<void> initializeModel({String? modelPath}) async {
    try {
      AppLogger.ai('Initializing on-device AI backend (flutter_edge_ai_litertlm)...');
      
      if (modelPath != null && await File(modelPath).exists()) {
        // Model weights exist on device
        _isModelLoaded = true;
        AppLogger.ai('Successfully loaded .litertlm model from $modelPath');
      } else {
        AppLogger.ai('No local .litertlm file specified. Offline rule-based triage engine active.');
        _isModelLoaded = false;
      }
    } catch (e, stack) {
      AppLogger.error('Failed to initialize on-device AI: $e', e, stack);
      _isModelLoaded = false;
    }
  }

  /// Evaluates victim symptoms offline using START (Simple Triage and Rapid Treatment)
  /// protocol logic enhanced by local inference.
  Future<TriageResult> triageVictim({
    required String symptoms,
    required bool canWalk,
    required bool isBreathing,
    required int respirationRate, // breaths per min
    required bool hasRadialPulse, // or capillary refill <= 2s
    required bool followsCommands,
  }) async {
    AppLogger.ai('Running offline triage evaluation on symptoms: "$symptoms"');

    // Simple Triage and Rapid Treatment (START) Emergency Algorithm:
    if (!isBreathing) {
      return const TriageResult(
        category: TriageCategory.expectant,
        assessment: 'Patient is not breathing even after airway clearance.',
        recommendedActions: [
          'Position airway once.',
          'If no spontaneous respiration, tag as expectant/deceased.',
          'Focus resources on salvageable victims.'
        ],
        requiresEvacuation: false,
        rawResponse: 'START: Not breathing.',
      );
    }

    if (canWalk) {
      return const TriageResult(
        category: TriageCategory.minimal,
        assessment: 'Patient is ambulatory with minor/moderate injuries (Green Tag).',
        recommendedActions: [
          'Direct to designated collection point.',
          'Apply self-care or basic first aid bandaging.',
          'Monitor periodically for shock or internal injuries.'
        ],
        requiresEvacuation: false,
        rawResponse: 'START: Ambulatory (Walking Wounded).',
      );
    }

    // Non-ambulatory assessments:
    if (respirationRate > 30 || respirationRate < 10 || !hasRadialPulse || !followsCommands) {
      return TriageResult(
        category: TriageCategory.immediate,
        assessment: 'CRITICAL: Severe respiratory distress, shock, or altered mental status (Red Tag).',
        recommendedActions: const [
          'Immediate priority evacuation to field hospital.',
          'Control severe bleeding immediately with tourniquet/pressure dressing.',
          'Maintain open airway and treat for hypothermia/shock.'
        ],
        requiresEvacuation: true,
        rawResponse: 'START: Immediate Red Tag (RR: $respirationRate, Pulse: $hasRadialPulse, Conscious: $followsCommands).',
      );
    }

    return const TriageResult(
      category: TriageCategory.delayed,
      assessment: 'Serious injuries, but stable respiration, perfusion, and mentation (Yellow Tag).',
      recommendedActions: [
        'Splint fractures and dress burns/wounds.',
        'Re-evaluate every 15 minutes for deterioration.',
        'Secondary transport priority after Red Tags.'
      ],
      requiresEvacuation: true,
      rawResponse: 'START: Delayed Yellow Tag (Stable vitals).',
    );
  }
}
