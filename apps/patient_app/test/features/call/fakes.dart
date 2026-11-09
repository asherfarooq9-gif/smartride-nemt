import 'package:patient_app/features/call/call_media.dart';
import 'package:patient_app/features/call/call_signaling.dart';

/// The call socket in memory: records what the phone sends, and lets a test play
/// the other person and the server.
class FakeCallSignaling implements CallSignaling {
  final List<Map<String, dynamic>> sent = [];
  int connectCalls = 0;
  int closeCalls = 0;
  bool sendWorks = true;
  void Function(Map<String, dynamic>)? _onFrame;

  Iterable<String> get sentTypes => sent.map((f) => f['type'] as String);

  void receive(Map<String, dynamic> frame) => _onFrame?.call(frame);

  @override
  Future<void> connect(
    String rideId, {
    required void Function(Map<String, dynamic>) onFrame,
  }) async {
    connectCalls++;
    _onFrame = onFrame;
  }

  @override
  bool send(Map<String, dynamic> frame) {
    if (!sendWorks) return false;
    sent.add(frame);
    return true;
  }

  @override
  Future<void> close() async => closeCalls++;
}

/// The phone's side of the audio, in memory.
class FakeCallMedia implements CallMedia {
  FakeCallMedia({this.openError});

  final Object? openError;
  List<Map<String, dynamic>>? openedWith;
  final List<Map<String, dynamic>> candidatesAdded = [];
  final List<String> events = [];
  String? appliedAnswer;
  String? answeredOffer;
  bool muted = false;
  bool speaker = false;
  bool closed = false;
  void Function(Map<String, dynamic>)? _onCandidate;
  void Function()? _onConnected;
  void Function()? _onFailed;

  void emitCandidate(Map<String, dynamic> candidate) =>
      _onCandidate?.call(candidate);
  void emitConnected() => _onConnected?.call();
  void emitFailed() => _onFailed?.call();

  @override
  Future<void> open({
    required List<Map<String, dynamic>> iceServers,
    required void Function(Map<String, dynamic> candidate) onCandidate,
    required void Function() onConnected,
    required void Function() onFailed,
  }) async {
    final error = openError;
    if (error != null) throw error;
    events.add('open');
    openedWith = iceServers;
    _onCandidate = onCandidate;
    _onConnected = onConnected;
    _onFailed = onFailed;
  }

  @override
  Future<String> createOffer() async {
    events.add('createOffer');
    return 'offer-sdp';
  }

  @override
  Future<String> createAnswer(String offerSdp) async {
    events.add('createAnswer');
    answeredOffer = offerSdp;
    return 'answer-sdp';
  }

  @override
  Future<void> applyAnswer(String sdp) async {
    events.add('applyAnswer');
    appliedAnswer = sdp;
  }

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    events.add('addCandidate');
    candidatesAdded.add(candidate);
  }

  @override
  void setMuted(bool value) => muted = value;

  @override
  Future<void> setSpeaker(bool value) async => speaker = value;

  @override
  Future<void> close() async => closed = true;
}
