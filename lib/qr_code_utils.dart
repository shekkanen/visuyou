// lib/qr_code_utils.dart
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart'; // Import for HMAC
import 'dart:io'; // Import for Platform
import 'package:flutter_dotenv/flutter_dotenv.dart';
class QRCodeUtils {

  static String _getSecretKey() {
    // Instead of Platform.environment, use dotenv.env
    final secretKey = dotenv.env['VISUYOU_SECRET_KEY'];
    if (secretKey == null || secretKey.isEmpty) {
      throw Exception('VISUYOU_SECRET_KEY environment variable is not set. '
          'Please set this before using this application...');
    }
    return secretKey;
  }

    /// Generates HMAC signature for the given data using the secret key.
  static String _generateHMAC(String data) {
      final key = utf8.encode(_getSecretKey());
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key); // HMAC-SHA256
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies HMAC signature for the given data.
  static bool _verifyHMAC(String data, String signature) {
    final expectedSignature = _generateHMAC(data);
    return expectedSignature == signature;
  }

  /// Displays a QR code containing type, sdp, iceCandidates, and HMAC signature.
  static Future<void> displayQRCode(
    BuildContext context,
    String type,
    String sdp,
    List<Map<String, dynamic>> iceCandidates,
    Function(String) setStateCallback,
  ) async {
    try {
      // Construct the JSON object
      final Map<String, dynamic> qrData = {
        'type': type,
        'sdp': sdp,
        'iceCandidates': iceCandidates,
      };

      String jsonString = jsonEncode(qrData);
      String compressedData = _compressData(jsonString);

      // Generate HMAC signature
      String signature = _generateHMAC(compressedData);

      // Attach signature to the data
      final Map<String, dynamic> qrDataWithSignature = {
        'data': compressedData,
        'signature': signature,
      };

      String finalQrData = jsonEncode(qrDataWithSignature);

      if (kDebugMode) {
        print(
            "Size of data before compression: ${utf8.encode(jsonString).length} bytes");
        print(
            "Size of data after compression: ${utf8.encode(compressedData).length} bytes");
      }

      // Generate QR Code
      String qrCodeData = finalQrData;

      setStateCallback(qrCodeData);

      if (kDebugMode) {
        print("Generated QR Code Data: $qrCodeData");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error generating QR code: $e");
      }
      _showErrorAlert(context, "Failed to generate QR code. Please try again.");
    }
  }

  /// Scans a QR code and extracts type, sdp, and iceCandidates after verification.
  static Future<void> scanQRCode(
      BuildContext context,
      Function(String, String, List<Map<String, dynamic>>)
          processScannedData) async {
    try {
      String scannedData = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.QR);

      if (scannedData != '-1') {
        _processScannedData(context, scannedData, processScannedData);
      } else {
        if (kDebugMode) {
          print("QR scan was cancelled or failed");
        }
        _showInfoSnackBar(context, "QR scan was cancelled.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error scanning QR code: $e");
      }
      _showErrorAlert(context, "Failed to scan QR code. Please try again.");
    }
  }

  /// Processes the scanned QR code data with HMAC verification.
  static void _processScannedData(BuildContext context, String scannedData,
      Function(String, String, List<Map<String, dynamic>>) processScannedData) {
    try {
      final Map<String, dynamic> receivedData = jsonDecode(scannedData);

      String compressedData = receivedData['data'];
      String signature = receivedData['signature'];

      // Verify HMAC signature
      bool isValid = _verifyHMAC(compressedData, signature);
      if (!isValid) {
        if (kDebugMode) {
          print("HMAC signature verification failed.");
        }
        _showErrorAlert(
            context, "Invalid QR code. The data may have been tampered with.");
        return;
      }

      // Decompress data
      String decompressedData = _decompressData(compressedData);
      final Map<String, dynamic> connectionData = jsonDecode(decompressedData);

      final String type = connectionData['type'];
      final String sdp = connectionData['sdp'];
      final List<dynamic> iceCandidatesDynamic =
          connectionData['iceCandidates'] ?? [];

      // Convert dynamic list to List<Map<String, dynamic>>
      List<Map<String, dynamic>> iceCandidates = iceCandidatesDynamic
          .map((candidate) => Map<String, dynamic>.from(candidate))
          .toList();

      if (kDebugMode) {
        print("Decoded Data: $connectionData");
        print("Type: $type, SDP: $sdp, ICE Candidates: $iceCandidates");
      }

      processScannedData(type, sdp, iceCandidates);
    } catch (e) {
      if (kDebugMode) {
        print("Failed to decode or verify QR code data: $e");
      }
        _showErrorAlert(context, "Failed to process scanned QR code data. Please try again.");
    } on FormatException catch (e) {
        if (kDebugMode) {
          print('Failed to decode JSON: $e');
        }
        _showErrorAlert(context, "Failed to decode scanned QR code data. Please try again.");
    }
  }

  /// Compresses data using GZip and encodes it in Base64.
  static String _compressData(String data) {
    try {
      List<int> stringBytes = utf8.encode(data);
      List<int> compressedBytes =
          GZipEncoder().encode(stringBytes) as List<int>;
      return base64Encode(compressedBytes);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to compress data: $e');
      }
      throw Exception('Failed to compress data');
    }
  }

  /// Decompresses Base64 encoded GZip data.
  static String _decompressData(String compressedData) {
    try {
      List<int> compressedBytes = base64Decode(compressedData);
      List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      return utf8.decode(decompressedBytes);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to decompress data: $e');
      }
      throw Exception('Failed to decompress data');
    }
  }

  /// Displays an error alert dialog.
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

  /// Displays an informational snackbar.
  static void _showInfoSnackBar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Builds the QR code widget to display on the screen.
  static Widget buildQRCodeWidget(String connectionCode) {
    return Padding(
      padding: const EdgeInsets.all(16.0), // Consistent padding
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Added vertical centering
          children: [
            const Text(
              'Using VR headsets may cause motion sickness, disorientation, or other discomfort. Be aware of your surroundings and use caution.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent, // Make the warning stand out
              ),
            ),
            const SizedBox(height: 10),
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
        ),
      ),
    );
  }
}