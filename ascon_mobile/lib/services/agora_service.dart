import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; 
import 'package:audio_session/audio_session.dart'; 
import 'dart:io' show Platform;

class AgoraService {
  late RtcEngine engine; 
  bool isJoined = false;
  bool _isInitialized = false; 

  Future<void> initializeAgora({
    required bool isVideoCall, 
    required Function(int uid) onUserJoined, 
    required Function(int uid) onUserOffline
  }) async {
    
    if (!kIsWeb) {
      if (isVideoCall) {
        await [Permission.microphone, Permission.camera].request();
      } else {
        await [Permission.microphone].request();
      }
    }

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';

    engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          onUserJoined(remoteUid); 
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          onUserOffline(remoteUid); 
        },
      ),
    );

    await engine.enableAudio();

    if (isVideoCall) {
      await engine.enableVideo();
    }
    
    _isInitialized = true; 
  }

  Future<void> joinCall({required String token, required String channelName}) async {
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication, 
      ),
    );
  }

  // ✅ NEW: Fetch available audio output devices (Web/Windows)
  Future<List<AudioDeviceInfo>> getPlaybackDevices() async {
    if (!_isInitialized) return [];
    try {
      return await engine.getAudioDeviceManager().enumeratePlaybackDevices();
    } catch (e) {
      if (kDebugMode) print("Error fetching audio devices: $e");
      return [];
    }
  }

  // ✅ NEW: Route audio to a specific device ID (Web/Windows)
  Future<void> setPlaybackDevice(String deviceId) async {
    if (!_isInitialized) return;
    try {
      await engine.getAudioDeviceManager().setPlaybackDevice(deviceId);
      if (kDebugMode) print("✅ Audio routed to device: $deviceId");
    } catch (e) {
      if (kDebugMode) print("Error setting playback device: $e");
    }
  }

  // ✅ FIXED: Advanced Native Audio Routing 
  Future<void> setAudioRoute(String route) async {
    if (!_isInitialized) return;

    try {
      bool isDesktopOrWeb = kIsWeb;
      if (!kIsWeb) {
        isDesktopOrWeb = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      }

      if (isDesktopOrWeb) {
        if (route == 'Speaker') {
          await engine.setEnableSpeakerphone(true); 
        } else {
          await engine.setEnableSpeakerphone(false); 
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
        await engine.setEnableSpeakerphone(true); 
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
        await engine.setEnableSpeakerphone(false); 
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
        await engine.setEnableSpeakerphone(false); 
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting native audio route: $e");
      }
    }
  }

  Future<void> leaveCall() async {
    if (isJoined) {
      await engine.leaveChannel();
      isJoined = false;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
       await engine.release();
       _isInitialized = false;
    }
  }
}