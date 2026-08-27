
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:openapi/api.dart';

@immutable
class CurrentUserDto {
  final String? username;
  final Uint8List? profileImage;
  final Uint8List? profileImageSmall;
  final String? description;
  final int? selectedBatch;
  final UserXpDto xp;

  const CurrentUserDto({required this.username, this.profileImage, this.profileImageSmall, this.description, required this.selectedBatch, required this.xp});

}
