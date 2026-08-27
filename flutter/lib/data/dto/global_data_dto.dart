
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@immutable
class GlobalDataDto {

  final String? userId;
  final String? refreshToken;
  String get host => dotenv.env['API_HOST'] ?? "https://stick-it.lr-projects.de";
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
