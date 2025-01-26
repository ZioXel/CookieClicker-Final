import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'blurred_background.dart';

extension ListAddIf<T> on List<T> {
  void addIf(bool condition, T value) {
    if (condition) {
      add(value);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _startServer();
  runApp(MaterialApp(
    theme: ThemeData(
      primarySwatch: Colors.brown,
      scaffoldBackgroundColor: const Color(0xFFFFF3E0), // Light cookie color
      appBarTheme: const AppBarTheme(
        color: Color(0xFF6D4C41), // Darker brown for app bar
        iconTheme: IconThemeData(color: Colors.white), // Ensure icons are white
        titleTextStyle: TextStyle(
          color: Colors.white, // Ensure the title text is white
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF8D6E63), // Medium brown for buttons
          foregroundColor: Colors.white, // Ensure the button text is white
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Arial', // Change font to 'Arial'
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF3E2723), fontFamily: 'Cookie'), // Dark brown text
        bodyMedium: TextStyle(color: Color(0xFF3E2723), fontFamily: 'Cookie'), // Dark brown text
        titleLarge: TextStyle(color: Color(0xFF3E2723), fontFamily: 'Cookie'), // Dark brown text
      ),
    ),
    home: const MainMenu(),
  ));
}

Future<void> _startServer() async {
  try {
    String serverScriptPath = await _getServerScriptPath();
    await Process.start(
      'cmd',
      ['/c', 'start', 'python', serverScriptPath],
      runInShell: true,
    );
    print('Server started successfully.');
  } catch (e) {
    print('Failed to start server: $e');
  }
}

