import '../../protocol/envelope.dart';
import '../../protocol/limits.dart';

enum PowerMode {
  normal('NORMAL'),
  low('LOW POWER — DISCOVERY REDUCED'),
  critical('CRITICAL POWER — RELAYING EMERGENCIES ONLY'),
  unknown('BATTERY READING UNAVAILABLE');

  const PowerMode(this.label);

  final String label;
}

/// Battery-aware relay policy. Low power sheds non-essential work first
/// (others' beacons, low-urgency SOS); the emergency receive path stays open.
/// A diagnostics override is kept separate from the real reading.
class PowerPolicy {
  const PowerPolicy({required this.realLevel, this.overrideLevel});

  final int? realLevel;
  final int? overrideLevel;

  static const int lowThreshold = 20;
  static const int criticalThreshold = 8;

  int? get effectiveLevel => overrideLevel ?? realLevel;

  bool get isSimulatedOverride => overrideLevel != null;

  PowerMode get mode {
    final level = effectiveLevel;
    if (level == null) return PowerMode.unknown;
    if (level <= criticalThreshold) return PowerMode.critical;
    if (level <= lowThreshold) return PowerMode.low;
    return PowerMode.normal;
  }

  Duration get beaconInterval => switch (mode) {
        PowerMode.normal || PowerMode.unknown => const Duration(seconds: 60),
        PowerMode.low => const Duration(seconds: 180),
        PowerMode.critical => const Duration(seconds: 300),
      };

  int get syncBatch => mode == PowerMode.normal || mode == PowerMode.unknown
      ? Limits.syncBatchMax
      : Limits.syncBatchMaxLowPower;

  /// Whether to relay someone else's envelope in the current mode.
  bool shouldRelay(Envelope env) {
    switch (mode) {
      case PowerMode.normal || PowerMode.unknown:
        return true;
      case PowerMode.low:
        if (env.type == MsgType.beacon) return false;
        if (env.type == MsgType.sos) return env.urg != 'LOW';
        return true;
      case PowerMode.critical:
        if (env.type == MsgType.sos) return env.urg == 'CRITICAL' || env.urg == 'UNKNOWN';
        return env.type == MsgType.event || env.type == MsgType.revocation;
    }
  }
}
