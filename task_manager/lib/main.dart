import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'screens/task_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CameraService.instance.initialize();
  _setupSync();
  runApp(const MyApp());
}

void _setupSync() {
  ConnectivityService.instance.listenOnlineChanges((online) {
    if (online) {
      SyncService.instance.sync();
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.online$,
      initialData: true,
      builder: (context, snap) {
        final online = snap.data == true;
        return MaterialApp(
          title: 'Task Manager Pro',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            cardTheme: const CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: TaskListScreen()),
              ],
            ),
          ),
        );
      },
    );
  }
}
