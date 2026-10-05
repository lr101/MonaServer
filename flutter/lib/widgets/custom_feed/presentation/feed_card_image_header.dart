import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_group.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

/// The compact attribution overlay shown over a pin photo.
class FeedCardImageHeader extends ConsumerStatefulWidget {
  const FeedCardImageHeader({
    super.key,
    required this.pin,
    this.distance,
    this.showOptions = true,
  });

  final PinEntity pin;
  final double? distance;
  final bool showOptions;

  @override
  ConsumerState<FeedCardImageHeader> createState() =>
      _FeedCardImageHeaderState();
}

class _FeedCardImageHeaderState extends ConsumerState<FeedCardImageHeader> {
  Future<List<Placemark>>? _location;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void didUpdateWidget(covariant FeedCardImageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin.latitude != widget.pin.latitude ||
        oldWidget.pin.longitude != widget.pin.longitude ||
        oldWidget.distance != widget.distance) {
      _loadLocation();
    }
  }

  void _loadLocation() {
    _location = widget.distance == null && !kIsWeb
        ? Future<List<Placemark>>.sync(
            () => placemarkFromCoordinates(
              widget.pin.latitude,
              widget.pin.longitude,
            ),
          ).catchError((_) => <Placemark>[])
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final authorId = widget.pin.creator;
    final author = authorId.isEmpty
        ? widget.pin.contributorUsername ?? 'Former user'
        : ref.watch(userByIdUsernameProvider(authorId)).value ??
              widget.pin.contributorUsername ??
              'Former user';
    final selectedBatch = authorId.isEmpty
        ? null
        : ref.watch(userByIdSelectedBatchProvider(authorId)).value;
    final selectedBatchColor = authorId.isEmpty
        ? null
        : ref.watch(
            userServiceProvider(authorId)
                .select((user) => user.value?.selectedBatchColor),
          );

    final header = Row(
      children: [
        _OverlappingProfilePictures(
          authorId: authorId,
          groupId: widget.pin.groupId,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: authorId.isEmpty
                        ? Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          )
                        : ClickableUser(
                            userId: authorId,
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                  ),
                  if (selectedBatch != null) ...[
                    const SizedBox(width: 5),
                    Batch(
                      batchId: selectedBatch,
                      fontSize: 7,
                      colorOverride: selectedBatchColor,
                    ),
                  ],
                ],
              ),
              _locationLabel(context),
            ],
          ),
        ),
        if (widget.showOptions) PopUpMenuFeed(pinDto: widget.pin),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: header,
    );
  }

  Widget _locationLabel(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white,
      fontStyle: FontStyle.italic,
      fontSize: 10,
      height: 1,
    );
    if (widget.distance case final distance?) {
      final text = distance >= 1000
          ? '~ ${(distance / 1000).toStringAsFixed(1)} km near you'
          : '~ ${distance.toInt()} m near you';
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }
    if (kIsWeb) {
      return Text(
        _coordinateLabel(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }
    if (_location == null) return const SizedBox.shrink();

    return FutureBuilder<List<Placemark>>(
      future: _location,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final placemarks = snapshot.data;
        final label = placemarks == null || placemarks.isEmpty
            ? null
            : _placemarkLabel(placemarks.first);
        return Text(
          label ?? _coordinateLabel(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      },
    );
  }

  String _coordinateLabel() {
    final latitude = widget.pin.latitude;
    final longitude = widget.pin.longitude;
    return '${latitude.abs().toStringAsFixed(4)}° ${latitude < 0 ? 'S' : 'N'} · '
        '${longitude.abs().toStringAsFixed(4)}° ${longitude < 0 ? 'W' : 'E'}';
  }

  String? _placemarkLabel(Placemark placemark) {
    final parts =
        [placemark.locality, placemark.administrativeArea, placemark.country]
            .map((part) => part?.trim())
            .whereType<String>()
            .where((part) => part.isNotEmpty);
    final uniqueParts = <String>[];
    for (final part in parts) {
      if (!uniqueParts.any(
        (existing) => existing.toLowerCase() == part.toLowerCase(),
      )) {
        uniqueParts.add(part);
      }
    }
    return uniqueParts.isEmpty ? null : uniqueParts.join(', ');
  }
}

class _OverlappingProfilePictures extends StatelessWidget {
  const _OverlappingProfilePictures({
    required this.authorId,
    required this.groupId,
  });

  final String authorId;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final userAvatar = authorId.isEmpty
        ? const CircleAvatar(
            radius: 12,
            child: Icon(Icons.person_outline, size: 18),
          )
        : ClickableUser(
            userId: authorId,
            child: SmallProfilePicture.user(userId: authorId, radius: 9),
          );

    return SizedBox(
      width: 40,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, child: userAvatar),
          Positioned(
            left: 15,
            top: 0,
            child: ClickableGroup(
              groupId: groupId,
              child: SmallProfilePicture.group(groupId: groupId, radius: 9),
            ),
          ),
        ],
      ),
    );
  }
}
