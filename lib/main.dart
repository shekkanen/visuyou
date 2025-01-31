// lib/main.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'qr_code_utils.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'voice_command_utils.dart';
import 'about_page.dart'; // Import the About page
import 'settings_page.dart'; // Import the Settings page
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'policies.dart'; // Import the privacy policy and terms of service text
import 'package:provider/provider.dart'; // Import provider
import 'settings_model.dart'; // Import settings model
import 'dart:async'; // Import for async functions
import 'package:vibration/vibration.dart';
import 'animated_styled_button.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure plugin services are initialized

  // Load environment variables from /assets/.env
  await dotenv.load(fileName: "assets/.env");

  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsModel(),
      child: MaterialApp(
        title: 'VisuYou',
        theme: ThemeData(primaryColor: Colors.black),
        home: const CameraStreamingApp(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

class CameraStreamingApp extends StatefulWidget {
  const CameraStreamingApp({super.key});

  @override
  _CameraStreamingAppState createState() => _CameraStreamingAppState();
}

class _CameraStreamingAppState extends State<CameraStreamingApp> {
  late SharedPreferences prefs;
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  RTCPeerConnection? _peerConnection;
  bool _renderersInitialized = false;
  bool _isOfferer = false; // Track if the device is the offerer
  bool _connecting = false; // Track connection status
  bool _isConnected = false; // Track connection status

  String _connectionCode = '';
  final List<RTCIceCandidate> _gatheredIceCandidates = [];

  MediaStream? _remoteStream;

  // Dropdown menu related
  String _selectedViewMode = 'Full VR Mode'; // Default selected mode
  final List<String> _viewModes = [
    'Full VR Mode',
    'Full VR Mode2',
    '50/50 VR Mode',
    'PIP VR Mode',
    'PIP VR Mode2'
  ];
  VoiceCommandUtils? _voiceCommandUtils; // Modified to be nullable
  late SettingsModel _settingsModel; // Add this line

  // Added member variables for audio control
  MediaStream? _localStream;
  MediaStreamTrack? _audioTrack;
  RTCRtpSender? _audioSender;

  final ValueNotifier<String?> _vrMessageNotifier =
      ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _initializePreferences(); // Initialize preferences
    _checkFirstLaunch(); // Check if the user has accepted the terms

    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    // Initialize _settingsModel and add listener
    _settingsModel = Provider.of<SettingsModel>(context, listen: false);
    _settingsModel.addListener(_onSettingsChanged);

    // Wait for settings to load before proceeding
    _settingsModel.settingsLoaded.then((_) async {
      await _requestPermissions(); // Proceed with the rest after settings are loaded

      // Manually trigger the settings changed handler
      _onSettingsChanged();
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]); // Force portrait mode initially
  }

  Future<void> _initializePreferences() async {
    prefs = await SharedPreferences.getInstance();
    // No need to retrieve settings here; we'll get them in _requestPermissions()
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {
      _showPermissionAlert();
      return;
    }

    // Proceed with initialization after permissions are granted
    await _initializeRenderers();
    await _createPeerConnection();
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      setState(() {
        _renderersInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize renderers: $e');
      }
      _showErrorAlert(
          'Failed to initialize video renderers. Please restart the app.');
    }
  }

  Future<void> _createPeerConnection() async {
    if (prefs == null) {
      if (kDebugMode) {
        print("SharedPreferences is not initialized");
      }
      return;
    }

    try {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (kDebugMode) {
          print('ICE Connection State: $state');
        }
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          setState(() {
            _connecting = false;
            _isConnected = true;
          });
          _showInfoSnackBar('Connected successfully!');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          if (_isConnected) {
            setState(() {
              _isConnected = false;
            });
            _showErrorSnackBar('Connection lost. Please try again.');
            _resetApp();
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          Navigator.of(context).popUntil((route) => route.isFirst);            
          }
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (kDebugMode) {
          print('Peer Connection State: $state');
        }
      };

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        if (kDebugMode) {
          print('Signaling State: $state');
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (kDebugMode) {
          print('Received track: ${event.track.kind}');
        }
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _remoteStream = event.streams[0]; // Store the remote stream
            _toggleSpeaker(
                _settingsModel.speakerEnabled); // Apply speaker setting
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          if (kDebugMode) {
            print('ICE Candidate: ${candidate.candidate}');
          }
          _gatheredIceCandidates.add(candidate);
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        if (kDebugMode) {
          print('ICE Gathering State: $state');
        }
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          _sendQRCode();
        }
      };

      // Enumerate cameras and get the device ID of the back camera
      final mediaDevices = await navigator.mediaDevices.enumerateDevices();
      String? backCameraId;

      for (var device in mediaDevices) {
        if (device.kind == 'videoinput' &&
            device.label.toLowerCase().contains('back')) {
          backCameraId = device.deviceId;
          break;
        }
      }

      // Always request audio and video
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true, // Always request audio
        'video': backCameraId != null
            ? {
                'deviceId': backCameraId,
                'minWidth': 1280,
                'minHeight': 720,
                'minFrameRate': 30,
              }
            : true,
      });

      _localRenderer.srcObject = stream;
      _localStream = stream;

      // Add video track
      var videoTrack = stream.getVideoTracks()[0];
      await _peerConnection!.addTrack(videoTrack, stream);

      // Store the audio track for later use
      _audioTrack = stream.getAudioTracks()[0];
      _audioTrack!.enabled = _settingsModel.micEnabled;

      // Always add the audio track
      _audioSender = await _peerConnection!.addTrack(_audioTrack!, stream);

      if (backCameraId == null) {
        if (kDebugMode) {
          print('Back camera not found');
        }
        _showErrorSnackBar('Back camera not found. Using default camera.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create PeerConnection: $e');
      }
      _showErrorAlert('Failed to create a connection. Please try again.');
    }
  }

  /// Sends the QR code containing SDP and ICE candidates.
  Future<void> _sendQRCode() async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      RTCSessionDescription? localDescription =
          await _peerConnection!.getLocalDescription();
      if (localDescription == null) {
        if (kDebugMode) {
          print("Local description is not set");
        }
        return;
      }

      // Prepare ICE candidates as a list of maps
      List<Map<String, dynamic>> iceCandidates = [];
      for (var i = 0; i < _gatheredIceCandidates.length && i < 15; i++) {
        var candidate = _gatheredIceCandidates[i];
        iceCandidates.add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }

      // Determine type based on whether this device is the offerer
      String type = _isOfferer ? 'offer' : 'answer';

      await QRCodeUtils.displayQRCode(
        context,
        type,
        localDescription.sdp ?? '',
        iceCandidates,
        (String qrCodeData) {
          setState(() {
            _connectionCode = qrCodeData;
            // Only set _connecting to false if we are the offerer
            if (_isOfferer) {
              _connecting = false;
            }
            // Do not set _connecting to false if we are the answerer
          });
        },
      );

      if (kDebugMode) {
        print("QR Code sent with type: $type");
      }

      // Clear the gathered ICE candidates after sending
      _gatheredIceCandidates.clear();
    } catch (e) {
      if (kDebugMode) {
        print("Failed to send QR Code: $e");
      }
      _showErrorAlert('Failed to send QR code. Please try again.');
    }
  }

  /// Creates an SDP offer.
  Future<void> _createOffer() async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      setState(() {
        _connecting = true;
        _isOfferer = true; // Mark this device as the offerer
      });

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      Future.delayed(const Duration(seconds: 5), _sendQRCode);
      // _sendQRCode();
      if (kDebugMode) {
        print("Local SDP Offer: ${offer.sdp}");
      }

      // The QR code will be sent automatically once ICE gathering is complete
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      if (kDebugMode) {
        print('Failed to create offer: $e');
      }
      _showErrorAlert('Failed to create an offer. Please try again.');
    }
  }

  /// Creates an SDP answer.
  Future<void> _createAnswer() async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      setState(() {
        _connecting = true;
        _isOfferer = false; // This device is the answerer
      });

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      Future.delayed(const Duration(seconds: 5), _sendQRCode);
      // _sendQRCode();

      if (kDebugMode) {
        print("Local SDP Answer: ${answer.sdp}");
      }

      // The QR code will be sent automatically once ICE gathering is complete
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      if (kDebugMode) {
        print('Failed to create answer: $e');
      }
      _showErrorAlert('Failed to create an answer. Please try again.');
    }
  }

  /// Handles receiving an SDP offer.
  Future<void> _onOfferReceived(
      String sdp, List<Map<String, dynamic>> iceCandidates) async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final description = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(description);
      if (kDebugMode) {
        print("Remote SDP set as Offer");
      }

      // Add ICE candidates received from the offer
      for (var candidate in iceCandidates) {
        RTCIceCandidate iceCandidate = RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(iceCandidate);
      }

      await _createAnswer();
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      if (kDebugMode) {
        print('Failed to handle received offer: $e');
      }
      _showErrorAlert('Failed to process the offer. Please try again.');
    }
  }

  /// Handles receiving an SDP answer.
  Future<void> _onAnswerReceived(
      String sdp, List<Map<String, dynamic>> iceCandidates) async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      final description = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(description);
      if (kDebugMode) {
        print("Remote SDP set as Answer");
      }

      // Add ICE candidates received from the answer
      for (var candidate in iceCandidates) {
        RTCIceCandidate iceCandidate = RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(iceCandidate);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to handle received answer: $e');
      }
      _showErrorAlert('Failed to process the answer. Please try again.');
    }
  }

  /// Scans a QR code and processes the data.
  Future<void> _scanQRCode() async {
    await QRCodeUtils.scanQRCode(context, _processScannedData);
  }

  /// Processes the scanned QR code data.
  void _processScannedData(
      String type, String sdp, List<Map<String, dynamic>> iceCandidates) async {
    if (type == 'offer') {
      await _onOfferReceived(sdp, iceCandidates);
    } else if (type == 'answer') {
      await _onAnswerReceived(sdp, iceCandidates);
    } else {
      if (kDebugMode) {
        print("Unknown type: $type");
      }
      _showErrorAlert('Unknown QR code type. Please try again.');
    }
  }

  Future<void> handleVoiceCommand(String command) async {
    command = command.toLowerCase();

    // Check if the device has a vibrator
    bool? hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator != null && hasVibrator) {
      // Define a vibration pattern [delay, vibrate, pause, vibrate, ...]
      List<int> pattern = [0, 200, 100, 200]; // Adjust as needed
      Vibration.vibrate(pattern: pattern);
    }

    if (command == 'view_next') {
      // Handle 'next' command
      int currentIndex = _viewModes.indexOf(_selectedViewMode);
      int nextIndex = (currentIndex + 1) % _viewModes.length;
      String nextMode = _viewModes[nextIndex];
      setState(() {
        _selectedViewMode = nextMode;
      });
      switchViewMode(nextMode);
    } else if (command == 'view_back') {
      // Handle 'back' command
      int currentIndex = _viewModes.indexOf(_selectedViewMode);
      int prevIndex =
          (currentIndex - 1 + _viewModes.length) % _viewModes.length;
      String prevMode = _viewModes[prevIndex];
      setState(() {
        _selectedViewMode = prevMode;
      });
      switchViewMode(prevMode);
    } else if (command == 'mute_mic') {
      _settingsModel.updatemicEnabled(false);
      _toggleMic(false);
      _showInfoSnackBar('Mic has been muted.');
    } else if (command == 'unmute_mic') {
      _settingsModel.updatemicEnabled(true);
      _toggleMic(true);
      _showInfoSnackBar('Mic has been unmuted.');
    } else if (command == 'mute_speaker') {
      _settingsModel.updateSpeakerEnabled(false);
      _toggleSpeaker(false);
      _showInfoSnackBar('Speaker has been muted.');
    } else if (command == 'unmute_speaker') {
      _settingsModel.updateSpeakerEnabled(true);
      _toggleSpeaker(true);
      _showInfoSnackBar('Speaker has been unmuted.');
    } else if (command == 'full_vr_mode') {
      setState(() {
        _selectedViewMode = 'Full VR Mode';
      });
      switchViewMode('Full VR Mode');
    } else if (command == 'full_vr_mode2') {
      setState(() {
        _selectedViewMode = 'Full VR Mode2';
      });
      switchViewMode('Full VR Mode2');
    } else if (command == 'vr50_50_mode') {
      setState(() {
        _selectedViewMode = '50/50 VR Mode';
      });
      switchViewMode('50/50 VR Mode');
    } else if (command == 'pip_vr_mode') {
      setState(() {
        _selectedViewMode = 'PIP VR Mode';
      });
      switchViewMode('PIP VR Mode');
    } else if (command == 'pip_vr_mode2') {
      setState(() {
        _selectedViewMode = 'PIP VR Mode2';
      });
      switchViewMode('PIP VR Mode2');
    } else {
      if (kDebugMode) {
        print('Unknown command received: $command');
      }
    }
  }

  /// Switches the view mode based on the selected mode.
  void switchViewMode(String mode) {
    if (mode.contains('VR Mode')) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    switch (mode) {
      case 'Full VR Mode':
        _enterFullVRMode();
        break;
      case 'Full VR Mode2':
        _enterFullVRMode2();
        break;
      case '50/50 VR Mode':
        _enter50_50VRMode();
        break;
      case 'PIP VR Mode':
        _enterPiPMode();
        break;
      case 'PIP VR Mode2':
        _enterPiPMode2();
        break;
    }
  }

  /// Enters Full VR Mode.
  void _enterFullVRMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullVRVideoView(
          renderer: _remoteRenderer,
          messageNotifier: _vrMessageNotifier,
        ),
      ),
    ).then((_) {
      // This will reset the orientation when the VR view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  void _enterFullVRMode2() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullVRVideoView(
          renderer: _localRenderer,
          messageNotifier: _vrMessageNotifier,
        ),
      ),
    ).then((_) {
      // This will reset the orientation when the VR view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Enters 50/50 VR Mode.
  void _enter50_50VRMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VR50_50VideoView(
          localRenderer: _localRenderer,
          remoteRenderer: _remoteRenderer,
          messageNotifier: _vrMessageNotifier,
        ),
      ),
    ).then((_) {
      // Reset orientation when the VR view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Enters Picture-in-Picture VR Mode.
  void _enterPiPMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PiPVideoView(
          mainRenderer: _remoteRenderer, // Assuming remoteRenderer as main view
          pipRenderer: _localRenderer, // Assuming localRenderer as PiP view
          messageNotifier: _vrMessageNotifier,
        ),
      ),
    ).then((_) {
      // Reset orientation when the PiP view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Enters the second Picture-in-Picture VR Mode.
  void _enterPiPMode2() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PiPVideoView(
          mainRenderer: _localRenderer, // Assuming localRenderer as main view
          pipRenderer: _remoteRenderer, // Assuming remoteRenderer as PiP view
          messageNotifier: _vrMessageNotifier,
        ),
      ),
    ).then((_) {
      // Reset orientation when the PiP view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Shows an alert dialog if permissions are not granted.
  void _showPermissionAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions required'),
        content: const Text(
            'Camera and microphone permissions are required to proceed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows an error alert dialog.
  void _showErrorAlert(String message) {
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

  /// Shows an error snackbar.
  void _showErrorSnackBar(String message) {
    _displayVRMessage(message);
  }

  /// Shows an informational snackbar.
  void _showInfoSnackBar(String message) {
    _displayVRMessage(message);
  }

  // Helper method to check if in VR mode
  bool _isInVRMode() {
    // Implement logic to determine if the app is currently in VR mode
    return _selectedViewMode.contains('VR Mode');
  }

  // Display message in VR or non-VR mode
  void _displayVRMessage(String message) {
    _vrMessageNotifier.value = message;
    // Hide the message after a delay
    Future.delayed(const Duration(seconds: 3), () {
      _vrMessageNotifier.value = null;
    });
  }

  /// Checks if it's the first launch and shows Terms of Service if needed.
  void _checkFirstLaunch() async {
    prefs = await SharedPreferences.getInstance();
    bool acceptedTerms = prefs.getBool('acceptedTerms') ?? false;
    if (!acceptedTerms) {
      _showTermsAcceptance();
    }
  }

  /// Displays the Terms of Service acceptance dialog.
  void _showTermsAcceptance() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Text(termsOfService),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // User declines, exit the app
              Navigator.of(context).pop();
              SystemNavigator.pop();
            },
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              // User accepts
              prefs.setBool('acceptedTerms', true);
              Navigator.of(context).pop();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  /// Handles changes in the settings model.
  Future<void> _onSettingsChanged() async {
    if (_settingsModel.enableVoiceCommands) {
      if (_voiceCommandUtils == null) {
        // Check if permissions are granted
        if (!await Permission.microphone.isGranted ||
            !await Permission.camera.isGranted) {
          // Permissions not granted; do not initialize speech recognition
          return;
        }
        _voiceCommandUtils = VoiceCommandUtils(
          onCommandRecognized: handleVoiceCommand,
          settingsModel: _settingsModel,
        );
        try {
          await _voiceCommandUtils!.initSpeech();
        } catch (e) {
          if (kDebugMode) {
            print('Failed to initialize speech: $e');
          }
          _showErrorSnackBar('Voice command initialization failed.');
          _voiceCommandUtils = null;
        }
        _voiceCommandUtils?.startListening();
      } else {
        _voiceCommandUtils?.startListening();
      }
    } else {
      if (_voiceCommandUtils != null) {
        _voiceCommandUtils!.stopListening();
      }
    }

    // Handle speakerEnabled changes
    _toggleSpeaker(_settingsModel.speakerEnabled);

    // Handle micEnabled changes
    if (_audioTrack != null) {
      _audioTrack!.enabled = _settingsModel.micEnabled;
    }

    setState(() {
      // Update UI if necessary
    });
  }

  Future<void> _toggleMic(bool enable) async {
    try {
      if (_audioTrack != null) {
        _audioTrack!.enabled = enable;
        if (kDebugMode) {
          print('Microphone has been ${enable ? 'enabled' : 'disabled'}.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling mic: $e');
      }
    }
  }

  // Modify _toggleSpeaker function
  Future<void> _toggleSpeaker(bool enable) async {
    try {
      if (_remoteStream != null) {
        var audioTracks = _remoteStream!.getAudioTracks();
        for (var track in audioTracks) {
          track.enabled = enable;
        }
        if (kDebugMode) {
          print('Speaker has been ${enable ? 'enabled' : 'disabled'}.');
        }
      } else {
        if (kDebugMode) {
          print('Cannot toggle speaker: Remote stream is null.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling speaker: $e');
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();

    _voiceCommandUtils?.dispose(); // Dispose voice command utils if initialized

    _settingsModel
        .removeListener(_onSettingsChanged); // Remove settings listener
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]); // Reset to dynamic orientation on dispose
    super.dispose();
  }

  Future<void> _resetApp() async {
    // Close the peer connection
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    // Stop and dispose of local media stream
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      _localStream = null;
    }

    // Stop and dispose of remote media stream
    if (_remoteStream != null) {
      _remoteStream!.getTracks().forEach((track) => track.stop());
      _remoteStream = null;
    }

    // Dispose of the renderers
    await _localRenderer.dispose();
    _localRenderer = RTCVideoRenderer();
    await _localRenderer.initialize();

    await _remoteRenderer.dispose();
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer.initialize();

    // Reset variables
    setState(() {
      _connectionCode = '';
      _isOfferer = false;
      _connecting = false;
      _isConnected = false;
      _renderersInitialized = true; // Since we re-initialized them
    });

    // Re-initialize the peer connection and media streams
    await _createPeerConnection();
  }

  @override
  Widget build(BuildContext context) {
    /// The build method remains mostly unchanged...
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/visuyou_logo_512x512.png',
                  height: 36.0, // Increased logo size
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8.0),
                const Expanded(
                  child: Text(
                    'VisuYou',
                    style: TextStyle(
                      fontSize: 10.0, // Larger font size for better readability
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow
                        .ellipsis, // Prevent overflow, but ellipsis should not be needed
                    maxLines: 1, // Prevent the title from taking too much space
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            const FittedBox(
              fit: BoxFit.scaleDown, // Scale down the subtitle to fit properly
              child: Text(
                'True P2P VR Experience',
                style: TextStyle(
                  fontSize: 16.0, // Slightly larger subtitle font
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings,
                size: 28,
                color:
                    Colors.grey), // Increased icon size and set color to grey
            onPressed: () => _navigateToSettingsPage(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline,
                size: 28,
                color:
                    Colors.grey), // Increased icon size and set color to grey
            onPressed: () => _navigateToAboutPage(context),
          ),
          DropdownButton<String>(
            value: _selectedViewMode,
            dropdownColor: Colors.black87,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down,
                color: Colors.white, size: 28),
            items: _viewModes.map((String mode) {
              return DropdownMenuItem<String>(
                value: mode,
                child: Text(mode),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue == null) return;
              setState(() {
                _selectedViewMode = newValue;
              });
              switchViewMode(newValue);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Opacity(
              opacity: 0.05, // Adjust the opacity to make it subtle
              child: Image.asset(
                'assets/visuyou_background.png', // Path to the background image
                fit: BoxFit.cover, // Cover the entire background
              ),
            ),
          ),

          // All other UI components come here
          _renderersInitialized
              ? Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: RTCVideoView(
                          _localRenderer,
                          mirror: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: RTCVideoView(
                          _remoteRenderer,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0), // Increased padding
                      child: _isConnected
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8.0),
                                Text(
                                  'Double tap to exit VR mode',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            )
                          : _connectionCode.isNotEmpty
                              ? QRCodeUtils.buildQRCodeWidget(_connectionCode)
                              : _connecting
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'No data to display',
                                      style: TextStyle(fontSize: 16), // Increased text size
                                    ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Start Connection Button
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: AnimatedStyledButton(
                                  label: 'Start Connection', // Updated label
                                  icon: Icons.link, // Updated icon
                                  onPressed: _isOfferer || _connecting
                                      ? null
                                      : _createOffer,
                                  isEnabled: !(_isOfferer || _connecting),
                                ),
                              ),
                            ),

                            // Join Session Button
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: AnimatedStyledButton(
                                  label: 'Join Session', // Updated label
                                  icon: Icons.qr_code_scanner,
                                  onPressed: _connecting ? null : _scanQRCode,
                                  isEnabled: !_connecting,
                                ),
                              ),
                            ),

                            // Disconnect Button
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: AnimatedStyledButton(
                                  label: 'Disconnect', // Updated label
                                  icon:
                                      Icons.power_settings_new, // Updated icon
                                  onPressed: _resetApp,
                                  isEnabled: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(child: CircularProgressIndicator()),

          // Global Message Overlay for Non-VR Modes
          ValueListenableBuilder<String?>(
            valueListenable: _vrMessageNotifier,
            builder: (context, message, child) {
              if (message == null) return const SizedBox.shrink();
              return Positioned(
                top: 50, // Adjust the position as needed
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Navigates to the Settings page.
  void _navigateToSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  /// Navigates to the About page.
  void _navigateToAboutPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPage()),
    );
  }
}

// VR Video View Classes

// In main.dart or wherever your VR views are defined

class FullVRVideoView extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final ValueNotifier<String?> messageNotifier;

  const FullVRVideoView({
    Key? key,
    required this.renderer,
    required this.messageNotifier,
  }) : super(key: key);

  @override
  _FullVRVideoViewState createState() => _FullVRVideoViewState();
}

class _FullVRVideoViewState extends State<FullVRVideoView> {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            final messageWidth = halfWidth * 0.8;
            final settingsModel = Provider.of<SettingsModel>(context);
            final leftEyeSeparation =
                halfWidth * settingsModel.leftEyeSeparation;
            final rightEyeSeparation =
                halfWidth * settingsModel.rightEyeSeparation;

            return Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: halfWidth,
                      height: constraints.maxHeight,
                      child: RTCVideoView(
                        widget.renderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      height: constraints.maxHeight,
                      child: RTCVideoView(
                        widget.renderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ],
                ),
                // Overlay Messages
                ValueListenableBuilder<String?>(
                  valueListenable: widget.messageNotifier,
                  builder: (context, message, child) {
                    if (message == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        SizedBox(
                          width: halfWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: (halfWidth - messageWidth) / 2 +
                                    leftEyeSeparation,
                                top: constraints.maxHeight / 2 - 50,
                                child: Container(
                                  width: messageWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: halfWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: (halfWidth - messageWidth) / 2 -
                                    rightEyeSeparation,
                                top: constraints.maxHeight / 2 - 50,
                                child: Container(
                                  width: messageWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class VR50_50VideoView extends StatelessWidget {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final ValueNotifier<String?> messageNotifier;

  const VR50_50VideoView({
    Key? key,
    required this.localRenderer,
    required this.remoteRenderer,
    required this.messageNotifier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final quarterWidth = constraints.maxWidth / 4;
            final settingsModel = Provider.of<SettingsModel>(context);
            final leftEyeSeparation =
                quarterWidth * settingsModel.leftEyeSeparation;
            final rightEyeSeparation =
                quarterWidth * settingsModel.rightEyeSeparation;
            final messageWidth = quarterWidth * 2 * 0.8; // 80% of half screen

            return Stack(
              children: [
                // Existing VR Views
                Row(
                  children: [
                    // Left Eye View
                    SizedBox(
                      width: quarterWidth * 2,
                      height: constraints.maxHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: quarterWidth,
                            height: constraints.maxHeight,
                            child: RTCVideoView(
                              localRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                          SizedBox(
                            width: quarterWidth,
                            height: constraints.maxHeight,
                            child: RTCVideoView(
                              remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right Eye View
                    SizedBox(
                      width: quarterWidth * 2,
                      height: constraints.maxHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: quarterWidth,
                            height: constraints.maxHeight,
                            child: RTCVideoView(
                              localRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                          SizedBox(
                            width: quarterWidth,
                            height: constraints.maxHeight,
                            child: RTCVideoView(
                              remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Overlay Messages
                ValueListenableBuilder<String?>(
                  valueListenable: messageNotifier,
                  builder: (context, message, child) {
                    if (message == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        // Left Eye Overlay
                        SizedBox(
                          width: quarterWidth * 2,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: (quarterWidth * 2 - messageWidth) / 2 +
                                    leftEyeSeparation,
                                top: constraints.maxHeight / 2 - 50,
                                child: Container(
                                  width: messageWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Eye Overlay
                        SizedBox(
                          width: quarterWidth * 2,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: (quarterWidth * 2 - messageWidth) / 2 -
                                    rightEyeSeparation,
                                top: constraints.maxHeight / 2 - 50,
                                child: Container(
                                  width: messageWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// PiP Mode implementation for VR headset
class PiPVideoView extends StatelessWidget {
  final RTCVideoRenderer mainRenderer;
  final RTCVideoRenderer pipRenderer;
  final ValueNotifier<String?> messageNotifier; // Add this line

  const PiPVideoView({
    Key? key,
    required this.mainRenderer,
    required this.pipRenderer,
    required this.messageNotifier, // Add this line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            final pipSize = halfWidth / 3; // Adjust as needed
            final settingsModel = Provider.of<SettingsModel>(context);
            final leftEyeSeparation =
                halfWidth * settingsModel.leftEyeSeparation;
            final rightEyeSeparation =
                halfWidth * settingsModel.rightEyeSeparation;
            final messageWidth = halfWidth * 0.8;

            // Define proportional positions
            final leftEyeRightPosition = halfWidth * 0.05 + leftEyeSeparation;
            final rightEyeRightPosition = halfWidth * 0.2 - rightEyeSeparation;

            return Stack(
              children: [
                Row(
                  children: [
                    // Left Eye View
                    SizedBox(
                      width: halfWidth,
                      height: constraints.maxHeight,
                      child: Stack(
                        children: [
                          RTCVideoView(
                            mainRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                          Positioned(
                            right: leftEyeRightPosition,
                            bottom: 20.0,
                            width: pipSize,
                            height: pipSize,
                            child: _buildPipContainer(),
                          ),
                        ],
                      ),
                    ),
                    // Right Eye View
                    SizedBox(
                      width: halfWidth,
                      height: constraints.maxHeight,
                      child: Stack(
                        children: [
                          RTCVideoView(
                            mainRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                          Positioned(
                            right: rightEyeRightPosition,
                            bottom: 20.0,
                            width: pipSize,
                            height: pipSize,
                            child: _buildPipContainer(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Overlay Messages
                ValueListenableBuilder<String?>(
                  valueListenable: messageNotifier,
                  builder: (context, message, child) {
                    if (message == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        // Left Eye Overlay
                        SizedBox(
                          width: halfWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: (halfWidth - messageWidth) / 2 +
                                    leftEyeSeparation,
                                top: constraints.maxHeight / 2 - 50,
                                child: Container(
                                  width: messageWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Eye Overlay
                        SizedBox(
                          width: halfWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: (halfWidth - messageWidth) / 2 -
                                    rightEyeSeparation,
                                top: constraints.maxHeight / 2 - 50,
                                child: Container(
                                  width: messageWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPipContainer() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: RTCVideoView(
        pipRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}
