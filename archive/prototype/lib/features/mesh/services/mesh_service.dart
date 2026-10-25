import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter_nearby_connections_plus/flutter_nearby_connections_plus.dart';
import '../../../core/network/packet_protocol.dart';
import '../../../core/utils/app_logger.dart';
import '../../storage/services/hive_storage_service.dart';
import '../../storage/models/sos_message.dart';
import '../models/peer_device.dart';

class MeshService {
  final NearbyConnections _nearby = NearbyConnections();
  final String localNodeId;
  final String serviceId = 'com.resq.mesh';
  final Strategy strategy = Strategy.P2P_CLUSTER; // High density mesh cluster

  // Track discovered and connected peers
  final Map<String, PeerDevice> _peers = {};
  final List<Device> _connectedDevices = [];

  // Deduplication LRU cache (Bitchat spec: 1000 items, 5-min TTL)
  static const int _maxSeenEntries = 1000;
  static const Duration _seenTtl = Duration(minutes: 5);
  final LinkedHashMap<String, DateTime> _seenPacketIds = LinkedHashMap();

  // Relay jitter RNG (Bitchat spec: 10-220ms random delay)
  final Random _jitterRng = Random();

  // Stream controllers
  final _peerStreamController = StreamController<List<PeerDevice>>.broadcast();
  final _packetStreamController = StreamController<MeshPacket>.broadcast();
  final _sosStreamController = StreamController<SosMessage>.broadcast();

  Stream<List<PeerDevice>> get peerStream => _peerStreamController.stream;
  Stream<MeshPacket> get packetStream => _packetStreamController.stream;
  Stream<SosMessage> get sosStream => _sosStreamController.stream;

  MeshService({required this.localNodeId});

  /// Starts dual-role P2P Mesh (simultaneous advertising and discovery)
  Future<void> startMesh() async {
    try {
      AppLogger.mesh('Initializing P2P Mesh (Node: $localNodeId)...');
      await _nearby.initService(
        serviceType: serviceId,
        strategy: strategy,
        callback: (isRunning) {
          AppLogger.mesh('Nearby Connections status changed: isRunning=$isRunning');
        },
      );

      // Start Advertising as a Peripheral node
      await _nearby.startAdvertising(
        localNodeId,
        strategy: strategy,
        serviceId: serviceId,
      );
      AppLogger.mesh('Started BLE/P2P advertising as $localNodeId');

      // Start Discovering other Central/Peripheral nodes
      await _nearby.startDiscovery(
        localNodeId,
        strategy: strategy,
        serviceId: serviceId,
      );
      AppLogger.mesh('Started BLE/P2P discovery for peers');

      // Subscribe to device state events
      _nearby.stateChangedSubscription(callback: (devicesList) {
        _handleDeviceStateChanges(devicesList);
      });

      // Subscribe to received data payloads
      _nearby.dataReceivedSubscription(callback: (data) {
        _handleIncomingPayload(data['message'] ?? '', data['deviceId'] ?? '');
      });
    } catch (e, stack) {
      AppLogger.error('Error starting P2P mesh: $e', e, stack);
    }
  }

