import 'package:flutter_webrtc/flutter_webrtc.dart';

/// The person did not allow the microphone, or the phone has none to use.
class CallPermissionDenied implements Exception {
  const CallPermissionDenied();

  @override
  String toString() => 'CallPermissionDenied';
}

/// This phone's side of a call: the microphone, the peer connection and the
/// speaker. Behind an interface so the call logic can be tested without audio.
abstract class CallMedia {
  /// Gets the microphone (asking permission) and prepares the connection.
  /// Throws [CallPermissionDenied] when there is no microphone to use.
  Future<void> open({
    required List<Map<String, dynamic>> iceServers,
    required void Function(Map<String, dynamic> candidate) onCandidate,
    required void Function() onConnected,
    required void Function() onFailed,
  });

  Future<String> createOffer();

  /// Applies the other side's offer and returns this side's answer.
  Future<String> createAnswer(String offerSdp);

  Future<void> applyAnswer(String sdp);

  Future<void> addCandidate(Map<String, dynamic> candidate);

  void setMuted(bool muted);

  Future<void> setSpeaker(bool on);

  Future<void> close();
}

/// The real thing, on flutter_webrtc. Only exercised on a device: it needs a
/// microphone and a network.
class WebRtcCallMedia implements CallMedia {
  RTCPeerConnection? _connection;
  MediaStream? _microphone;

  RTCPeerConnection get _pc => _connection!;

  @override
  Future<void> open({
    required List<Map<String, dynamic>> iceServers,
    required void Function(Map<String, dynamic> candidate) onCandidate,
    required void Function() onConnected,
    required void Function() onFailed,
  }) async {
    final MediaStream microphone;
    try {
      microphone = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } on Object {
      throw const CallPermissionDenied();
    }
    _microphone = microphone;

    final connection = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _connection = connection;
    for (final track in microphone.getAudioTracks()) {
      await connection.addTrack(track, microphone);
    }
    connection.onIceCandidate = (candidate) {
      final line = candidate.candidate;
      if (line == null) return;
      onCandidate({
        'candidate': line,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    connection.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          onConnected();
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          onFailed();
        // "disconnected" often heals by itself, so it does not end the call.
        default:
          break;
      }
    };
  }

  @override
  Future<String> createOffer() async {
    final offer = await _pc.createOffer({'offerToReceiveAudio': 1});
    await _pc.setLocalDescription(offer);
    return offer.sdp!;
  }

  @override
  Future<String> createAnswer(String offerSdp) async {
    await _pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
    final answer = await _pc.createAnswer();
    await _pc.setLocalDescription(answer);
    return answer.sdp!;
  }

  @override
  Future<void> applyAnswer(String sdp) =>
      _pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) => _pc.addCandidate(
        RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          candidate['sdpMLineIndex'] as int?,
        ),
      );

  @override
  void setMuted(bool muted) {
    for (final track in _microphone?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
  }

  @override
  Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

  @override
  Future<void> close() async {
    for (final track in _microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _microphone?.dispose();
    await _connection?.close();
    _microphone = null;
    _connection = null;
  }
}
