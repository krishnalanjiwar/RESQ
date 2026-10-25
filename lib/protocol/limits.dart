/// Protocol bounds. Every inbound frame is checked against these before any
/// other processing, so hostile input can't exhaust memory, battery or the radio.
abstract final class Limits {
  static const int protocolVersion = 1;

  /// Largest frame we accept or send. Nearby BYTES payloads cap at 32 KiB.
  static const int maxFrameBytes = 16 * 1024;
  static const int maxJsonDepth = 8;

  /// Hop budget for flooding. Frames claiming more are clamped down.
  static const int maxTtl = 8;

  static const int maxSosTextChars = 500;
  static const int maxProfileTextChars = 300;
  static const int maxNoteChars = 120;

  /// Message lifetimes; frames whose expiry exceeds these are rejected.
  static const Duration sosLifetime = Duration(hours: 24);
  static const Duration eventLifetime = Duration(hours: 24);
  static const Duration beaconLifetime = Duration(minutes: 5);
  static const Duration hazardLifetime = Duration(hours: 6);
  static const Duration credentialLifetime = Duration(days: 30);
  static const Duration revocationLifetime = Duration(days: 30);
  static const Duration vouchLifetime = Duration(days: 30);
  static const Duration linkLifetime = Duration(minutes: 1);

  /// Clock skew tolerated on sender timestamps (they are claims, not facts).
  /// Phone clocks drift or reset after a dead battery; 30 min keeps such phones
  /// in the mesh while still bounding how long a message can be made to live.
  static const Duration maxFutureSkew = Duration(minutes: 30);

  /// Peer clock offset beyond which the UI warns that this phone's clock may be wrong.
  static const Duration clockWarningSkew = Duration(minutes: 5);

  /// Heartbeats only need to outlive the orphan timeout, not a whole day.
  static const Duration heartbeatLifetime = Duration(minutes: 15);

  /// Per-link flood control (token bucket). The burst must exceed the
  /// store-and-forward replay a healthy peer sends on connect (syncBatchMax
  /// plus link frames), otherwise honest neighbours get quarantined.
  static const double linkMessagesPerSecond = 8;
  static const int linkBurst = 260;
  static const int linkStrikesBeforeQuarantine = 60;
  static const Duration linkQuarantine = Duration(minutes: 10);

  /// Per-origin limits on what we are willing to relay.
  static const int originSosPerTenMinutes = 6;
  static const int originEventsPerTenMinutes = 40;

  /// Cap on frames replayed to a newly connected peer.
  static const int syncBatchMax = 200;
  static const int syncBatchMaxLowPower = 50;

  /// Sybil heuristics.
  static const int sybilIdentitiesPerLink = 3;
  static const int colocatedClusterSize = 4;
  static const double colocatedRadiusM = 25;
}
