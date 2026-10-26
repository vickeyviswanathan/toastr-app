import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'screens/main_home_screen.dart';
import 'theme/toastr_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToastrCloneApp());
}

class ToastrCloneApp extends StatelessWidget {
  const ToastrCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider()..initialize(),
      child: MaterialApp(
        title: 'Toastr - Compare Food & Groceries',
        debugShowCheckedModeBanner: false,
        theme: ToastrTheme.darkTheme,
        home: const MainHomeScreen(),
      ),
    );
  }
}
