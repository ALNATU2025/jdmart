import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';

class QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const QtyStepper({super.key, required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: context.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less',
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'More',
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
