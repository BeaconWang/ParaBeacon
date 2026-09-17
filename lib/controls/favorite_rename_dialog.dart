import 'package:flutter/material.dart';

import '../data/weather_favorites.dart';
import '../l10n/app_localizations.dart';

/// Prompts for a new name for [place] and applies it to
/// [WeatherFavoritesStore].
///
/// Returns the stored name when the rename went through, or null when the
/// user cancelled or the entry no longer exists. The store sanitizes and
/// length-caps the input and refuses a blank name, so the saved entry can
/// never end up unnamed.
Future<String?> showFavoriteRenameDialog(
  BuildContext context,
  FavoritePlace place, {
  String? coordsLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: place.name);
  try {
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.weatherFavoriteRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: FavoritePlace.maxNameLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.weatherFavoriteName,
              helperText: coordsLabel,
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    if (input == null) return null;

    final store = WeatherFavoritesStore.instance;
    final ok = await store.rename(place.lat, place.lon, input);
    if (!ok) return null;
    final index = store.indexOfSpot(place.lat, place.lon);
    return index >= 0 ? store.places[index].name : null;
  } finally {
    controller.dispose();
  }
}
