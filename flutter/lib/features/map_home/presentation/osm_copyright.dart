import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OsmCopyright extends StatelessWidget {
  const OsmCopyright({super.key});


  @override
  Widget build(BuildContext context) {
      return Align(
      alignment: Alignment.bottomLeft,
        child: Padding(padding: const EdgeInsets.all(5), child: GestureDetector(
          onTap: () => _onTap(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.5), // Semi-transparent grey
              borderRadius: BorderRadius.circular(8.0), // Rounded corners
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ), // Internal padding for the text
            child: const Text(
              "© OpenStreetMap",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),),),);
    }

  void _onTap(BuildContext context) {
    context.pushNamed("web", queryParameters: {
      "url": "https://www.openstreetmap.org/copyright",
      "title": "OpenStreetMap Copyright",
    },);
  }
}
