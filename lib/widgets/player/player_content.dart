import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';

class PlayerContent extends StatelessWidget {
  final Song song;

  const PlayerContent({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return PageView(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                image: DecorationImage(
                  image: NetworkImage(song.coverUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Text(
                song.lyrics,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.8,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
