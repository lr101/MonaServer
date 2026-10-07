import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const _webLoginFormId = 'stick-it-login-autofill-form';

class AuthAutofillFormElement extends StatefulWidget {
  const AuthAutofillFormElement({super.key});

  @override
  State<AuthAutofillFormElement> createState() =>
      _AuthAutofillFormElementState();
}

class _AuthAutofillFormElementState extends State<AuthAutofillFormElement> {
  web.HTMLFormElement? _form;

  @override
  void initState() {
    super.initState();
    final existing = web.document.getElementById(_webLoginFormId);
    if (existing != null && existing.isA<web.HTMLFormElement>()) {
      _form = existing as web.HTMLFormElement;
      return;
    }

    final form = web.HTMLFormElement()
      ..id = _webLoginFormId
      ..method = 'post'
      ..action = '#'
      ..noValidate = true;
    form.style
      ..position = 'fixed'
      ..top = '0'
      ..left = '0'
      ..width = '1px'
      ..height = '1px'
      ..margin = '0'
      ..padding = '0'
      ..border = '0'
      ..overflow = 'visible'
      ..pointerEvents = 'none';
    form.addEventListener(
      'submit',
      ((web.Event event) => event.preventDefault()).toJS,
    );
    web.document.body?.append(form);
    _form = form;
  }

  @override
  void dispose() {
    _form?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AuthAutofillField extends StatefulWidget {
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
  State<AuthAutofillField> createState() => _AuthAutofillFieldState();
}

class _AuthAutofillFieldState extends State<AuthAutofillField> {
  web.HTMLInputElement? _input;
  bool _hasFocus = false;

  late final JSFunction _inputListener = ((web.Event _) => _handleInput()).toJS;
  late final JSFunction _focusListener = ((web.Event _) => _handleFocus()).toJS;
  late final JSFunction _blurListener = ((web.Event _) => _handleBlur()).toJS;
  late final JSFunction _submitListener = ((
    web.KeyboardEvent event,
  ) => _handleKeyDown(event)).toJS;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    widget.focusNode.addListener(_handleFocusNodeChanged);
    _hasFocus = widget.focusNode.hasFocus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyInputStyle();
  }

  @override
  void didUpdateWidget(covariant AuthAutofillField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusNodeChanged);
      widget.focusNode.addListener(_handleFocusNodeChanged);
      _hasFocus = widget.focusNode.hasFocus;
    }
    _syncInputFromWidget();
    _applyInputStyle();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.focusNode.removeListener(_handleFocusNodeChanged);
    final input = _input;
    if (input != null) {
      input
        ..removeEventListener('input', _inputListener)
        ..removeEventListener('change', _inputListener)
        ..removeEventListener('focus', _focusListener)
        ..removeEventListener('blur', _blurListener)
        ..removeEventListener('keydown', _submitListener);
    }
    super.dispose();
  }

  void _onElementCreated(Object element) {
    final input = element as web.HTMLInputElement;
    _input = input;
    input
      ..id = 'stick-it-login-${widget.name}'
      ..name = widget.name
      ..type = widget.obscureText ? 'password' : 'text'
      ..autocomplete = widget.autocomplete
      ..value = widget.controller.text
      ..disabled = !widget.enabled
      ..tabIndex = 0
      ..setAttribute('form', _webLoginFormId)
      ..setAttribute('aria-label', widget.decoration.labelText ?? widget.name)
      ..setAttribute(
        'inputmode',
        widget.keyboardType == TextInputType.emailAddress ? 'email' : 'text',
      )
      ..setAttribute('autocapitalize', 'off')
      ..spellcheck = false;
    input
      ..addEventListener('input', _inputListener)
      ..addEventListener('change', _inputListener)
      ..addEventListener('focus', _focusListener)
      ..addEventListener('blur', _blurListener)
      ..addEventListener('keydown', _submitListener);
    _applyInputStyle();
  }

  void _handleInput() {
    final input = _input;
    if (input == null) return;
    final text = input.value;
    if (widget.controller.text != text) {
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _handleControllerChanged() {
    _syncInputFromWidget();
    if (mounted) setState(() {});
  }

  void _syncInputFromWidget() {
    final input = _input;
    if (input == null) return;
    input
      ..disabled = !widget.enabled
      ..type = widget.obscureText ? 'password' : 'text'
      ..autocomplete = widget.autocomplete;
    if (input.value != widget.controller.text) {
      input.value = widget.controller.text;
    }
  }

  void _handleFocus() {
    _hasFocus = true;
    if (!widget.focusNode.hasFocus) widget.focusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _handleBlur() {
    _hasFocus = false;
    if (widget.focusNode.hasFocus) widget.focusNode.unfocus();
    if (mounted) setState(() {});
  }

  void _handleFocusNodeChanged() {
    final hasFocus = widget.focusNode.hasFocus;
    _hasFocus = hasFocus;
    final input = _input;
    if (input != null) {
      if (hasFocus && !input.matches(':focus')) {
        input.focus();
      } else if (!hasFocus && input.matches(':focus')) {
        input.blur();
      }
    }
    if (mounted) setState(() {});
  }

  void _handleKeyDown(web.KeyboardEvent event) {
    if (event.key != 'Enter') return;
    event.preventDefault();
    widget.onSubmitted?.call(widget.controller.text);
  }

  void _applyInputStyle() {
    final input = _input;
    if (input == null) return;
    final textStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final color = Theme.of(context).colorScheme.onSurface.toARGB32();
    final cssColor =
        '#${(color & 0x00ffffff).toRadixString(16).padLeft(6, '0')}';
    final fontSize = textStyle.fontSize ?? 16;
    final lineHeight = fontSize * (textStyle.height ?? 1.5);
    input.style
      ..display = 'block'
      ..boxSizing = 'border-box'
      ..width = '100%'
      ..height = '${lineHeight}px'
      ..margin = '0'
      ..padding = '0'
      ..border = '0'
      ..outline = 'none'
      ..backgroundColor = 'transparent'
      ..color = cssColor
      ..fontFamily = textStyle.fontFamily ?? 'sans-serif'
      ..fontSize = '${fontSize}px'
      ..fontWeight = '${textStyle.fontWeight?.value ?? 400}'
      ..lineHeight = '${lineHeight}px'
      ..letterSpacing = '${textStyle.letterSpacing ?? 0}px'
      ..appearance = 'none';
  }

  @override
  Widget build(BuildContext context) {
    final textStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final lineHeight = (textStyle.fontSize ?? 16) * (textStyle.height ?? 1.5);
    return Focus(
      focusNode: widget.focusNode,
      child: InputDecorator(
        decoration: widget.decoration.copyWith(enabled: widget.enabled),
        isFocused: _hasFocus,
        isEmpty: widget.controller.text.isEmpty,
        child: SizedBox(
          height: lineHeight,
          width: double.infinity,
          child: HtmlElementView.fromTagName(
            key: ValueKey<String>('auth-dom-input-${widget.name}'),
            tagName: 'input',
            onElementCreated: _onElementCreated,
          ),
        ),
      ),
    );
  }
}
