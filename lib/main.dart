import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/data/services/excel_parser.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/presentation/map_screen.dart';

// AGENT NOTE: According to AGENTS.md, the following C++ code must be added
// to `windows/runner/main.cpp` before the `runLoop(window);` line for bitsdojo_window to work.
/*
#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);
*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Run the excel parser test
  print("--- Running Excel Parser Test ---");
  final excelParser = ExcelParser();
  await excelParser.parseDemoData();
  print("--- Excel Parser Test Finished ---");

  runApp(const ProviderScope(child: MyApp()));

  // Add this code below runApp()
  doWhenWindowReady(() {
    const initialSize = Size(1280, 720);
    appWindow.minSize = const Size(800, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vessel Track Visualizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: WindowBorder(
          color: Colors.grey.shade300,
          width: 1,
          child: const MapScreen(),
        ),
      ),
    );
  }
}