import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class CustomTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: Row(
        children: [
          Expanded(
            child: MoveWindow(
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'Vessel Track Visualizer',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          MinimizeWindowButton(),
          MaximizeWindowButton(),
          CloseWindowButton(),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(32);
}
