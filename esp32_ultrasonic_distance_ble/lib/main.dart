// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/widgets.dart';
import 'package:flutter_blue/gen/flutterblue.pbserver.dart' as prefix0;
import 'widgets.dart';
//import 'package:esp32_ultrasonic_distance_ble/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
//import 'package:flutter_sparkline/flutter_sparkline.dart';

void main() {
  runApp(FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state.toString().substring(15)}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subhead
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Colors.redAccent,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text('Find Devices'),
      ),
      body: ListView(
        children: <Widget>[
          StreamBuilder<List<BluetoothDevice>>(
            stream: Stream.periodic(Duration(seconds: 2))
                .asyncMap((_) => FlutterBlue.instance.connectedDevices),
            initialData: [],
            builder: (c, snapshot) => Column(
              /*
              if (snapshot.data.name == "OurCharacteristic")
              {
                return ListTile(title: Text(snapshot.data.name));
              }else{
                return ListTile();
              }
            */

              children: snapshot.data
                  .map((d) => ListTile(
                        title: Text(d.name),
                        subtitle: Text(d.id.toString()),
                        trailing: StreamBuilder<BluetoothDeviceState>(
                          stream: d.state,
                          initialData: BluetoothDeviceState.disconnected,
                          builder: (c, snapshot) {
                            if (snapshot.data ==
                                BluetoothDeviceState.connected) {
                              return RaisedButton(
                                child: Text('OPEN'),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            DeviceScreen(device: d))),
                              );
                            }
                            return Text(snapshot.data.toString());
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          StreamBuilder<List<ScanResult>>(
            stream: FlutterBlue.instance.scanResults,
            initialData: [],
            builder: (c, snapshot) => Column(
              children: snapshot.data
                  .map(
                    (r) => ScanResultTile(
                      result: r,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) {
                        r.device.connect();
                        return DeviceScreen(device: r.device);
                      })),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),

      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                backgroundColor: Colors.teal[700],
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);
  final BluetoothDevice device;
  static String CHARACTERISTIC_UUID_BTN =
      "0000b00b-1212-efde-1523-785fef13d123";
  static String CHARACTERISTIC_UUID_TEMP =
      "0000beef-1212-efde-1523-785fef13d123";

  Widget _myService(List<BluetoothService> services) {
    Stream<List<int>> btn_stream;
    Stream<List<int>> temp_stream;
    services.forEach((service) {
      service.characteristics.forEach((character) {
        if (character.uuid.toString() == CHARACTERISTIC_UUID_BTN) {
          Future.delayed(new Duration(seconds: 2), () {
            character.setNotifyValue(true);
          });
          btn_stream = character.value;
        }
        if (character.uuid.toString() == CHARACTERISTIC_UUID_TEMP) {
          character.setNotifyValue(true);
          temp_stream = character.value;
        }
      });
    });
    return Container(
      
      child: StreamBuilder<List<int>>(
      stream: btn_stream,
      builder: (BuildContext context, AsyncSnapshot<List<int>> btn_snapshot) {
        return StreamBuilder(
          stream: temp_stream,
          builder:
              (BuildContext context, AsyncSnapshot<List<int>> temp_snapshot) {
            if (btn_snapshot.hasError)
              return Text('Error : ${btn_snapshot.error}');
            if (temp_snapshot.hasError)
              return Text('Error : ${temp_snapshot.error}');

            if ((btn_snapshot.data != null) && (temp_snapshot.data != null)) {
              if ((btn_snapshot.data.length != 0) &&
                  (temp_snapshot.data.length != 0)) {
                int incoming_counts = btn_snapshot.data[0];
                int incoming_temp = temp_snapshot.data[0];
                return Text(incoming_counts.toString() +
                    " " +
                    incoming_temp.toString());
              } else {
                return Text("Synced! Waiting for input");
                //return Text(btn_snapshot.data.toString() +
                //  " " +
                //  temp_snapshot.data.toString());
              }
            } else {
              return Text("Waiting to sync...");
              //return Text(btn_snapshot.data.toString() +
              //    " " +
              //    temp_snapshot.data.toString());
            }
          },
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('Insight Bluetooth Demo'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),

            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return _myService(snapshot.data);
              },
            ),

            //test
          ],
        ),
      ),
    );
  }
}
