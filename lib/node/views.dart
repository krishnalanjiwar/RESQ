import '../domain/chain/evaluation_chain.dart';
import '../domain/dispatch/matcher.dart';
import '../domain/reconcile/reconciler.dart';
import '../domain/trust/trust_agent.dart';
import '../domain/world.dart';

/// Local-first delivery stages. A local save is never shown as a remote delivery.
enum DeliveryStage {
  savedLocally('SAVED LOCALLY — NOT YET SENT'),
  waitingForPeer('WAITING FOR A NEARBY PEER'),
  sentToPeers('SENT TO CONNECTED PEERS'),
  acknowledged('PEER ACKNOWLEDGED');

  const DeliveryStage(this.label);

  final String label;
}

class DeliveryStatus {
  const DeliveryStatus(this.stage, this.sentTo, this.acks);

  final DeliveryStage stage;
  final int sentTo;
  final int acks;
}

class MySosView {
  const MySosView({required this.sos, required this.state, required this.delivery});

  final SosRecord sos;
  final SosState state;
  final DeliveryStatus delivery;

  /// What the requester should read. Acceptance never claims departure or arrival.
  String get headline {
    if (state.conflicts.contains('MULTIPLE_ON_SCENE')) return 'STATUS CONFLICT — RECONCILIATION REQUIRED';
    return switch (state.phase) {
      SosPhase.searching => state.reopened ? 'RESPONDER LOST CONTACT — SEARCHING AGAIN' : delivery.stage.label,
      _ => state.phase.label,
    };
  }
}

class OfferView {
  const OfferView({required this.assignment, required this.justification, required this.windowRemaining});

  final Assignment assignment;
  final String justification;

  /// Informational only: when it reaches zero the offer moves on. It never accepts.
  final Duration windowRemaining;
}

class EngagementView {
  const EngagementView({
    required this.sos,
    required this.state,
    required this.myProgress,
    required this.standDown,
    required this.isPrimary,
  });

  final SosRecord sos;
  final SosState state;
  final int myProgress;
  final bool standDown;
  final bool isPrimary;
}

class OpenRequestView {
  const OpenRequestView({
    required this.sos,
    required this.state,
    required this.assignedTo,
    required this.unmatchedReason,
    required this.myResult,
  });

  final SosRecord sos;
  final SosState state;
  final String? assignedTo;
  final String? unmatchedReason;
  final ChainResult? myResult;
}

class PeerView {
  const PeerView({
    required this.endpoint,
    required this.identity,
    required this.beacon,
    required this.trust,
    required this.directIdentities,
  });

  final String endpoint;
  final String? identity;
  final BeaconRecord? beacon;
  final TrustAssessment? trust;

  /// Distinct identities that originated traffic over this link (Sybil signal).
  final int directIdentities;
}

class DiagnosticsCounts {
  const DiagnosticsCounts({
    required this.liveMessages,
    required this.sosKnown,
    required this.beaconsKnown,
    required this.hazardsKnown,
    required this.outboxPending,
    required this.seenCacheSize,
    required this.quarantinedLinks,
    required this.penalisedIdentities,
    required this.connectedPeers,
  });

  final int liveMessages;
  final int sosKnown;
  final int beaconsKnown;
  final int hazardsKnown;
  final int outboxPending;
  final int seenCacheSize;
  final int quarantinedLinks;
  final int penalisedIdentities;
  final int connectedPeers;
}
