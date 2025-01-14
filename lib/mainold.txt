import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _cookieCount = 0;
  int _clickValue = 1;
  int _upgradeCost = 10;
  List<String> _factories = [];
  Process? _serverProcess;
  Timer? _timer;
  bool _serverRunning = false;

  @override
  void initState() {
    super.initState();
    _startServer().then((_) {
      _getState();
      _timer = Timer.periodic(Duration(seconds: 1), (timer) => _getState());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopServer();
    super.dispose();
  }

  Future<void> _startServer() async {
    try {
      String serverScriptPath = await _getServerScriptPath();
      _serverProcess = await Process.start('python', [serverScriptPath]);
      _serverRunning = true;
      _serverProcess?.stdout.transform(utf8.decoder).listen((data) {
        print('Server stdout: $data');
      });
      _serverProcess?.stderr.transform(utf8.decoder).listen((data) {
        print('Server stderr: $data');
      });
      await Future.delayed(Duration(seconds: 2));
    } catch (e) {
      print('Failed to start server: $e');
    }
  }

  Future<void> _stopServer() async {
    _serverProcess?.kill();
    _serverRunning = false;
  }

  Future<String> _getServerScriptPath() async {
    final appDir = Directory.current;
    return path.join(appDir.path, 'app.py');
  }

  Future<void> _getState() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/state'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        setState(() {
          _cookieCount = state['cookie_count'];
          _clickValue = state['click_value'];
          _upgradeCost = state['upgrade_cost'];
          _factories = List<String>.from(
              state['factories'].map((factory) => factory['production_rate'] == 1 ? 'Basic' : 'Advanced'));
        });
      }
    } catch (e) {
      print('Failed to fetch state: $e');
    }
  }

  Future<void> _click() async {
    try {
      final response = await http.post(Uri.parse('http://127.0.0.1:8000/click'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        setState(() {
          _cookieCount = state['cookie_count'];
        });
      }
    } catch (e) {
      print('Failed to send click: $e');
    }
  }

  Future<void> _upgrade() async {
    try {
      final response = await http.post(Uri.parse('http://127.0.0.1:8000/upgrade'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        setState(() {
          _cookieCount = state['cookie_count'];
          _clickValue = state['click_value'];
          _upgradeCost = state['upgrade_cost'];
        });
      }
    } catch (e) {
      print('Failed to upgrade: $e');
    }
  }

  Future<void> _buyBasicFactory() async {
    try {
      final response = await http.post(Uri.parse('http://127.0.0.1:8000/buy_basic_factory'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        setState(() {
          _cookieCount = state['cookie_count'];
          _factories.add('Basic');
        });
      }
    } catch (e) {
      print('Failed to buy basic factory: $e');
    }
  }

  Future<void> _buyAdvancedFactory() async {
    try {
      final response = await http.post(Uri.parse('http://127.0.0.1:8000/buy_advanced_factory'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        setState(() {
          _cookieCount = state['cookie_count'];
          _factories.add('Advanced');
        });
      }
    } catch (e) {
      print('Failed to buy advanced factory: $e');
    }
  }

  Future<void> _resetGame() async {
    try {
      final response = await http.post(Uri.parse('http://127.0.0.1:8000/reset_game'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        setState(() {
          _cookieCount = state['cookie_count'];
          _clickValue = state['click_value'];
          _upgradeCost = state['upgrade_cost'];
          _factories = List<String>.from(
              state['factories'].map((factory) => factory['production_rate'] == 1 ? 'Basic' : 'Advanced'));
        });
      }
    } catch (e) {
      print('Failed to reset game: $e');
    }
  }

  Future<void> _resetServer() async {
    await _stopServer();
    await _startServer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Cookie Clicker'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Server is ${_serverRunning ? 'running' : 'not running'}'),
              Text('Cookies: $_cookieCount'),
              Text('Factories: ${_factories.join(', ')}'),
              ElevatedButton(
                onPressed: _click,
                child: Text('Click!'),
              ),
              ElevatedButton(
                onPressed: _upgrade,
                child: Text('Upgrade (Cost: $_upgradeCost)'),
              ),
              ElevatedButton(
                onPressed: _buyBasicFactory,
                child: Text('Buy Basic Factory (Cost: 10)'),
              ),
              ElevatedButton(
                onPressed: _buyAdvancedFactory,
                child: Text('Buy Advanced Factory (Cost: 20)'),
              ),
              ElevatedButton(
                onPressed: _resetGame,
                child: Text('Reset Game'),
              ),
              ElevatedButton(
                onPressed: _resetServer,
                child: Text('Reset Server'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