Future<String> _getServerScriptPath() async {
  return path.join(Directory.current.path, 'app.py');
}

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
      ),
      body: BlurredBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                },
                child: const Text('New Game'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoadDeleteMenu()),
                  );
                },
                child: const Text('Load Game'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OptionsScreen()),
                  );
                },
                child: const Text('Options'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _sendPostRequest(String endpoint, [Map<String, String>? params]) async {
  try {
    final uri = Uri.http('127.0.0.1:8000', endpoint, params);
    final response = await http.post(uri);
    if (response.statusCode != 200) {
      print('Failed to send request: ${response.statusCode}');
    }
  } catch (e) {
    print('Request failed: $e');
  }
}

class MyApp extends StatefulWidget {
  final int? slot;

  const MyApp({super.key, this.slot});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Change int to double for numeric values that can be decimal
  double _cookieCount = 0;
  double _clickValue = 1;
  double _totalProductionRate = 0;
  double _upgradeCost = 10.0;
  double _prestigeThreshold = 1000.0; // Add prestige threshold
  int _prestigePoints = 0; // Add prestige points
  double _totalCookiesProduced = 0.0; // Add total cookies produced
  List<String> _factories = [];
  Process? _serverProcess;
  bool _serverRunning = false, _isHovered = false;
  late AnimationController _animationController;
  late Animation<Offset> _animation;
  Timer? _timer;

  // Update factory costs to double
  Map<String, double> _factoryCosts = {
    'grandma': 5.0,
    'nursing_home': 8.0,
    'garage': 13.0,
    'simple': 21.0,
    'basic': 34.0,
    'advanced': 55.0,
    'industrial': 89.0,
    'printing': 144.0,
    'ultra_grandma': 233.0,
    'cookie_god': 377.0,
  };

  // 1. Add factory icon mapping
  Map<String, IconData> _factoryIcons = {
    'grandma': Icons.elderly,
    'nursing_home': Icons.local_hospital,
    'garage': Icons.garage,
    'simple': Icons.factory,
    'basic': Icons.business,
    'advanced': Icons.precision_manufacturing,
    'industrial': Icons.factory,
    'printing': Icons.print,
    'ultra_grandma': Icons.elderly_woman,
    'cookie_god': Icons.whatshot,
  };

  // Add factory counts
  Map<String, int> _factoryCounts = {};

  bool _isClicking = false;
  bool _isHovering = false;
  bool _isHoveringCookie = false;
  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimation();

    // Start the timer to periodically fetch the state
    _startStateFetchingTimer();

    // Load the game state if a slot is provided
    if (widget.slot != null) {
      _loadGame(widget.slot!);
    }
  }

  @override
  void dispose() async {
    _timer?.cancel();
    await _shutdownServer();
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

  Future<void> _stopServer() async {
    try {
      _serverProcess?.kill();
      print('Server process killed.');
    } catch (e) {
      print('Failed to kill server process: $e');
    }
  }

  // Update the getState method to properly parse factory data and counts
  Future<void> _getState() async {
  try {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/state')
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final state = jsonDecode(response.body);
      if (state is Map<String, dynamic>) {
        setState(() {
          _cookieCount = (state['cookie_count'] as num?)?.toDouble() ?? 0.0;
          _clickValue = (state['click_value'] as num?)?.toDouble() ?? 1.0;
          _totalProductionRate = (state['total_production_rate'] as num?)?.toDouble() ?? 0.0;
          _upgradeCost = (state['upgrade_cost'] as num?)?.toDouble() ?? 10.0;
          _prestigePoints = (state['prestige_points'] as num?)?.toInt() ?? 0;  // Parse prestige points
          _totalCookiesProduced = (state['total_cookies_produced'] as num?)?.toDouble() ?? 0.0;  // Parse total cookies produced
          _prestigeThreshold = (state['prestige_threshold'] as num?)?.toDouble() ?? 3000.0;  // Parse prestige threshold
          
          // Update factories list with null safety
          if (state['factories'] is List) {
            _factories = (state['factories'] as List)
              .where((factory) => factory != null && factory['type'] != null)
              .map((factory) => factory['type'].toString())
              .toList();
          }
          
          // Update factory costs with null safety
          if (state['factory_costs'] is Map) {
            _factoryCosts = Map<String, double>.from(
              (state['factory_costs'] as Map).map((key, value) => 
                MapEntry(key?.toString() ?? '', (value as num?)?.toDouble() ?? 0.0)
              )
            );
          }

          // Update factory counts
          if (state['factory_counts'] is Map) {
            _factoryCounts = Map<String, int>.from(
              (state['factory_counts'] as Map).map((key, value) => 
                MapEntry(key?.toString() ?? '', (value as num?)?.toInt() ?? 0)
              )
            );
          }
        });
      }
    }
  } catch (e) {
    print('Failed to fetch state: $e');
  }
}

  Future<void> _click() async {
    await _sendPostRequest('click');
    await _getState(); // Refresh the state after clicking
  }

  Future<void> _upgrade() async {
    await _sendPostRequest('upgrade');
    await _getState(); // Refresh the state after upgrading
  }

  Future<void> _buyFactory(String type) async {
    try {
        await _sendPostRequest('buy_factory/$type');
        await _getState();
    } catch (e) {
    }
}

  Future<void> _resetGame() async {
    await _sendPostRequest('reset_game');
    await _getState(); // Refresh the state after resetting the game
  }

  Future<void> _saveGame(int slot) async {
    await _sendPostRequest('save_game', {
      'slot': slot.toString(),
    });
    await _getState(); // Refresh the state after saving the game
  }

  Future<void> _loadGame(int slot) async {
    await _sendPostRequest('load_game', {'slot': slot.toString()});
    await _getState(); // Refresh the state after loading the game
  }

  Future<void> _deleteGame(int slot) async {
    await _sendPostRequest('delete_game', {'slot': slot.toString()});
    await _getState(); // Refresh the state after deleting the game
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
        });
      }
    } catch (e) {
      print('Request failed: $e');
      setState(() {
      });
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, int slot) {
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

  Widget _buildSaveSlot(BuildContext context, int slot, {bool showSaveButton = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Save Slot $slot'),
        Row(
          children: [
            if (showSaveButton)
              ElevatedButton(
                onPressed: () => _saveGame(slot),
                child: const Text('Save'),
              ),
            if (showSaveButton) const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _loadGame(slot),
              child: const Text('Load'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _showDeleteConfirmationDialog(context, slot),
              child: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }

  void _showSaveLoadDialog(BuildContext context, {bool showSaveButton = true}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save/Load Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSaveSlot(context, 1, showSaveButton: showSaveButton),
              const SizedBox(height: 8),
              _buildSaveSlot(context, 2, showSaveButton: showSaveButton),
              const SizedBox(height: 8),
              _buildSaveSlot(context, 3, showSaveButton: showSaveButton),
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

  Widget _buildTotalCookiesProduced() {
  return Text(
    'Total Cookies Produced: ${_totalCookiesProduced.toStringAsFixed(2)}',
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)), // Dark brown text
  );
}

Widget _buildTotalProductionRate() {
  return Text(
    'Production Rate: ${_totalProductionRate.toStringAsFixed(2)} cookies/second',
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)), // Dark brown text
  );
}

  Widget _buildUpgradeCount() {
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
          'x$_clickValue',
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFactorySection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, // Changed to stretch
    children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.brown.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center( // Center the text
          child: Text(
            'Factories',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _buildFactoryTypeCard('grandma', 'Grandma'),
                  _buildFactoryTypeCard('nursing_home', 'Nursing Home'),
                  _buildFactoryTypeCard('garage', 'Garage'),
                  _buildFactoryTypeCard('simple', 'Simple Factory'),
                  _buildFactoryTypeCard('basic', 'Basic Factory'),
                  _buildFactoryTypeCard('advanced', 'Advanced Factory'),
                  _buildFactoryTypeCard('industrial', 'Industrial Plant'),
                  _buildFactoryTypeCard('printing', 'Printing Farm'),
                  _buildFactoryTypeCard('ultra_grandma', 'Ultra Grandma'),
                  _buildFactoryTypeCard('cookie_god', 'Cookie God'),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

  // Update factory card to show factory icons, count, and production rate
  Widget _buildFactoryTypeCard(String type, String name) {
    final cost = _factoryCosts[type] ?? 0;
    final count = _factoryCounts[type] ?? 0;
    final productionRate = _getProductionRate(type);
    final totalProduction = productionRate * count;
    
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: ElevatedButton(
              onPressed: () => _buyFactory(type),
              child: const Text('Buy'),
            ),
            title: Row(
              children: [
                Text(name),
                const SizedBox(width: 8),
                if (count > 0) 
                  Wrap(
                    spacing: 4,
                    children: [
                      ...List.generate(
                        min(count, 10),
                        (_) => Icon(_factoryIcons[type] ?? Icons.help, size: 20),
                      ),
                      if (count > 10) 
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            subtitle: Text('Cost: ${cost.toStringAsFixed(2)} cookies'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Production: ${totalProduction.toStringAsFixed(2)} cookies/second',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
}

  // Helper method to get production rate for factory type
  double _getProductionRate(String type) {
    final rates = {
      'grandma': 0.5,
      'nursing_home': 0.8,
      'garage': 1.0,
      'simple': 1.5,
      'basic': 2.0,
      'advanced': 3.0,
      'industrial': 5.0,
      'printing': 8.0,
      'ultra_grandma': 12.0,
      'cookie_god': 20.0,
    };
    return rates[type] ?? 0.0;
  }

  Widget _buildUpgradeSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, // Changed to stretch
    children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.brown.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center( // Center the text
          child: Text(
            'Upgrades',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: _upgrade,
                                child: const Text('Buy'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF8D6E63), // Medium brown for buttons
                                  textStyle: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Click Upgrade',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            'Cost: ${_upgradeCost.toStringAsFixed(2)} cookies',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Current: $_clickValue per click',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Prestige Level:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_prestigePoints',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text(
                                'Cookies Needed for Prestige:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_prestigeThreshold.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _cookieCount >= _prestigeThreshold ? _prestige : null,
                            child: const Text('Prestige'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Cookie Clicker'),
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: () => _showSaveLoadDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OptionsScreen()),
            );
          },
        ),
      ],
    ),
    body: BlurredBackground(
      blurIntensity: 5.0, // Very slight blur for main background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side with cookie and stats
            Flexible(
              flex: 1,
              child: Column(
                children: [
                  Center(
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
                  const SizedBox(height: 20),
                  _buildTotalCookiesProduced(),
                  const SizedBox(height: 10),
                  Text('Cookies: ${_cookieCount.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 24)
                  ),
                  const SizedBox(height: 10),
                  _buildTotalProductionRate(),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right side with factories and upgrades
            Flexible(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    flex: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildUpgradeSection(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildFactorySection(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // Add a new method to handle prestige
  Future<void> _prestige() async {
    setState(() {
      _prestigePoints++;
      _cookieCount = 0;
      _clickValue = 1;
      _totalProductionRate = 0;
      _upgradeCost = 10.0;
      _factories.clear();
      _factoryCounts.clear();
      _totalCookiesProduced = 0;
    });
    await _sendPostRequest('prestige');
    await _getState(); // Refresh the state after prestiging
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

  // Add a new method to start the state fetching timer
  void _startStateFetchingTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _getState();
    });
  }

  // Add a new method to restart the state fetching timer
  void _restartStateFetchingTimer() {
    _timer?.cancel();
    _startStateFetchingTimer();
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookie Clicker'),
      ),
      body: const Center(
        child: Text('Game Screen'),
      ),
    );
  }
}

class LoadGameScreen extends StatefulWidget {
  const LoadGameScreen({Key? key}) : super(key: key);

  @override
  _LoadGameScreenState createState() => _LoadGameScreenState();
}

class _LoadGameScreenState extends State<LoadGameScreen> {
  List<int> _saveSlots = [];

  @override
  void initState() {
    super.initState();
    _fetchSaveSlots();
  }

  Future<void> _fetchSaveSlots() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/saves'));
      if (response.statusCode == 200) {
        final saves = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _saveSlots = saves.map((save) => save as int).toList();
        });
      } else {
        print('Failed to fetch save slots: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to fetch save slots: $e');
    }
  }

  Future<void> _loadGame(int slot) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyApp(slot: slot)),
    ).then((_) async {
      await _sendPostRequest('load_game', {'slot': slot.toString()});
    });
  }

  Future<void> _sendPostRequest(String endpoint, [Map<String, String>? params]) async {
    try {
      final uri = Uri.http('127.0.0.1:8000', endpoint, params);
      final response = await http.post(uri);
      if (response.statusCode != 200) {
        print('Failed to send request: ${response.statusCode}');
      }
    } catch (e) {
      print('Request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Load Game'),
      ),
      body: ListView.builder(
        itemCount: _saveSlots.length,
        itemBuilder: (context, index) {
          final slot = _saveSlots[index];
          return ListTile(
            title: Text('Save Slot $slot'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _loadGame(slot),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Sound Volume'),
            Slider(
              value: 0.5,
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }
}

class LoadDeleteMenu extends StatelessWidget {
  const LoadDeleteMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Load/Delete Game'),
      ),
      body: BlurredBackground(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildSaveSlot(context, 1),
                const SizedBox(height: 8),
                _buildSaveSlot(context, 2),
                const SizedBox(height: 8),
                _buildSaveSlot(context, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveSlot(BuildContext context, int slot) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Save Slot $slot'),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => _loadGame(context, slot),
            child: const Text('Load'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showDeleteConfirmationDialog(context, slot),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGame(BuildContext context, int slot) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyApp(slot: slot)),
    ).then((_) async {
      await _sendPostRequest('load_game', {'slot': slot.toString()});
    });
  }

  Future<void> _sendPostRequest(String endpoint, [Map<String, String>? params]) async {
    try {
      final uri = Uri.http('127.0.0.1:8000', endpoint, params);
      final response = await http.post(uri);
      if (response.statusCode != 200) {
        print('Failed to send request: ${response.statusCode}');
      }
    } catch (e) {
      print('Request failed: $e');
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, int slot) {
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

  Future<void> _deleteGame(int slot) async {
    await _sendPostRequest('delete_game', {'slot': slot.toString()});
  }
}