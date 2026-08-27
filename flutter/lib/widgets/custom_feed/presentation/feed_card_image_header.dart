import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

class FeedCardImageHeader extends ConsumerWidget {
  final PinEntity pin;
  final double? distance;

  const FeedCardImageHeader({super.key, required this.pin, this.distance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch images
    final userImage = ref.watch(getUserProfileSmallProvider(pin.creator));
    final groupImage = ref.watch(groupProfilePictureSmallByIdProvider(pin.groupId));
    
    final selectedBatch = ref.watch(userByIdSelectedBatchProvider(pin.creator));
    final username = ref.watch(userByIdUsernameProvider(pin.creator));

    // Common size for both avatars
    const double avatarSize = 14.0; // Radius (so diameter is 36)

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // 2. STACKED IMAGES
            SizedBox(
              width: avatarSize * 4, // Width to hold both overlapped images
              height: 40,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: avatarSize, 
                    child:  RoundImage(
                          imageCallback: groupImage,
                          size: avatarSize, 
                    ),
                  ),

                  Positioned(
                    left: 0,
                    child: ClickableUser(
                      userId: pin.creator,
                      child:RoundImage(
                          imageCallback: userImage, 
                          size: avatarSize, 
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            
            // 3. TEXT INFO
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: ClickableUser(
                          userId: pin.creator,
                          child: Text(
                            username.value ?? "...",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (selectedBatch.value != null)
                        Batch(batchId: selectedBatch.value!, fontSize: 7),
                    ],
                  ),
                  if (distance != null) getDistance(),
                  if (distance == null && !kIsWeb) getPinLocation(),
                ],
              ),
            ),

            // 4. MENU
            Align(
              alignment: Alignment.centerRight,
              child: PopUpMenuFeed(pinDto: pin),
            ),
          ],
        ),
      ),
    );
  }

  Widget getDistance() {
    final text = "~ ${distance! >= 1000 ? "${distance! ~/ 1000}km near you" : "${distance!.toInt()}m near you"}";
    return Text(
      text,
      style: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.white,
        fontSize: 10,
      ),
    );
  }

  Widget getPinLocation() {
    return FutureBuilder<List<Placemark>>(
      future: placemarkFromCoordinates(
        pin.latitude,
        pin.longitude,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          final Placemark first = snapshot.data!.first;
          String near = "";
          if (first.locality != null) {
            near += first.locality!;
            if (first.isoCountryCode != null) {
              near += " (${first.isoCountryCode})";
            }
          } else if (first.country != null) {
            near += first.country ?? "";
          }
          return Text(
            near,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white,
              fontSize: 10,
            ),
          );
        } else {
          return const Text("", style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white,
              fontSize: 10,
            ),
          );
        }
      },
    );
  }
}
