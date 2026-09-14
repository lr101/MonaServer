import 'package:buff_lisa/core/session/session_status.dart';
import 'package:buff_lisa/data/config/api_host.dart';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@immutable
class GlobalDataDto {
  SessionStatus get sessionStatus => userId == null
      ? SessionStatus.signedOut
      : refreshToken?.isNotEmpty == true
      ? SessionStatus.signedIn
      : SessionStatus.expired;
  final String? userId;
  final String? refreshToken;
  String get host => resolveApiHost(configuredHost: dotenv.env['API_HOST']);
  final List<CameraDescription> cameras;

  const GlobalDataDto({
    required this.userId,
    required this.refreshToken,
    required this.cameras,
  });

  GlobalDataDto copyWith({
    String? userId,
    String? refreshToken,
    List<CameraDescription>? cameras,
  }) {
    return GlobalDataDto(
      userId: userId ?? this.userId,
      refreshToken: refreshToken ?? this.refreshToken,
      cameras: cameras ?? this.cameras,
    );
  }
}
