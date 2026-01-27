import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "QUALITY_DIALOG";


class QualityDialog extends StatefulWidget {
  final Song song;

  const QualityDialog({super.key, required this.song});

  @override
  State<QualityDialog> createState() => _QualityDialogState();
}

class _QualityDialogState extends State<QualityDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AudioStreamInfo? _streamInfo;
  final AudioStreamApi _audioApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    Log.v(_tag, "initState");
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStreamInfo();
  }

  Future<void> _loadStreamInfo() async {
    Log.v(_tag, "_loadStreamInfo");
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      int cid = widget.song.cid;
      if (cid == 0) {
        cid = await _searchApi.fetchCid(widget.song.bvid);
        if (cid == 0) throw Exception("No CID fetched");
      }

      final info = await _audioApi.getAudioStream(widget.song.bvid, cid);

      if (mounted) {
        setState(() {
          _streamInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _tabController.dispose();
    super.dispose();
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
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: S.of(context).weight_player_audio_quilty_default),
                  Tab(text: S.of(context).weight_player_audio_quilty_for_this),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDefaultQualityTab(),
                    _buildAvailableQualityTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultQualityTab() {
    Log.v(_tag, "_buildDefaultQualityTab");
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final qualities = QualityUtils.supportQualities;

    return ListView.builder(
      itemCount: qualities.length,
      itemBuilder: (context, index) {
        final quality = qualities[index];
        final isSelected = settingsProvider.defaultAudioQuality == quality;
        return ListTile(
          title: Text(QualityUtils.getQualityLabel(context, quality, detailed: true)),
          trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
          onTap: () {
            settingsProvider.setDefaultAudioQuality(quality);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildAvailableQualityTab() {
    Log.v(_tag, "_buildAvailableQualityTab");
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            Text(S.of(context).common_failed),
            TextButton(
              onPressed: _loadStreamInfo,
              child: Text(S.of(context).common_retry),
            ),
          ],
        ),
      );
    }

    if (_streamInfo == null || _streamInfo!.availableQualities.isEmpty) {
      return Center(
        child: Text(S.of(context).weight_player_audio_quilty_no_available),
      );
    }
    final available = _streamInfo!.availableQualities;
    final current = context.select<PlayerProvider, int>((p) => p.currentPlayingQuality);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            S.of(context).weight_player_audio_quilty_for_this_message,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (context, index) {
              final quality = available[index];
              final isCurrent = quality == current;

              return ListTile(
                title: Text(QualityUtils.getQualityLabel(context, quality, detailed: true)),
                subtitle: isCurrent
                    ? Text(
                  S.of(context).weight_player_audio_quilty_for_this_using,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                )
                    : null,
                trailing: isCurrent
                    ? Icon(Icons.volume_up, color: Theme.of(context).colorScheme.primary)
                    : null,
                enabled: false,
              );
            },
          ),
        ),
      ],
    );
  }
}