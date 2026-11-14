import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/pages/main/settings/widgets/settings_widgets.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/generated/l10n.dart';

class NetworkSettingsPage extends StatelessWidget {
  final bool embedded;

  const NetworkSettingsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return SettingsFragmentScaffold(
      title: S.of(context).pages_settings_tag_network,
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          SettingsGroup(
            title: S.of(context).pages_settings_tag_network_interface_request,
            children: [
              ListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_network_interface_request_retry,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_network_interface_request_retry_description,
                ),
                trailing: DropdownButton<int>(
                  value: settingsProvider.maxRetries,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setMaxRetries(newValue);
                    }
                  },
                  items: [0, 1, 2, 3, 4, 5].map<DropdownMenuItem<int>>((
                    int value,
                  ) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                ),
              ),
              ListTile(
                title: Text(
                  S.of(context).pages_settings_tag_network_request_delay,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_network_request_delay_description,
                ),
                trailing: DropdownButton<int>(
                  value: settingsProvider.requestDelay,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setRequestDelay(newValue);
                    }
                  },
                  items: [0, 10, 50, 100, 200, 300, 400, 500]
                      .map<DropdownMenuItem<int>>((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value ms'),
                        );
                      })
                      .toList(),
                ),
              ),
            ],
          ),
          SettingsGroup(
            title: S.of(context).pages_settings_tag_network_play_history,
            children: [
              SwitchListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_network_play_history_location,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_network_play_history_location_description,
                ),
                value: settingsProvider.enableHistoryLocation,
                onChanged: (bool value) {
                  settingsProvider.setEnableHistoryLocation(value);
                },
              ),
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_network_play_history_report,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_network_play_history_report_description,
                ),
                value: settingsProvider.enableHistoryReport,
                onChanged: (bool value) {
                  settingsProvider.setEnableHistoryReport(value);
                },
              ),
              if (settingsProvider.enableHistoryReport)
                ListTile(
                  title: Text(
                    S
                        .of(context)
                        .pages_settings_tag_network_play_history_report_delay,
                  ),
                  subtitle: Text(
                    S
                        .of(context)
                        .pages_settings_tag_network_play_history_report_delay_description,
                  ),
                  trailing: DropdownButton<int>(
                    value: settingsProvider.historyReportDelay,
                    underline: const SizedBox(),
                    alignment: Alignment.centerRight,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        settingsProvider.setHistoryReportDelay(newValue);
                      }
                    },
                    items: [0, 1, 3, 5, 10].map<DropdownMenuItem<int>>((
                      int value,
                    ) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          value == 0
                              ? S.of(context).common_disable
                              : '$value ${S.of(context).time_second}',
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
