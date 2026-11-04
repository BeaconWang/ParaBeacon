import 'package:flutter/material.dart';

class SheetNoticeHost extends StatelessWidget {
  const SheetNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(backgroundColor: Colors.transparent, body: child),
    );
  }
}
