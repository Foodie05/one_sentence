import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:single_sentence/root_page.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  Directory docPath=await getApplicationDocumentsDirectory();
  Hive.init(docPath.path);
  await Hive.openBox('profile');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Xwwk',
      ),
      home: RootPage(),
    );
  }
}
