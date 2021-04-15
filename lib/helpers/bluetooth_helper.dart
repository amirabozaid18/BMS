import 'dart:async';
import 'dart:convert';

import 'package:bms/providers/cells.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue/flutter_blue.dart';

const String Current_data_service = "0000180f-0000-1000-8000-00805f9b34fb";
const String Alarming_service = "00001802-0000-1000-8000-00805f9b34fb";
const Device_name = "00002a00-0000-1000-8000-00805f9b34fb";
const Temperature = "00002a6e-0000-1000-8000-00805f9b34fb";
const Current = "00002ae0-0000-1000-8000-00805f9b34fb";
const Voltage = "00002ae1-0000-1000-8000-00805f9b34fb";
const SOC = "00002a19-0000-1000-8000-00805f9b34fb";

class BTHelper with ChangeNotifier {
  final Cells _cells;
  BTHelper(this._cells);
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> _devices = [];
  List<bool> _devicesStates = [];
  BluetoothDevice _connectedDevice;
  BluetoothDevice targetDevice;
  List<BluetoothService> _sevices = [];
  int temp, current, volt, sOC;
  Future<void> getDevices() async {
/*     _devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    notifyListeners(); */
    flutterBlue.stopScan();
    StreamSubscription subscription;
    flutterBlue
        .startScan(timeout: Duration(seconds: 5))
        .then((value) => subscription.cancel());
    subscription =
        flutterBlue.scanResults.listen((List<ScanResult> results) async {
      // do something with scan results
      for (ScanResult r in results) {
        if (!_devices.any((element) => element.id == r.device.id)) {
          _devices.add(r.device);
          _devicesStates.add(false);
          /*print('${r.device.name} found! rssi: ${r.rssi}');
          print(r.advertisementData);
          print(r.device.id);
          print(_devices.length);
            if (r.device.name == 'ESP32') {
            print('found');
            targetDevice = r.device;
            subscription.cancel();
            flutterBlue.stopScan();
            try {
              await targetDevice.connect();
              await discoverServices();
              // ignore: unrelated_type_equality_checks
              if (targetDevice.state == BluetoothDeviceState.connected) {
                isConnected = true;
                _connectedDevice = targetDevice;
              }
              notifyListeners();
            } catch (e) {
              print(e);
              print(isConnected);
              print(targetDevice.name);
            } 
          }*/
        }
      }
      notifyListeners();
    });
    flutterBlue.connectedDevices.asStream().listen((event) async {
      for (BluetoothDevice bd in event) {
        if (!_devices.contains(bd)) {
          _devices.add(bd);
          _devicesStates.add(true);
          _connectedDevice = bd;
          _sevices = await _connectedDevice.discoverServices();
        }
        print(bd.id);
      }
      notifyListeners();
    });
    print(_devices.length);
  }

  Future<bool> connect(int index) async {
    flutterBlue.stopScan();
    try {
      await _devices[index].connect();
      _connectedDevice = _devices[index];
      _connectedDevice.state.listen((event) {
        if (event == BluetoothDeviceState.disconnected) {
          _sevices = [];
          _connectedDevice = null;
          _devicesStates = [];
        }
      });
/*       _connectedDevice.isDiscoveringServices.listen((event) {
        _isDiscovering = event;
        notifyListeners();
      }); */
      await discoverServices();
      List<BluetoothDevice> _connectedDevices =
          await flutterBlue.connectedDevices;
      for (var i = 0; i < _connectedDevices.length; i++) {
        if (_devices[index] == _connectedDevices[i]) {
          _devicesStates[index] = true;
          notifyListeners();
          return true;
        }
      }
      notifyListeners();
    } catch (e) {
      print(e);
      throw e;
    }
    return false;
  }

  Future<void> discoverServices() async {
    if (_connectedDevice == null) return;
    print(_connectedDevice.name);
    _sevices = await _connectedDevice.discoverServices();
    notifyListeners();
    await getData();
  }

  getData() async {
    _sevices.forEach((service) {
      if (service.uuid.toString() == Current_data_service) {
        service.characteristics.forEach((charac) async {
          if (charac.uuid.toString() == Current) {
            Future.delayed(Duration(milliseconds: 200), () async {
              List<int> data = await charac.read();
              current = data[0];
              print(current);
              print('current');
            });
          }
          if (charac.uuid.toString() == Voltage) {
            Future.delayed(Duration(milliseconds: 400), () async {
              List<int> data = await charac.read();
              volt = data[0];
              print(volt);
              print('volt');
            });
          }
          if (charac.uuid.toString() == SOC) {
            Future.delayed(Duration(milliseconds: 600), () async {
              List<int> data = await charac.read();
              sOC = data[0];
              print(sOC);
              print('Soc');
            });
          }
          if (charac.uuid.toString() == Temperature) {
            Future.delayed(Duration(milliseconds: 800), () async {
              List<int> data = await charac.read();
              temp = data[0];
              print(temp);
              print('temp');
            });
          }
          if (charac.uuid.toString() == Device_name) {
            Future.delayed(Duration(milliseconds: 1000), () async {
              List<int> data = await charac.read();
              _cells.setCellValue(Cell(
                id: data[0],
                temp: temp,
                current: current,
                volt: volt,
                sOC: sOC,
              ));
              await charac.write([0x00]);
              print(data.toString());
              print('here');
            });
          }
        });
      }
    });
  }

  writeData(String data, BluetoothCharacteristic targetCharacteristic) {
    if (targetCharacteristic == null) return;
    List<int> bytes = utf8.encode(data);
    targetCharacteristic.write(bytes);
  }

  Future<String> readData(BluetoothCharacteristic targetCharacteristic) async {
    // ignore: unnecessary_null_comparison
    if (targetCharacteristic == null) return null;
    String data = String.fromCharCodes(await targetCharacteristic.read());
    return data;
  }

  List<BluetoothDevice> get devices {
    return [..._devices];
  }

  List<bool> get devicesStates {
    return [..._devicesStates];
  }

  List<BluetoothService> get sevices {
    return [..._sevices];
  }
}
