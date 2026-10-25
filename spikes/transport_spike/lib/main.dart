// Phase 0 transport spike (throwaway). Compares the two candidate packages on
// real phones: discovery, connection, PING/PONG round-trip, and payload size.
// APIs used here were checked against the resolved package sources:
// nearby_connections 4.3.0 and flutter_nearby_connections_plus 1.2.2.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections_plus/flutter_nearby_connections_plus.dart' as fnc;
import 'package:nearby_connections/nearby_connections.dart' as nc;
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const SpikeApp());

typedef LogFn = void Function(String line);
typedef MessageFn = void Function(String peerId, String message);
typedef PeersFn = void Function(Map<String, String> connected);

abstract class SpikeTransport {
  String get label;
  Future<void> start(String myName, {required LogFn log, required MessageFn onMessage, required PeersFn onPeers});
  Future<void> send(String peerId, String message);
  Future<void> stop();
}

/// nearby_connections 4.3.0: explicit request/accept, raw bytes payloads.
class NearbyConnectionsTransport implements SpikeTransport {
  static const _serviceId = 'com.darubaaz.resq.spike';
  final nc.Nearby _nearby = nc.Nearby();
  final Map<String, String> _connected = {};
  final Map<String, String> _pendingNames = {};
  late LogFn _log;
  late MessageFn _onMessage;
  late PeersFn _onPeers;
  late String _me;

  @override
  String get label => 'nearby_connections 4.3.0';

  void _onInitiated(String id, nc.ConnectionInfo info) {
    _pendingNames[id] = info.endpointName;
    _log('initiated $id (${info.endpointName}) incoming=${info.isIncomingConnection} token=${info.authenticationToken}');
    _nearby.acceptConnection(id, onPayLoadRecieved: (endpointId, payload) {
      if (payload.type == nc.PayloadType.BYTES && payload.bytes != null) {
        _onMessage(endpointId, utf8.decode(payload.bytes!));
      }
    });
  }

  void _onResult(String id, nc.Status status) {
    _log('result $id: ${status.name}');
    if (status == nc.Status.CONNECTED) {
      _connected[id] = _pendingNames[id] ?? id;
      _onPeers(Map.of(_connected));
    }
  }

  void _onDisconnected(String id) {
    _log('disconnected $id');
    _connected.remove(id);
    _onPeers(Map.of(_connected));
  }

  @override
  Future<void> start(String myName, {required LogFn log, required MessageFn onMessage, required PeersFn onPeers}) async {
    _me = myName;
    _log = log;
    _onMessage = onMessage;
    _onPeers = onPeers;
    final adv = await _nearby.startAdvertising(
      _me,
      nc.Strategy.P2P_CLUSTER,
      onConnectionInitiated: _onInitiated,
      onConnectionResult: _onResult,
      onDisconnected: _onDisconnected,
      serviceId: _serviceId,
    );
    _log('advertising: $adv');
    final disc = await _nearby.startDiscovery(
      _me,
      nc.Strategy.P2P_CLUSTER,
      onEndpointFound: (id, name, serviceId) {
        _log('found $id ($name)');
        // Tie-break so only one side requests, avoiding simultaneous-dial collisions.
        if (_me.compareTo(name) < 0) {
          _nearby.requestConnection(
            _me,
            id,
            onConnectionInitiated: _onInitiated,
            onConnectionResult: _onResult,
            onDisconnected: _onDisconnected,
          );
        }
      },
      onEndpointLost: (id) => _log('lost $id'),
      serviceId: _serviceId,
    );
    _log('discovering: $disc');
  }

  @override
  Future<void> send(String peerId, String message) =>
      _nearby.sendBytesPayload(peerId, Uint8List.fromList(utf8.encode(message)));

  @override
  Future<void> stop() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    _connected.clear();
  }
}

/// flutter_nearby_connections_plus 1.2.2: NearbyService, string messages.
class NearbyPlusTransport implements SpikeTransport {
  final fnc.NearbyService _service = fnc.NearbyService();
  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _dataSub;
  final Set<String> _invited = {};

  @override
  String get label => 'flutter_nearby_connections_plus 1.2.2';

  @override
  Future<void> start(String myName, {required LogFn log, required MessageFn onMessage, required PeersFn onPeers}) async {
    await _service.init(
      serviceType: 'resqspike',
      strategy: fnc.Strategy.P2P_CLUSTER,
      deviceName: myName,
      callback: (dynamic isRunning) async {
        log('service running: $isRunning');
        if (isRunning == true) {
          await _service.startAdvertisingPeer(deviceName: myName);
          await _service.startBrowsingForPeers();
          log('advertising + browsing started');
        }
      },
    );
    _stateSub = _service.stateChangedSubscription(callback: (devices) {
      final connected = <String, String>{};
      for (final d in devices) {
        log('device ${d.deviceId} (${d.deviceName}) ${d.state.name}');
        if (d.state == fnc.SessionState.connected) {
          connected[d.deviceId] = d.deviceName;
        } else if (d.state == fnc.SessionState.notConnected &&
            myName.compareTo(d.deviceName) < 0 &&
            _invited.add(d.deviceId)) {
          _service.invitePeer(deviceID: d.deviceId, deviceName: d.deviceName);
        }
      }
      onPeers(connected);
    });
    _dataSub = _service.dataReceivedSubscription(callback: (dynamic data) {
      if (data is Map) {
        onMessage('${data['deviceId']}', '${data['message']}');
      } else {
        log('unexpected data shape: ${data.runtimeType}');
      }
    });
  }

