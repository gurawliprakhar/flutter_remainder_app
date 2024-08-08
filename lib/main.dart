import 'package:flutter/material.dart';
import 'package:flutter_task_remainder/ui/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToDo List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
            brightness: Brightness.light
      ),
      darkTheme: ThemeData(
          primaryColor: Colors.black,
          brightness: Brightness.dark
      ),
      home: HomePage()
    );
  }
}
