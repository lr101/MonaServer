import 'dart:typed_data';

import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/features/pin/platform/pin_photo_saver.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_group.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

class ViewImage extends ConsumerStatefulWidget {
  const ViewImage({super.key, required this.pinId, this.initialPhotoId});

  final String pinId;
  final String? initialPhotoId;

  @override
  ConsumerState<ViewImage> createState() => _ViewImageState();
}

class _ViewImageState extends ConsumerState<ViewImage> {
  bool _isDownloadingPhoto = false;
  String? _selectedPhotoId;

  @override
  void initState() {
    super.initState();
    _selectedPhotoId = widget.initialPhotoId;
  }

  @override
  void didUpdateWidget(covariant ViewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pinId != widget.pinId ||
        oldWidget.initialPhotoId != widget.initialPhotoId) {
      _selectedPhotoId = widget.initialPhotoId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(pinByIdProvider(widget.pinId));
    final toolbarPin = pin.whenOrNull(data: (value) => value);
    final currentUserId = ref.watch(userIdProvider);
    final photoHistoryState = toolbarPin == null
        ? null
        : ref.watch(pinPhotoHistoryProvider(toolbarPin.pinId));
    final photos = photoHistoryState?.value ?? const <PinPhotoDto>[];
    final originalPhoto = photos.where((photo) => photo.isOriginal).firstOrNull;
    final selectedPhoto = _selectedPhotoId == null
        ? originalPhoto
        : photos.where((photo) => photo.id == _selectedPhotoId).firstOrNull;
    final isOriginalSelected =
        _selectedPhotoId == null || selectedPhoto?.isOriginal == true;
    final originalContributorId = selectedPhoto?.contributorId;
    final selectedPhotoContributor = isOriginalSelected
        ? originalContributorId == null || originalContributorId.isEmpty
              ? toolbarPin?.creator
              : originalContributorId
        : selectedPhoto?.contributorId;
    final hasSelectedPhotoBytes = isOriginalSelected
        ? toolbarPin != null
        : selectedPhoto?.image?.isNotEmpty == true;
    final canDownloadSelectedPhoto =
        supportsPinPhotoDownload &&
        currentUserId.isNotEmpty &&
        currentUserId == selectedPhotoContributor &&
        hasSelectedPhotoBytes;
    final theme = Theme.of(context);
    final viewport = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin details'),
        actions: [
          if (toolbarPin != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopUpMenuFeed(
                pinDto: toolbarPin,
                onDownloadPhoto: canDownloadSelectedPhoto
                    ? () => _downloadPhoto(
                        pinId: toolbarPin.pinId,
                        pinCreatorId: toolbarPin.creator,
                        photo: selectedPhoto,
                        isOriginal: isOriginalSelected,
                      )
                    : null,
                isDownloadingPhoto: _isDownloadingPhoto,
                tooltip: 'Pin options',
              ),
            ),
        ],
      ),
      body: pin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this pin.')),
        data: (currentPin) {
          if (currentPin == null) {
            return const Center(child: Text('This pin is unavailable.'));
          }
          final groupName = ref
              .watch(groupMetadataProvider(currentPin.groupId))
              .value
              ?.name;
          final photoCount = photos.isEmpty ? 1 : photos.length;
          final coordinateLabel =
              '${currentPin.latitude.abs().toStringAsFixed(4)}° ${currentPin.latitude < 0 ? 'S' : 'N'} · '
              '${currentPin.longitude.abs().toStringAsFixed(4)}° ${currentPin.longitude < 0 ? 'W' : 'E'}';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final defaultHeight = width * 4 / 3;
                              final maxHeight = viewport.width >= 600
                                  ? defaultHeight.clamp(
                                      280.0,
                                      viewport.height * 0.56,
                                    )
                                  : defaultHeight;
                              return FeedCardImage(
                                key: ValueKey(currentPin.pinId),
                                item: currentPin,
                                maxWidth: width,
                                maxHeight: maxHeight,
                                initialPhotoId: widget.initialPhotoId,
                                isDetail: true,
                                onPhotoChanged: (photo) {
                                  if (_selectedPhotoId != photo.photoId) {
                                    setState(
                                      () => _selectedPhotoId = photo.photoId,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: coordinateLabel,
                                trailing: Icon(
                                  Icons.content_copy_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onTap: () {
                                  final raw =
                                      '${currentPin.latitude.toStringAsFixed(5)}, '
                                      '${currentPin.longitude.toStringAsFixed(5)}';
                                  Clipboard.setData(ClipboardData(text: raw));
                                  _showMessage('Coordinates copied.');
                                },
                              ),
                              if (groupName != null && groupName.isNotEmpty) ...[
                                Divider(
                                  height: 18,
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                                ClickableGroup(
                                  groupId: currentPin.groupId,
                                  child: _DetailRow(
                                    icon: Icons.groups_outlined,
                                    label: 'Group',
                                    value: groupName,
                                    trailing: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                              Divider(
                                height: 18,
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                              _DetailRow(
                                icon: Icons.schedule_rounded,
                                label: 'Recorded',
                                value:
                                    '${_formatRelativeAge(currentPin.creationDate)} · '
                                    '${photoCount == 1 ? '1 photo' : '$photoCount photos'}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatRelativeAge(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    if (diff.inDays > 0) {
      return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    }
    if (diff.inHours > 0) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inMinutes > 0) {
      return diff.inMinutes == 1
          ? '1 minute ago'
          : '${diff.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  Future<void> _downloadPhoto({
    required String pinId,
    required String pinCreatorId,
    required PinPhotoDto? photo,
    required bool isOriginal,
  }) async {
    if (_isDownloadingPhoto) return;
    setState(() => _isDownloadingPhoto = true);
    _showMessage('Downloading photo…', duration: const Duration(seconds: 25));
    try {
      final bytes = await _loadPhotoBytes(
        photo: photo,
        pinId: pinId,
        pinCreatorId: pinCreatorId,
        isOriginal: isOriginal,
      );
      final name = _photoFileName(pinId, photo?.id ?? 'original');
      await savePinPhoto(bytes, name: name);
      if (mounted) _showMessage('Photo saved to your device.');
    } on _PinPhotoDownloadException {
      if (mounted) {
        _showMessage('Could not download this photo. Check your connection.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not save this photo. Check photo access and device storage.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPhoto = false);
    }
  }

  Future<Uint8List> _loadPhotoBytes({
    required String pinId,
    required String pinCreatorId,
    required PinPhotoDto? photo,
    required bool isOriginal,
  }) async {
    var photoToDownload = photo;
    if (photo != null) {
      try {
        final photos = await ref
            .read(photoLibraryProvider)
            .refreshHistory(pinId)
            .timeout(const Duration(seconds: 20));
        photoToDownload = photos
            .where(
              (candidate) =>
                  candidate.id == photo.id &&
                  candidate.pinId == pinId &&
                  candidate.isOriginal == isOriginal,
            )
            .firstOrNull;
        if (photoToDownload == null) {
          throw const _PinPhotoDownloadException();
        }

        final contributorId = photoToDownload.contributorId;
        final ownerId =
            isOriginal && (contributorId == null || contributorId.isEmpty)
            ? pinCreatorId
            : contributorId;
        final currentUserId = ref.read(userIdProvider);
        if (currentUserId.isEmpty || currentUserId != ownerId) {
          throw const _PinPhotoDownloadException();
        }
      } on _PinPhotoDownloadException {
        rethrow;
      } catch (_) {
        throw const _PinPhotoDownloadException();
      }
    }

    final imageUrl =
        photoToDownload?.image ??
        (isOriginal
            ? (await ref
                      .read(remoteImageSourcesProvider)
                      .resolve(
                        RemoteImageReference(
                          kind: RemoteImageKind.pin,
                          id: pinId,
                        ),
                        attempt: 3,
                      ))
                  ?.url
            : null);
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const _PinPhotoDownloadException();
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const _PinPhotoDownloadException();
    }
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        throw const _PinPhotoDownloadException();
      }
      return response.bodyBytes;
    } on _PinPhotoDownloadException {
      rethrow;
    } catch (_) {
      throw const _PinPhotoDownloadException();
    }
  }

  String _photoFileName(String pinId, String photoId) {
    final safePinId = pinId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    final safePhotoId = photoId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'stick-it-$safePinId-$safePhotoId';
  }

  void _showMessage(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: duration));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

class _PinPhotoDownloadException implements Exception {
  const _PinPhotoDownloadException();
}
