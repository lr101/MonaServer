import 'dart:async';
import 'package:buff_lisa/data/service/init_service.dart';
import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncingPreview extends ConsumerWidget {
  const SyncingPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(syncingServiceProvider);
    ref.watch(initServiceProvider); // request permissions
    if (syncing == SyncState.syncing) {
      return  _content(true);
    } else if (syncing == SyncState.failed) {
      return _content(false);
    } else {
      return const SizedBox.shrink();
    }
  }
  
  Widget _content(bool loading) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.all(10),
        child: loading ? const LoadingTextAnimation() : Text("Offline", style: TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade600,
        ),
        ),
      ),
    );
  }
}

class LoadingTextAnimation extends StatefulWidget {
  const LoadingTextAnimation({super.key});

  @override
  _LoadingTextAnimationState createState() => _LoadingTextAnimationState();
}

class _LoadingTextAnimationState extends State<LoadingTextAnimation> {
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update the dot count every 500 milliseconds.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotCount = _dotCount % 3 + 1; // Cycles through 1, 2, and 3 dots.
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when disposing.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.bold,
      color: Colors.blueGrey.shade600,
    );

    // Using a Stack with an invisible text widget ensures the overall width
    // always matches the maximum string "Syncing...".
    return Stack(
      children: [
        // Invisible text that reserves the maximum width.
        Opacity(
          opacity: 0,
          child: Text(
            "Syncing...",
            style: textStyle,
          ),
        ),
        // Animated text overlaid on top.
        Text(
          "Syncing${"." * _dotCount}",
          style: textStyle,
        ),
      ],
    );
  }
}
