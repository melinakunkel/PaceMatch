import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/pace_format.dart';

/// A tappable field that opens a scroll-wheel picker for a pace value —
/// minutes:seconds per km for pace-based sports, or a plain km/h wheel for
/// speed-based ones (matches [SportType.defaultUnit]).
class PacePickerField extends StatelessWidget {
  const PacePickerField({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String unit; // 'min_per_km' or 'km_per_h'
  final double? value;
  final ValueChanged<double> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = unit == 'km_per_h'
        ? await _showSpeedPicker(context, value ?? 25)
        : await _showPacePicker(context, value ?? 6.0);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? '–'
        : unit == 'km_per_h'
            ? '${formatSpeed(value!)} km/h'
            : '${formatPace(value!)} /km';
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.speed_outlined),
        ),
        child: Text(text),
      ),
    );
  }
}

Future<double?> _showPacePicker(BuildContext context, double initial) {
  int minutes = initial.floor().clamp(2, 12);
  int seconds = (((initial - initial.floor()) * 60).round() ~/ 5 * 5).clamp(0, 55);

  return showModalBottomSheet<double>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: 280,
          child: Column(
            children: [
              _PickerSheetHeader(
                onDone: () => Navigator.of(context).pop(minutes + seconds / 60),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: minutes - 2),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) => minutes = i + 2,
                        children: [
                          for (var m = 2; m <= 12; m++)
                            Center(child: Text('$m min')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: seconds ~/ 5),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) => seconds = i * 5,
                        children: [
                          for (var s = 0; s <= 55; s += 5)
                            Center(child: Text('${s.toString().padLeft(2, '0')} sek')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<double?> _showSpeedPicker(BuildContext context, double initial) {
  int speed = initial.round().clamp(3, 60);

  return showModalBottomSheet<double>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: 280,
          child: Column(
            children: [
              _PickerSheetHeader(
                onDone: () => Navigator.of(context).pop(speed.toDouble()),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: speed - 3),
                  itemExtent: 40,
                  onSelectedItemChanged: (i) => speed = i + 3,
                  children: [
                    for (var s = 3; s <= 60; s++) Center(child: Text('$s km/h')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PickerSheetHeader extends StatelessWidget {
  const _PickerSheetHeader({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(onPressed: onDone, child: const Text('Fertig')),
      ],
    );
  }
}