  @override
  Future<void> send(String peerId, String message) async => _service.sendMessage(peerId, message);

  @override
  Future<void> stop() async {
    await _stateSub?.cancel();
    await _dataSub?.cancel();
    await _service.stopAdvertisingPeer();
    await _service.stopBrowsingForPeers();
    _invited.clear();
  }
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const SpikeScreen(),
      );
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final String _me = 'spike-${(Random().nextInt(0xFFFF)).toRadixString(16).padLeft(4, '0')}';
  final List<String> _log = [];
  Map<String, String> _peers = {};
  SpikeTransport? _transport;
  int _seq = 0, _pingsSent = 0, _pongs = 0, _bigSent = 0, _bigReceived = 0;
  final List<int> _rtts = [];

  void _addLog(String line) {
    final t = DateTime.now().toIso8601String().substring(11, 23);
    setState(() => _log.insert(0, '$t $line'));
  }

  Future<void> _start(SpikeTransport transport) async {
    final statuses = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
    statuses.forEach((p, s) => _addLog('perm $p: ${s.name}'));
    setState(() => _transport = transport);
    _addLog('starting ${transport.label} as $_me');
    try {
      await transport.start(_me, log: _addLog, onMessage: _onMessage, onPeers: (p) => setState(() => _peers = p));
    } catch (e) {
      _addLog('START ERROR: $e');
    }
  }

  void _onMessage(String peerId, String message) {
    final parts = message.split('|');
    switch (parts.first) {
      case 'PING':
        _transport?.send(peerId, 'PONG|${parts[1]}|${parts[2]}');
        _addLog('PING #${parts[1]} from $peerId -> PONG');
      case 'PONG':
        final rtt = DateTime.now().millisecondsSinceEpoch - int.parse(parts[2]);
        setState(() {
          _pongs++;
          _rtts.add(rtt);
        });
        _addLog('PONG #${parts[1]} rtt=${rtt}ms');
      case 'BIG':
        setState(() => _bigReceived++);
        _addLog('BIG payload received: ${message.length} chars intact=${message.length == int.parse(parts[1])}');
      default:
        _addLog('msg from $peerId: ${message.length} chars');
    }
  }

  Future<void> _broadcast(String Function() build, {bool big = false}) async {
    for (final id in _peers.keys) {
      try {
        await _transport?.send(id, build());
        setState(() => big ? _bigSent++ : _pingsSent++);
      } catch (e) {
        _addLog('SEND ERROR to $id: $e');
      }
    }
  }

  Future<void> _ping() => _broadcast(() => 'PING|${++_seq}|${DateTime.now().millisecondsSinceEpoch}');

  Future<void> _sendBig(int size) => _broadcast(() {
        final header = 'BIG|$size|';
        return header + 'x' * (size - header.length);
      }, big: true);

  @override
  Widget build(BuildContext context) {
    final avg = _rtts.isEmpty ? '-' : '${(_rtts.reduce((a, b) => a + b) / _rtts.length).round()}ms';
    return Scaffold(
      appBar: AppBar(title: Text('Transport spike · $_me')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_transport == null) ...[
              FilledButton(onPressed: () => _start(NearbyConnectionsTransport()), child: const Text('START: nearby_connections')),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => _start(NearbyPlusTransport()), child: const Text('START: flutter_nearby_connections_plus')),
              const SizedBox(height: 8),
              const Text('Use the SAME package on both phones. Restart the app to switch package.'),
            ] else ...[
              Text('Package: ${_transport!.label}'),
              Text('Connected peers: ${_peers.length} ${_peers.values.join(', ')}'),
              Text('Pings sent $_pingsSent · pongs $_pongs · avg RTT $avg · BIG sent $_bigSent / received $_bigReceived'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(onPressed: _peers.isEmpty ? null : _ping, child: const Text('PING')),
                OutlinedButton(onPressed: _peers.isEmpty ? null : () => _sendBig(16 * 1024), child: const Text('SEND 16 KB')),
                OutlinedButton(onPressed: _peers.isEmpty ? null : () => _sendBig(30 * 1024), child: const Text('SEND 30 KB')),
              ]),
            ],
            const Divider(),
            Expanded(
              child: ListView(children: [for (final l in _log) Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))]),
            ),
          ],
        ),
      ),
    );
  }
}
