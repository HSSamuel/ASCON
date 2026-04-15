import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ascon_mobile/services/api_client.dart';
import 'package:audio_session/audio_session.dart';

enum CallEvent { ringing, connected, callEnded, error, userJoined, userOffline }

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  bool isJoined = false;
  
  // ✅ Track multiple UIDs for Group Video Calls
  Set<int> remoteUids = {}; 

  final _callEventController = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  // ✅ Expose engine for Video Rendering in UI
  RtcEngine get engine => _engine; 

  Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      await [Permission.microphone, Permission.camera].request();
    }

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';
    if (appId.isEmpty) {
      debugPrint("❌ Agora App ID is missing from env.txt");
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        logConfig: const LogConfig(level: LogLevel.logLevelError),
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Agora Joined Channel: ${connection.channelId}");
          isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("📞 Remote user answered! UID: $remoteUid");
          remoteUids.add(remoteUid); 
          _callEventController.add(CallEvent.connected);
          _callEventController.add(CallEvent.userJoined);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("📞 Remote user left! UID: $remoteUid");
          remoteUids.remove(remoteUid); 
          _callEventController.add(CallEvent.callEnded);
          _callEventController.add(CallEvent.userOffline);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          _callEventController.add(CallEvent.error);
        },
      ),
    );

    await _engine.enableAudio();
    _isInitialized = true;
  }

  Future<bool> joinCall({required String channelName, bool isVideo = false}) async {
    if (!_isInitialized) await init();

    try {
      final response = await ApiClient().post('/api/agora/token', {'channelName': channelName});
      final responseData = response['data'] ?? response;

      if (responseData['token'] != null) {
        String token = responseData['token'];

        if (isVideo) {
           await _engine.enableVideo();
           await _engine.startPreview();
        } else {
           await _engine.disableVideo();
        }

        await _engine.joinChannel(
          token: token,
          channelId: channelName,
          uid: 0,
          options: ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileCommunication,
            publishCameraTrack: isVideo, 
            publishMicrophoneTrack: true, 
          ),
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> leaveCall() async {
    if (isJoined) {
      try {
        await _engine.stopPreview(); 
      } catch (_) {}
      await _engine.leaveChannel();
      remoteUids.clear(); 
      isJoined = false;
    }
  }

  Future<void> toggleMute(bool isMuted) async {
    if (_isInitialized) await _engine.muteLocalAudioStream(isMuted);
  }

  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    if (_isInitialized) await _engine.setEnableSpeakerphone(isSpeakerOn);
  }

  // ✅ NEW: Fetch available audio output devices (Web/Windows)
  Future<List<AudioDeviceInfo>> getPlaybackDevices() async {
    if (!_isInitialized) return [];
    try {
      return await _engine.getAudioDeviceManager().enumeratePlaybackDevices();
    } catch (e) {
      debugPrint("Error fetching audio devices: $e");
      return [];
    }
  }

  // ✅ NEW: Route audio to a specific device ID (Web/Windows)
  Future<void> setPlaybackDevice(String deviceId) async {
    if (!_isInitialized) return;
    try {
      await _engine.getAudioDeviceManager().setPlaybackDevice(deviceId);
      debugPrint("✅ Audio routed to device: $deviceId");
    } catch (e) {
      debugPrint("Error setting playback device: $e");
    }
  }

  // ✅ FIXED: Advanced Native Audio Routing 
  Future<void> setAudioRoute(String route) async {
    if (!_isInitialized) return;

    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) {
        if (route == 'Speaker') {
          await _engine.setEnableSpeakerphone(true);
        } else {
          await _engine.setEnableSpeakerphone(false);
        }
        return; 
      }

      final session = await AudioSession.instance;

      if (route == 'Speaker') {
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.videoChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        await _engine.setEnableSpeakerphone(true);
      } 
      else if (route == 'Earpiece') {
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        await _engine.setEnableSpeakerphone(false);
      } 
      else if (route == 'Bluetooth') {
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth, 
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        await _engine.setEnableSpeakerphone(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting native audio route: $e");
      }
    }
  }

  Future<void> toggleVideo(bool isVideoOff) async {
    if (_isInitialized) {
      await _engine.muteLocalVideoStream(isVideoOff);
    }
  }

  Future<void> switchCamera() async {
    if (_isInitialized) {
      await _engine.switchCamera();
    }
  }
}