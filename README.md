# smatcityproject

#modesandthemes
#settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart'; // Ensure this file exists

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Color selectedColor = Colors.blue;
  String selectedFont = 'Roboto';

  final List<Color> colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange
  ];

  final List<String> fonts = [
    'Roboto',
    'Arial',
    'Courier New',
    'Georgia',
    'Times New Roman'
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

         return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark Mode Toggle
            ListTile(
              title: Text('Toggle Dark Mode'),
              trailing: Switch(
                value: themeProvider.themeData.brightness == Brightness.dark,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ),

            // Color Selection
            Text('Select Primary Color'),
            DropdownButton<Color>(
              value: selectedColor,
              items: colors.map((color) {
                return DropdownMenuItem(
                  value: color,
                  child: Container(
                    width: 100,
                    height: 20,
                    color: color,
                  ),
                );
              }).toList(),
              onChanged: (Color? newColor) {
                if (newColor != null) {
                  setState(() {
                    selectedColor = newColor;
                  });
                }
              },
            ),

            SizedBox(height: 20),

            // Font Selection
            Text('Select Font'),
            DropdownButton<String>(
              value: selectedFont,
              items: fonts.map((font) {
                return DropdownMenuItem(
                  value: font,
                  child: Text(font, style: TextStyle(fontFamily: font)),
                );
              }).toList(),
              onChanged: (String? newFont) {
                if (newFont != null) {
                  setState(() {
                    selectedFont = newFont;
                  });
                }
              },
            ),

            SizedBox(height: 20),

            // Apply Theme Button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  themeProvider.applyCustomTheme(selectedColor, selectedFont);
                },
                child: Text('Apply Theme'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


#themeprovider.dart in lib

import 'package:flutter/material.dart';
import 'theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = AppThemes.lightTheme;

  ThemeData get themeData => _themeData;

  void toggleTheme() {
    if (_themeData.brightness == Brightness.dark) {
      _themeData = AppThemes.lightTheme;
    } else {
      _themeData = AppThemes.darkTheme;
    }
    notifyListeners();
  }

  void applyCustomTheme(Color primaryColor, String fontFamily) {
    _themeData = AppThemes.customTheme(primaryColor, fontFamily);
    notifyListeners();
  }
}

#modify theme.dart

import 'package:flutter/material.dart';

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    fontFamily: 'Roboto',
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.teal,
    fontFamily: 'Roboto',
  );

  static ThemeData customTheme(Color primaryColor, String fontFamily) {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.light(primary: primaryColor),
    );
  }
}

#ensuring theme.dart is in main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      theme: themeProvider.themeData,
      home: SettingsScreen(), // Your main settings screen
    );
  }
}


