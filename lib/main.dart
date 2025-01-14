import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'dart:async';

extension ListAddIf<T> on List<T> {
  void addIf(bool condition, T value) {
    if (condition) {
      add(value);
    }
  }
}

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _cookieCount = 0;
  int _upgradeCost = 10;
  int _basicFactoryCost = 10;    // Add this
  int _advancedFactoryCost = 20; // Add this
  int _clickValue = 1;           // Add this
  List<String> _factories = [];
  Map<String, int> _upgrades = {};
  Process? _serverProcess;
  bool _serverRunning = false, _isHovered = false;
  late AnimationController _animationController;
  late Animation<Offset> _animation;
  Timer? _timer; // Add a timer
  String _errorMessage = ''; // Add an error message

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServer();
    _setupAnimation();

    // Start the timer to periodically fetch the state
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _getState();
    });
  }

  @override
  void dispose() async {
    // Cancel timer first to stop state updates
    _timer?.cancel();
    
    // Stop the server with proper error handling
    await _shutdownServer();

    // Clean up animation controller
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _shutdownServer();
    }
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.05),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServer() async {
    await _startServer();
    _getState();
  }

  Future<void> _startServer() async {
    try {
      String serverScriptPath = await _getServerScriptPath();
      _serverProcess = await Process.start('python', [serverScriptPath]);
      _serverRunning = true;
      print('Server started successfully.');
    } catch (e) {
      print('Failed to start server: $e');
      setState(() {
        _errorMessage = 'Failed to start server: $e';
      });
    }
  }

  Future<void> _stopServer() async {
    try {
      _serverProcess?.kill();
      print('Server process killed.');
    } catch (e) {
      print('Failed to kill server process: $e');
    }
  }

  Future<String> _getServerScriptPath() async {
    return path.join(Directory.current.path, 'app.py');
  }

  Future<void> _getState() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/state'));
      if (response.statusCode == 200) {
        final state = jsonDecode(response.body);
        if (state is Map<String, dynamic>) {
          setState(() {
            _cookieCount = state['cookie_count'] ?? 0;
            _clickValue = state['click_value'] ?? 1;
            _upgradeCost = state['upgrade_cost'] ?? 10;
            _basicFactoryCost = state['basic_factory_cost'] ?? 10;
            _advancedFactoryCost = state['advanced_factory_cost'] ?? 20;
            _factories = List<String>.from(
                state['factories']?.map((factory) => factory['production_rate'] == 1 ? 'Basic' : 'Advanced') ?? []);
            _upgrades = Map<String, int>.from(state['upgrades'] ?? {});
            _errorMessage = ''; // Clear error message on success
          });
        } else {
          print('Invalid state format: $state');
          setState(() {
            _errorMessage = 'Invalid state format: $state';
          });
        }
      } else {
        print('Failed to fetch state: ${response.statusCode}');
        setState(() {
          _errorMessage = 'Failed to fetch state: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Failed to fetch state: $e');
      setState(() {
        _errorMessage = 'Failed to fetch state: $e';
      });
    }
  }

  Future<void> _click() async {
    await _sendPostRequest('click');
  }

  Future<void> _upgrade() async {
    await _sendPostRequest('upgrade');
  }

  Future<void> _buyFactory(String type) async {
    await _sendPostRequest('buy_${type.toLowerCase()}_factory');
  }

  Future<void> _resetGame() async {
    await _sendPostRequest('reset_game');
  }

  Future<void> _saveGame(int slot) async {
    await _sendPostRequest('save_game', {'slot': slot.toString()});
  }

  Future<void> _loadGame(int slot) async {
    await _sendPostRequest('load_game', {'slot': slot.toString()});
  }

  Future<void> _deleteGame(int slot) async {
    await _sendPostRequest('delete_game', {'slot': slot.toString()});
  }

  Future<void> _sendPostRequest(String endpoint, [Map<String, String>? params]) async {
    try {
      final uri = Uri.http('127.0.0.1:8000', endpoint, params);
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        _getState();
      } else {
        print('Failed to send request: ${response.statusCode}');
        setState(() {
          _errorMessage = 'Failed to send request: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Request failed: $e');
      setState(() {
        _errorMessage = 'Request failed: $e';
      });
    }
  }

  void _showDeleteConfirmationDialog(int slot) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Save Slot $slot'),
          content: const Text('Are you sure you want to delete this save slot?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteGame(slot);
                Navigator.of(context).pop();
              },
              child: const Text('I\'m Sure'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaveSlot(int slot) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Save Slot $slot'),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _saveGame(slot),
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _loadGame(slot),
              child: const Text('Load'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _showDeleteConfirmationDialog(slot),
              child: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }

  void _showSaveLoadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save/Load Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSaveSlot(1),
              const SizedBox(height: 8),
              _buildSaveSlot(2),
              const SizedBox(height: 8),
              _buildSaveSlot(3),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> actions) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...actions,
      ],
    );
  }

  Widget _buildFactoryDisplay() => _buildSection(
        'Your Factories',
        ['Basic', 'Advanced'].map(_buildFactoryTypeDisplay).toList(),
      );

  Widget _buildFactoryTypeDisplay(String factoryType) {
    int count = _factories.where((f) => f == factoryType).length;
    return Column(
      children: [
        Text('$factoryType Factories', style: const TextStyle(fontSize: 16)),
        Wrap(
          spacing: 10,
          children: List.generate(
            count.clamp(0, 10),
            (_) => Image.asset('assets/${factoryType.toLowerCase()}_factory.png', width: 50, height: 50),
          )..addAll([if (count > 10) Text('x$count')]),
        ),
      ],
    );
  }

  Widget _buildUpgradeCount() {
    int totalUpgrades = _upgrades.values.fold(0, (sum, count) => sum + count);
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          'x$totalUpgrades',
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookie Clicker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _showSaveLoadDialog,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              await _startServer(); // Use direct process start instead of HTTP request
              await Future.delayed(const Duration(seconds: 2)); // Wait for server to initialize
              await _getState(); // Get initial state
            },
            tooltip: 'Start Server',
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),  // Shutdown icon
            onPressed: () async {
              await _shutdownServer();
              setState(() {
                _serverRunning = false;
              });
            },
            tooltip: 'Shutdown Server',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cookie on the left, taking 1/3 of the window
            Expanded(
              flex: 1,
              child: Center(
                child: MouseRegion(
                  onEnter: (_) {
                    setState(() => _isHovered = true);
                    _getState();
                  },
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    onTap: _click,
                    child: SlideTransition(
                      position: _animation,
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isHovered ? 400 : 350,
                            height: _isHovered ? 400 : 350,
                            child: Image.asset('assets/cookie.png'),
                          ),
                          _buildUpgradeCount(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Other elements on the right, taking 2/3 of the window
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Server is ${_serverRunning ? 'running' : 'not running'}', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 20),
                    Text('Cookies: $_cookieCount', style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 20),
                    if (_errorMessage.isNotEmpty)
                      Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                    _buildSection('Upgrades', [
                      ElevatedButton.icon(
                        onPressed: _upgrade,
                        icon: const Icon(Icons.upgrade),
                        label: Text('Upgrade (Cost: $_upgradeCost)'),
                      )
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('Factories', [
                      ElevatedButton.icon(onPressed: () => _buyFactory('Basic'), icon: const Icon(Icons.factory), label: Text('Buy Basic Factory (Cost: $_basicFactoryCost)')),
                      ElevatedButton.icon(onPressed: () => _buyFactory('Advanced'), icon: const Icon(Icons.factory), label: Text('Buy Advanced Factory (Cost: $_advancedFactoryCost)'))
                    ]),
                    const SizedBox(height: 20),
                    _buildFactoryDisplay(),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(onPressed: _resetGame, icon: const Icon(Icons.refresh), label: const Text('Reset Game')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add a new method to handle clean shutdown
  Future<void> _shutdownServer() async {
    try {
      if (_serverRunning) {
        print('Attempting to shut down server...');
        final response = await http.post(Uri.parse('http://127.0.0.1:8000/shutdown'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          print('Server shutdown request successful.');
        } else {
          print('Failed to shut down server: ${response.statusCode}');
        }
        _serverProcess?.kill();
          print('Server process killed.');
        _serverRunning = false;
      }
    } catch (e) {
      print('Error during server shutdown: $e');
    }
  }
}