  void _handleDeviceStateChanges(List<Device> devices) {
    _connectedDevices.clear();
    for (var device in devices) {
      PeerConnectionState state = PeerConnectionState.discovered;
      if (device.state == SessionState.connected) {
        state = PeerConnectionState.connected;
        _connectedDevices.add(device);
        _flushOfflineOutboxToDevice(device);
      } else if (device.state == SessionState.connecting) {
        state = PeerConnectionState.connecting;
      }

      _peers[device.deviceId] = PeerDevice(
        endpointId: device.deviceId,
        endpointName: device.deviceName,
        state: state,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      // Automatically connect to discovered peers to expand mesh
      if (device.state == SessionState.notConnected) {
        _nearby.connectToDevice(device.deviceId);
      }
    }
    _peerStreamController.add(_peers.values.toList());
  }

  /// Broadcasts a packet across all connected peers in the mesh
  Future<void> broadcastPacket(MeshPacket packet) async {
    _markSeen(packet.id);
    final jsonStr = packet.toJson();

    for (var device in _connectedDevices) {
      try {
        await _nearby.sendMessage(device.deviceId, jsonStr);
        AppLogger.mesh('Sent packet ${packet.id} to peer ${device.deviceName}');
      } catch (e) {
        AppLogger.warning('Failed sending to ${device.deviceId}: $e');
      }
    }

    // If no peers are currently connected, store in offline outbox (Bitchat store-and-forward)
    if (_connectedDevices.isEmpty) {
      AppLogger.mesh('No peers in radio range. Storing packet in offline outbox.');
      await HiveStorageService.queueOutgoingPacket(packet.id, packet.toMap());
    }
  }

  /// Broadcast an SOS Beacon to all nodes in the mesh
  Future<void> broadcastSos(SosMessage sos) async {
    final packet = MeshPacket(
      id: sos.id,
      senderId: localNodeId,
      recipientId: 'broadcast',
      type: PacketType.sosBeacon,
      timestamp: sos.timestamp,
      payload: sos.toMap(),
    );

    // Persist locally
    await HiveStorageService.saveSosMessage(sos);
    // Broadcast over mesh
    await broadcastPacket(packet);
    _sosStreamController.add(sos);
  }

  /// Handles incoming packet with deduplication and multi-hop TTL relaying
  /// Checks if a packet ID has been seen within the TTL window
  bool _hasSeen(String packetId) {
    final timestamp = _seenPacketIds[packetId];
    if (timestamp == null) return false;
    if (DateTime.now().difference(timestamp) > _seenTtl) {
      _seenPacketIds.remove(packetId);
      return false;
    }
    return true;
  }

  /// Marks a packet ID as seen, evicting oldest entries if over capacity
  void _markSeen(String packetId) {
    _seenPacketIds[packetId] = DateTime.now();
    // Evict oldest entries if LRU exceeds capacity
    while (_seenPacketIds.length > _maxSeenEntries) {
      _seenPacketIds.remove(_seenPacketIds.keys.first);
    }
  }

  void _handleIncomingPayload(String rawMessage, String fromDeviceId) {
    try {
      final packet = MeshPacket.fromJson(rawMessage);

      // Deduplication: drop if seen recently (LRU + TTL)
      if (_hasSeen(packet.id)) {
        AppLogger.mesh('Dropped duplicate packet: ${packet.id}');
        return;
      }
      _markSeen(packet.id);

      AppLogger.mesh('Received packet ${packet.id} (Type: ${packet.type.name}, TTL: ${packet.ttl}, Hops: ${packet.hops})');
      _packetStreamController.add(packet);

      if (packet.type == PacketType.sosBeacon) {
        final sos = SosMessage.fromMap(packet.payload);
        HiveStorageService.saveSosMessage(sos);
        _sosStreamController.add(sos);
      }

      // Multi-hop Forwarding: If TTL > 1, decay TTL and relay with jitter
      if (packet.ttl > 1) {
        final relayedPacket = packet.copyWithDecayedTtl();
        final relayedJson = relayedPacket.toJson();

        for (var device in _connectedDevices) {
          if (device.deviceId != fromDeviceId) { // Split horizon: don't reflect back
            // Random relay jitter (10-220ms) to prevent broadcast storms
            final jitterMs = 10 + _jitterRng.nextInt(211);
            Future.delayed(Duration(milliseconds: jitterMs), () {
              _nearby.sendMessage(device.deviceId, relayedJson);
              AppLogger.mesh('Relayed packet ${relayedPacket.id} to ${device.deviceName} (TTL: ${relayedPacket.ttl}, jitter: ${jitterMs}ms)');
            });
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Could not parse mesh payload: $e');
    }
  }

  void _flushOfflineOutboxToDevice(Device device) async {
    final queued = HiveStorageService.getQueuedPackets();
    if (queued.isEmpty) return;

    AppLogger.mesh('Flushing ${queued.length} offline outbox packets to newly connected peer ${device.deviceName}');
    for (var item in queued) {
      final packet = MeshPacket.fromMap(item);
      await _nearby.sendMessage(device.deviceId, packet.toJson());
      await HiveStorageService.removeFromOutbox(packet.id);
    }
  }

  Future<void> stopMesh() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    _peerStreamController.close();
    _packetStreamController.close();
    _sosStreamController.close();
  }
}
