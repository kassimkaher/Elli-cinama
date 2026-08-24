import 'dart:math';

import '../storage/key_value_store.dart';

/// Backend-required device envelope. Values are representative and were
/// runtime-accepted; this does NOT read a privileged hardware MAC (modern
/// Android forbids it) and contains no restriction-bypass logic.
class DeviceEnvelope {
  final String mac;
  final String sn; // same value as mac (contract)
  final String model;
  final int group;

  const DeviceEnvelope({
    required this.mac,
    required this.sn,
    required this.model,
    this.group = 0,
  });

  Map<String, dynamic> toPayload() => {
        'mac': mac,
        'sn': sn,
        'model': model,
        'group': group,
      };
}

abstract class DeviceEnvelopeProvider {
  Future<DeviceEnvelope> get();
}

/// Fixed envelope (tests / deterministic default).
class StaticDeviceEnvelopeProvider implements DeviceEnvelopeProvider {
  final DeviceEnvelope envelope;
  const StaticDeviceEnvelopeProvider(this.envelope);
  @override
  Future<DeviceEnvelope> get() async => envelope;
}

/// Generates a stable pseudo-MAC once and persists it (isolated so it can be
/// changed later without touching repositories). `model` is resolved at
/// bootstrap (e.g. via device_info_plus) and injected here.
class PersistentDeviceEnvelopeProvider implements DeviceEnvelopeProvider {
  final KeyValueStore store;
  final String modelName;
  static const _key = 'device_stable_id';

  PersistentDeviceEnvelopeProvider({required this.store, required this.modelName});

  @override
  Future<DeviceEnvelope> get() async {
    var id = await store.getString(_key);
    if (id == null || id.isEmpty) {
      id = _generateStableId();
      await store.setString(_key, id);
    }
    final model = modelName.isEmpty ? 'generic' : modelName;
    return DeviceEnvelope(mac: id, sn: id, model: model, group: 0);
  }

  String _generateStableId() {
    final r = Random.secure();
    final parts = List<String>.generate(
      6,
      (i) => (i == 0 ? 0x02 : r.nextInt(256)).toRadixString(16).padLeft(2, '0'),
    );
    return parts.join(':'); // locally-administered style, e.g. 02:ab:cd:...
  }
}
