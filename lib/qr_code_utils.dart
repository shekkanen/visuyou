import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class QRCodeUtils {
  static Future<void> displayQRCode(BuildContext context, String data, String type, Function(String) setStateCallback) async {
    try {
      String compressedData = _compressData(data);
      String qrCodeData = jsonEncode({'type': type, 'data': compressedData});
      setStateCallback(qrCodeData);
      print("Generated QR Code Data: $qrCodeData");
    } catch (e) {
      print("Error generating QR code: $e");
      _showErrorAlert(context, "Failed to generate QR code. Please try again.");
    }
  }

  static Future<void> scanQRCode(BuildContext context, Function(String, String) processScannedData) async {
    try {
      String scannedData = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.QR);

      if (scannedData != '-1') {
        _processScannedData(context, scannedData, processScannedData);
      } else {
        print("QR scan was cancelled or failed");
        _showInfoSnackBar(context, "QR scan was cancelled.");
      }
    } catch (e) {
      print("Error scanning QR code: $e");
      _showErrorAlert(context, "Failed to scan QR code. Please try again.");
    }
  }

  static void _processScannedData(BuildContext context, String scannedData, Function(String, String) processScannedData) {
    try {
      final Map<String, dynamic> receivedData = jsonDecode(scannedData);
      print("Decoded Data: $receivedData");
      final String type = receivedData['type'];
      final String compressedData = receivedData['data'];
      final String data = _decompressData(compressedData);
      print("Type: $type, Data: $data");

      processScannedData(type, data);
    } catch (e) {
      print("Failed to decode QR code data: $e");
      _showErrorAlert(context, "Failed to process scanned QR code data. Please try again.");
    }
  }

  static String _compressData(String data) {
    try {
      List<int> stringBytes = utf8.encode(data);
      List<int> compressedBytes = GZipEncoder().encode(stringBytes) as List<int>;
      return base64Encode(compressedBytes);
    } catch (e) {
      print('Failed to compress data: $e');
      throw Exception('Failed to compress data');
    }
  }

  static String _decompressData(String compressedData) {
    try {
      List<int> compressedBytes = base64Decode(compressedData);
      List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      return utf8.decode(decompressedBytes);
    } catch (e) {
      print('Failed to decompress data: $e');
      throw Exception('Failed to decompress data');
    }
  }

  static void _showErrorAlert(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showInfoSnackBar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Widget buildQRCodeWidget(String connectionCode) {
    return Column(
      children: [
        const Text(
          'Scan the QR code on the other device to connect',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16.0),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 200.0,
          height: 200.0,
          child: QrImageView(
            data: connectionCode,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
      ],
    );
  }
}
