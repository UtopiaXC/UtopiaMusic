import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';
import 'dart:math';
import 'package:utopia_music/utils/log.dart';

const String _tag = "PLAYER_CONTENT";

class PlayerContent extends StatelessWidget {
  final Song song;

  const PlayerContent({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    Log.v(_tag, "build");
    return LayoutBuilder(
      builder: (context, constraints) {
        double imageSize = min(300.0, constraints.maxHeight - 60);

        if (imageSize < 0) imageSize = 0;

        final String optimizedCover =
            song.coverUrl.isNotEmpty ? '${song.coverUrl}@600w_600h.webp' : '';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                image: song.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(optimizedCover),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {},
                      )
                    : null,
              ),
              child: song.coverUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: imageSize * 0.5,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
