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

  void printReceipt() async {
    String receipt = '''
----------------------------------------
              FOOD RECEIPT              
----------------------------------------
Item                 Quantity    Price  
----------------------------------------
Burger                    2      \$5.99 
Fries                     1      \$2.99 
Coke                      2      \$1.99 
----------------------------------------
Total                           \$17.95 
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

    List<BluetoothDevice> connectedDevices = await flutterBlue.connectedDevices;
    if (connectedDevices.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('No Bluetooth devices connected'),
            content: Text(
                'Please connect a Bluetooth device before printing the receipt.'),
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

    if (printer == null) {
      print('No printer selected');
      return;
    }

    printReceipt();
  }

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() async {
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    // Listen to scan results
    var subscription = flutterBlue.scanResults.listen((results) async {
      // Stop scanning
      flutterBlue.stopScan();

      // Show dialog to select device
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Select a device'),
            content: Column(
              children: results
                  .map((result) => ListTile(
                        title: Text(result.device.name),
                        onTap: () async {
                          printer = result.device;
                          try {
                            await printer!.connect();
                            Navigator.of(context).pop();
                          } catch (e) {
                            print('Error connecting to device: $e');
                          }
                        },
                      ))
                  .toList(),
            ),
          );
        },
      );
    });

    // Stop listening after a certain time
    Future.delayed(Duration(seconds: 5), () async {
      await subscription.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => checkBluetoothAndPrint(context),
      child: Text('Print'),
    );
  }
}
