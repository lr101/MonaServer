
class PinNotFoundException implements Exception {
  final String pinId;
  PinNotFoundException({required this.pinId});
}
