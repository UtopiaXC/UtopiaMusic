import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/generated/l10n.dart';

import 'package:utopia_music/utils/log.dart';

const String _tag = "TIMER_DIALOG";

class TimerDialog extends StatefulWidget {
  const TimerDialog({super.key});

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _stopAfterCurrent = false;

  @override
  void initState() {
    Log.v(_tag, "initState");
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _tabController.dispose();
    super.dispose();
  }

  void _setTimer(int minutes) {
    Log.v(_tag, "_setTimer, minutes: $minutes");
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.setStopTimer(
      Duration(minutes: minutes),
      stopAfterCurrent: _stopAfterCurrent,
    );
    Navigator.pop(context);
  }

  void _showCustomTimerDialog() {
    Log.v(_tag, "_showCustomTimerDialog");
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).weight_player_timer_custom),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: S.of(context).time_minute,
            suffixText: 'min',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                _setTimer(minutes);
                Navigator.pop(context);
              }
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Log.v(_tag, "build");
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _stopAfterCurrent,
                onChanged: (value) {
                  setState(() {
                    _stopAfterCurrent = value ?? false;
                  });
                },
                title: Text(
                  S.of(context).weight_player_timer_stop_at_end_message,
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: S.of(context).weight_player_timer_discount_stop),
                  Tab(text: S.of(context).weight_player_timer_timestamp_stop),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildCountdownTab(), _buildSpecificTimeTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownTab() {
    Log.v(_tag, "_buildCountdownTab");
    return ListView(
      children: [
        ListTile(
          title: Text('15 ${S.of(context).time_minute}'),
          onTap: () => _setTimer(15),
        ),
        ListTile(
          title: Text('30 ${S.of(context).time_minute}'),
          onTap: () => _setTimer(30),
        ),
        ListTile(
          title: Text('60 ${S.of(context).time_minute}'),
          onTap: () => _setTimer(60),
        ),
        ListTile(
          title: Text('90 ${S.of(context).time_minute}'),
          onTap: () => _setTimer(90),
        ),
        ListTile(
          title: Text(S.of(context).common_custom),
          onTap: _showCustomTimerDialog,
        ),
      ],
    );
  }

  Widget _buildSpecificTimeTab() {
    Log.v(_tag, "_buildSpecificTimeTab");
    return Center(
      child: FilledButton(
        onPressed: () async {
          final now = TimeOfDay.now();
          final time = await showTimePicker(context: context, initialTime: now);
          if (time != null) {
            final nowDateTime = DateTime.now();
            var selectedDateTime = DateTime(
              nowDateTime.year,
              nowDateTime.month,
              nowDateTime.day,
              time.hour,
              time.minute,
            );
            if (selectedDateTime.isBefore(nowDateTime)) {
              selectedDateTime = selectedDateTime.add(const Duration(days: 1));
            }

            if (mounted) {
              final playerProvider = Provider.of<PlayerProvider>(
                context,
                listen: false,
              );
              playerProvider.setStopTime(
                selectedDateTime,
                stopAfterCurrent: _stopAfterCurrent,
              );
              Navigator.pop(context);
            }
          }
        },
        child: Text(S.of(context).weight_player_timer_select_time),
      ),
    );
  }
}
