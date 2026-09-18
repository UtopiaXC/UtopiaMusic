import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color?> onChanged;
  final bool showResetBtn;

  const SlideColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.showResetBtn = false,
  });

  @override
  State<SlideColorPicker> createState() => _SlideColorPickerState();
}

class _SlideColorPickerState extends State<SlideColorPicker> {
  late int _rgb;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _rgb = widget.color.toARGB32() & 0xFFFFFF;
    _textController = TextEditingController(text: _convert);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String get _convert => _rgb.toRadixString(16).toUpperCase().padLeft(6, '0');

  Color get _currentColor => Color(0xFF000000 | _rgb);

  Widget _slider({
    required String title,
    required int value,
    required ValueChanged<double> onChanged,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 20,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: activeColor,
                thumbColor: activeColor,
              ),
              child: Slider(
                padding: EdgeInsets.zero,
                min: 0,
                max: 255,
                divisions: 255,
                value: value.toDouble(),
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              value.toString(),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: 140,
              child: TextField(
                inputFormatters: [
                  LengthLimitingTextInputFormatter(6),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                ],
                controller: _textController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixText: '# ',
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    final parsed = int.tryParse(value, radix: 16);
                    if (parsed != null) {
                      setState(() {
                        _rgb = parsed;
                      });
                    }
                  }
                },
              ),
            ),
          ),
          _slider(
            title: 'R',
            value: (_rgb >> 16) & 0xFF,
            activeColor: Colors.redAccent,
            onChanged: (value) {
              setState(() {
                _rgb = (_rgb & 0x00FFFF) | (value.round() << 16);
                _textController.text = _convert;
              });
            },
          ),
          _slider(
            title: 'G',
            value: (_rgb >> 8) & 0xFF,
            activeColor: Colors.greenAccent,
            onChanged: (value) {
              setState(() {
                _rgb = (_rgb & 0xFF00FF) | (value.round() << 8);
                _textController.text = _convert;
              });
            },
          ),
          _slider(
            title: 'B',
            value: _rgb & 0xFF,
            activeColor: Colors.blueAccent,
            onChanged: (value) {
              setState(() {
                _rgb = (_rgb & 0xFFFF00) | value.round();
                _textController.text = _convert;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.showResetBtn) ...[
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onChanged(null);
                  },
                  child: const Text('重置'),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onChanged(_currentColor);
                },
                child: const Text('确定'),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }
}
