import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text('Bluetooth Printer')),
      body: Center(child: PrintButton()),
    ),
  ));
}

class PrintButton extends StatefulWidget {
  @override
  _PrintButtonState createState() => _PrintButtonState();
}

class _PrintButtonState extends State<PrintButton> {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? printer;
  List<BluetoothDevice> devices = [];
  bool isDialogShown = true;

  void printReceipt() async {
    String receipt = '''
----------------------------------------
              FOOD RECEIPT              
----------------------------------------
Item                 Quantity    Price  
----------------------------------------
Burger                    2      5.99 ETB
Fries                     1      2.99 ETB
Coke                      2      1.99 ETB
----------------------------------------
Total                           17.95 ETB 
----------------------------------------
Thank you for your purchase!
''';

    try {
      List<BluetoothService> services = await printer!.discoverServices();
      services.forEach((service) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.properties.write) {
            characteristic.write(utf8.encode(receipt));
          }
        });
      });
    } catch (e) {
      print('Error printing receipt: $e');
    }
  }

  void checkBluetoothAndPrint(BuildContext context) async {
    bool isOn = await flutterBlue.isOn;
    if (!isOn) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Bluetooth is off'),
            content:
                Text('Please turn on Bluetooth before printing the receipt.'),
            actions: <Widget>[
              ElevatedButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    startScan();
  }

  @override
  void initState() {
    super.initState();
  }

  BuildContext? dialogContext;

  void startScan() async {
    int dialogCounter = 0;
    flutterBlue.startScan();

    // Listen to scan results
    var subscription = flutterBlue.scanResults.listen((results) async {
      // if (!devices.isEmpty) {
      //   for (var i = 0; i < results.length; i++) {
      //     int index = devices.indexWhere((element) => element == results[i].device.id);

      //     print(index);
      //   }
      // }
      // Collect discovered devices into a list
      for (ScanResult result in results) {
        if (!devices.any((device) => device.id == result.device.id) &&
            result.device.name != '') {
          // Check if a device with the same id is already in the list
          devices.add(result.device);
          if (isDialogShown) {
            dialogCounter++;
            // print(dialogCounter);
            showDeviceListDialog(devices,
                dialogCounter); // Show the updated device list dialog // Show the updated device list dialog
          }
        }
      }
    });
  }

  void showDeviceListDialog(List<BluetoothDevice> devices, int counter) {
    if (counter > 0 && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Close the current dialog if counter > 0
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select a device'),
          content: SingleChildScrollView(
            child: Column(
              children: devices.map((device) {
                return ListTile(
                  title:
                      Text(device.name.isEmpty ? 'Unknown name' : device.name),
                  onTap: () async {
                    // print('device connected');
                    printer = device;
                    try {
                      print(printer);
                      await printer!.connect();
                      Navigator.of(context).pop();
                    } catch (e) {
                      print('Error connecting to device: $e');
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                flutterBlue.stopScan();
                for (var i = 0; i < devices.length; i++) {
                  devices.removeAt(i);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => checkBluetoothAndPrint(context),
      child: Text('Print'),
    );
  }
}
