import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeric keypad with dot indicators. Calls [onCompleted] when [length]
/// digits are entered, then clears itself.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onCompleted,
    this.error = false,
    this.enabled = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final bool error;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _value = '';

  void _tap(String digit) {
    if (!widget.enabled || _value.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      final v = _value;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _value = '');
        widget.onCompleted(v);
      });
    }
  }

  void _back() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.error ? scheme.error : scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _value.length ? color : Colors.transparent,
                  border: Border.all(
                    color: widget.error ? scheme.error : scheme.outline,
                    width: 1.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in row)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: k.isEmpty
                        ? null
                        : Material(
                            color: k == '<'
                                ? Colors.transparent
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: .6,
                                  ),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: k == '<' ? _back : () => _tap(k),
                              child: Center(
                                child: k == '<'
                                    ? const Icon(Icons.backspace_outlined)
                                    : Text(
                                        k,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
