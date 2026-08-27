import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';

class SubmitButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final String text;
  final double height;
  final IconData icon;

  const SubmitButton({
    super.key,
    required this.onPressed,
    this.text = 'Submit',
    this.height = 50,
    this.icon = Icons.arrow_forward,
  });

  @override
  _SubmitButtonState createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool _isLoading = false;

  final Mutex _m = Mutex();

  Future<void> _handlePress() async {
    if (_isLoading || _m.isLocked) return;
    await _m.acquire();
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _m.release();
    }
  }

  @override
  Widget build(BuildContext context) {

    return  Align(
      alignment: Alignment.bottomRight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          textStyle: const TextStyle(fontSize: 18.0),
          side: BorderSide(width: 2, color: Theme.of(context).colorScheme.primary),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isLoading) const CircularProgressIndicator() else Text(widget.text),
              const SizedBox(width: 5),
              Icon(widget.icon),
            ],
          ),
        ),
      ),
    );
  }
}
