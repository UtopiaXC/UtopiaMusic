import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/pages/main/settings/widgets/settings_widgets.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/generated/l10n.dart';

class SearchSettingsPage extends StatelessWidget {
  final bool embedded;

  const SearchSettingsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return SettingsFragmentScaffold(
      title: S.of(context).pages_settings_tag_search,
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          SettingsGroup(
            title: S.of(context).weight_search_label_serach_history,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_search_local_history,
                ),
                value: settingsProvider.saveSearchHistory,
                onChanged: (bool value) {
                  settingsProvider.setSaveSearchHistory(value);
                },
              ),
              ListTile(
                title: Text(
                  S.of(context).pages_settings_tag_search_local_history_limit,
                ),
                subtitle: Text(
                  '${S.of(context).pages_settings_tag_search_local_history_limit_now}: ${settingsProvider.searchHistoryLimit}',
                ),
                enabled: settingsProvider.saveSearchHistory,
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () {
                  _showLimitDialog(context, settingsProvider);
                },
              ),
            ],
          ),
          SettingsGroup(
            title: S.of(context).pages_settings_tag_search_suggest,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_search_suggest_title,
                ),
                subtitle: Text(
                  S.of(context).pages_settings_tag_search_suggest_hint,
                ),
                value: settingsProvider.showSearchSuggest,
                onChanged: (bool value) {
                  settingsProvider.setShowSearchSuggest(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLimitDialog(BuildContext context, SettingsProvider provider) {
    final TextEditingController controller = TextEditingController(
      text: provider.searchHistoryLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            S.of(context).pages_settings_tag_search_local_history_limit,
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: S.of(context).common_limitation,
              hintText:
                  "${S.of(context).common_please_input}${S.of(context).common_int}",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).common_cancel),
            ),
            TextButton(
              onPressed: () {
                final int? limit = int.tryParse(controller.text);
                if (limit != null && limit > 0) {
                  provider.setSearchHistoryLimit(limit);
                  Navigator.pop(context);
                }
              },
              child: Text(S.of(context).common_confirm),
            ),
          ],
        );
      },
    );
  }
}
