import 'package:flutter/material.dart';

class AuthAutofillFormElement extends StatelessWidget {
  const AuthAutofillFormElement({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AuthAutofillField extends StatelessWidget {
  const AuthAutofillField({
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.enabled,
    required this.autofillHints,
    required this.name,
    required this.autocomplete,
    required this.keyboardType,
    required this.textInputAction,
    required this.obscureText,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final bool enabled;
  final Iterable<String> autofillHints;
  final String name;
  final String autocomplete;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    key: key,
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    autofillHints: autofillHints,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    obscureText: obscureText,
    onSubmitted: onSubmitted,
    decoration: decoration,
  );
}
