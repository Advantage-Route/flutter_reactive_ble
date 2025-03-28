import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:meta/meta.dart';
import 'package:reactive_ble_platform_interface/reactive_ble_platform_interface.dart';

abstract class ConnectedDeviceOperation {
  Stream<CharacteristicValue> get characteristicValueStream;

  Future<List<int>> readCharacteristic(CharacteristicInstance characteristic);

  Future<void> writeCharacteristicWithResponse(
    CharacteristicInstance characteristic, {
    required List<int> value,
  });

  Future<void> writeCharacteristicWithoutResponse(
    CharacteristicInstance characteristic, {
    required List<int> value,
  });

  Future<void> writeCharacteristicLong(
    CharacteristicInstance characteristic, {
    required List<int> value,
  });

  Stream<List<int>> subscribeToCharacteristic(
    CharacteristicInstance characteristic,
    Future<void> isDisconnected,
  );

  Future<int> requestMtu(String deviceId, int mtu);

  Future<List<DiscoveredService>> discoverServices(String deviceId);

  Future<List<DiscoveredService>> getDiscoverServices(String deviceId);

  Future<void> requestConnectionPriority(
      String deviceId, ConnectionPriority priority);
}

class ConnectedDeviceOperationImpl implements ConnectedDeviceOperation {
  ConnectedDeviceOperationImpl({required ReactiveBlePlatform blePlatform})
      : _blePlatform = blePlatform;

  final ReactiveBlePlatform _blePlatform;

  @override
  Stream<CharacteristicValue> get characteristicValueStream =>
      _blePlatform.charValueUpdateStream;

  @override
  Future<List<int>> readCharacteristic(
    CharacteristicInstance characteristic,
  ) async {
    final specificCharacteristicValueStream = characteristicValueStream
        .where((update) => update.characteristic == characteristic)
        .map((update) => update.result);

    final result = await _blePlatform
        .readCharacteristic(characteristic)
        .asyncExpand((_) => specificCharacteristicValueStream)
        .firstWhere((_) => true,
            orElse: () => throw NoBleCharacteristicDataReceived());
    return result.dematerialize();
  }

  @override
  Future<void> writeCharacteristicWithResponse(
    CharacteristicInstance characteristic, {
    required List<int> value,
  }) async =>
      _blePlatform
          .writeCharacteristicWithResponse(characteristic, value)
          .then((info) => info.result.dematerialize());

  @override
  Future<void> writeCharacteristicWithoutResponse(
    CharacteristicInstance characteristic, {
    required List<int> value,
  }) async =>
      _blePlatform
          .writeCharacteristicWithoutResponse(characteristic, value)
          .then((info) => info.result.dematerialize());

  @override
  Future<void> writeCharacteristicLong(
    CharacteristicInstance characteristic, {
    required List<int> value,
  }) async =>
      _blePlatform
          .writeCharacteristicLong(characteristic, value)
          .then((info) => info.result.dematerialize());

  @override
  Stream<List<int>> subscribeToCharacteristic(
    CharacteristicInstance characteristic,
    Future<void> isDisconnected,
  ) {
    final specificCharacteristicValueStream = characteristicValueStream
        .where((update) => update.characteristic == characteristic)
        .map((update) => update.result.dematerialize());

    final autosubscribingRepeater = Repeater<List<int>>.broadcast(
      onListenEmitFrom: () => _blePlatform
          .subscribeToNotifications(characteristic)
          .asyncExpand((_) => specificCharacteristicValueStream),
      onCancel: () => _blePlatform
          .stopSubscribingToNotifications(characteristic)
          .catchError((Object e) =>
              // ignore: avoid_print
              print("Error unsubscribing from notifications: $e")),
    );

    isDisconnected.then<void>((_) => autosubscribingRepeater.dispose());

    return autosubscribingRepeater.stream;
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) async =>
      _blePlatform.requestMtuSize(deviceId, mtu);

  @override
  Future<List<DiscoveredService>> discoverServices(String deviceId) =>
      _blePlatform.discoverServices(deviceId);

  @override
  Future<List<DiscoveredService>> getDiscoverServices(String deviceId) =>
      _blePlatform.getDiscoverServices(deviceId);

  @override
  Future<void> requestConnectionPriority(
          String deviceId, ConnectionPriority priority) async =>
      _blePlatform
          .requestConnectionPriority(deviceId, priority)
          .then((message) => message.result.dematerialize());
}

@visibleForTesting
class NoBleCharacteristicDataReceived implements Exception {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

@visibleForTesting
class NoBleDeviceConnectionStateReceived implements Exception {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
