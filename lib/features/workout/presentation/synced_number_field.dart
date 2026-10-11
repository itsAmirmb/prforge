import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/format.dart';

/// Numeric input that saves on every change and mirrors external changes.
///
/// [value] is the stored value. While the field has focus it is never
/// overwritten, so database echoes of earlier keystrokes cannot eat input.
class SyncedNumberField extends StatefulWidget {
  const SyncedNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimal = false,
  });

  final String label;
  final double? value;
  final bool decimal;

  /// Called with the parsed number, or null when the text is empty/invalid.
  final ValueChanged<double?> onChanged;

  @override
  State<SyncedNumberField> createState() => _SyncedNumberFieldState();
}

class _SyncedNumberFieldState extends State<SyncedNumberField> {
  late final _controller =
      TextEditingController(text: formatWeight(widget.value));
  final _focus = FocusNode();

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void didUpdateWidget(SyncedNumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _parse(_controller.text) != widget.value) {
      _controller.text = formatWeight(widget.value) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: widget.decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        widget.decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => widget.onChanged(_parse(v)),
    );
  }
}
