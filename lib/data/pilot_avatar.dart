import 'package:flutter/material.dart';

class PilotAvatar {
  PilotAvatar._();

  static const int defaultId = 0;
  static const int maxId = 7;

  static const List<IconData> icons = [
    Icons.paragliding,
    Icons.flight,
    Icons.airplanemode_active,
    Icons.landscape,
    Icons.terrain,
    Icons.wb_sunny_outlined,
    Icons.explore,
    Icons.person,
  ];

  static bool isValid(int id) => id >= 0 && id <= maxId;

  static IconData iconFor(int id) => isValid(id) ? icons[id] : icons[defaultId];
}
