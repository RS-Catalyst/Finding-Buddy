import 'dart:async';

import 'package:finding_buddy/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Complete object picker with all 80 COCO classes + speech support
class CompleteObjectPickerSheet extends StatefulWidget {
  final Function(String) onObjectSelected;

  final bool enableSpeech;

  const CompleteObjectPickerSheet({
    super.key,
    required this.onObjectSelected,
    this.enableSpeech = true,
  });

  @override
  State<CompleteObjectPickerSheet> createState() =>
      _CompleteObjectPickerSheetState();
}

class _CompleteObjectPickerSheetState extends State<CompleteObjectPickerSheet> {
  bool _showAllObjects = false;
  bool _isListening = false;
  final RxString _recognizedText = ''.obs;

  late stt.SpeechToText _speech;
  bool _speechAvailable = false;

  // Safety timer - force stop if speech hangs
  Timer? _listeningTimer;
  // Periodic sync check timer
  Timer? _syncCheckTimer;

  // Top 8 common objects
  static const List<Map<String, dynamic>> commonObjects = [
    {'name': 'cell phone', 'icon': Icons.phone_android, 'label': 'Phone'},
    {'name': 'remote', 'icon': Icons.settings_remote, 'label': 'Remote'},
    {'name': 'bottle', 'icon': Icons.local_drink, 'label': 'Bottle'},
    {'name': 'cup', 'icon': Icons.coffee, 'label': 'Cup'},
    {'name': 'laptop', 'icon': Icons.laptop, 'label': 'Laptop'},
    {'name': 'backpack', 'icon': Icons.backpack, 'label': 'Backpack'},
    {'name': 'book', 'icon': Icons.book, 'label': 'Book'},
    {
      'name': 'view_all',
      'icon': Icons.grid_view,
      'label': 'View All',
      'isAction': true,
    },
  ];

  // All 80 COCO classes with icons
  static const List<Map<String, dynamic>> allObjects = [
    // People & Animals
    {'name': 'person', 'icon': Icons.person, 'category': 'People'},
    {'name': 'cat', 'icon': Icons.pets, 'category': 'Animals'},
    {'name': 'dog', 'icon': Icons.pets, 'category': 'Animals'},
    {'name': 'horse', 'icon': Icons.agriculture, 'category': 'Animals'},
    {'name': 'sheep', 'icon': Icons.agriculture, 'category': 'Animals'},
    {'name': 'cow', 'icon': Icons.agriculture, 'category': 'Animals'},
    {'name': 'elephant', 'icon': Icons.pets, 'category': 'Animals'},
    {'name': 'bear', 'icon': Icons.pets, 'category': 'Animals'},
    {'name': 'zebra', 'icon': Icons.pets, 'category': 'Animals'},
    {'name': 'giraffe', 'icon': Icons.pets, 'category': 'Animals'},
    {'name': 'bird', 'icon': Icons.flutter_dash, 'category': 'Animals'},

    // Vehicles
    {'name': 'bicycle', 'icon': Icons.pedal_bike, 'category': 'Vehicles'},
    {'name': 'car', 'icon': Icons.directions_car, 'category': 'Vehicles'},
    {'name': 'motorcycle', 'icon': Icons.two_wheeler, 'category': 'Vehicles'},
    {'name': 'airplane', 'icon': Icons.flight, 'category': 'Vehicles'},
    {'name': 'bus', 'icon': Icons.directions_bus, 'category': 'Vehicles'},
    {'name': 'train', 'icon': Icons.train, 'category': 'Vehicles'},
    {'name': 'truck', 'icon': Icons.local_shipping, 'category': 'Vehicles'},
    {'name': 'boat', 'icon': Icons.directions_boat, 'category': 'Vehicles'},

    // Outdoor Objects
    {'name': 'traffic light', 'icon': Icons.traffic, 'category': 'Outdoor'},
    {
      'name': 'fire hydrant',
      'icon': Icons.local_fire_department,
      'category': 'Outdoor',
    },
    {'name': 'stop sign', 'icon': Icons.stop, 'category': 'Outdoor'},
    {
      'name': 'parking meter',
      'icon': Icons.local_parking,
      'category': 'Outdoor',
    },
    {'name': 'bench', 'icon': Icons.weekend, 'category': 'Outdoor'},

    // Accessories
    {'name': 'backpack', 'icon': Icons.backpack, 'category': 'Accessories'},
    {'name': 'umbrella', 'icon': Icons.umbrella, 'category': 'Accessories'},
    {'name': 'handbag', 'icon': Icons.shopping_bag, 'category': 'Accessories'},
    {'name': 'tie', 'icon': Icons.work, 'category': 'Accessories'},
    {'name': 'suitcase', 'icon': Icons.luggage, 'category': 'Accessories'},

    // Sports
    {'name': 'frisbee', 'icon': Icons.sports, 'category': 'Sports'},
    {'name': 'skis', 'icon': Icons.downhill_skiing, 'category': 'Sports'},
    {'name': 'snowboard', 'icon': Icons.snowboarding, 'category': 'Sports'},
    {'name': 'sports ball', 'icon': Icons.sports_soccer, 'category': 'Sports'},
    {'name': 'kite', 'icon': Icons.flight, 'category': 'Sports'},
    {
      'name': 'baseball bat',
      'icon': Icons.sports_baseball,
      'category': 'Sports',
    },
    {
      'name': 'baseball glove',
      'icon': Icons.sports_baseball,
      'category': 'Sports',
    },
    {'name': 'skateboard', 'icon': Icons.skateboarding, 'category': 'Sports'},
    {'name': 'surfboard', 'icon': Icons.surfing, 'category': 'Sports'},
    {
      'name': 'tennis racket',
      'icon': Icons.sports_tennis,
      'category': 'Sports',
    },

    // Kitchen & Dining
    {'name': 'bottle', 'icon': Icons.local_drink, 'category': 'Kitchen'},
    {'name': 'wine glass', 'icon': Icons.wine_bar, 'category': 'Kitchen'},
    {'name': 'cup', 'icon': Icons.coffee, 'category': 'Kitchen'},
    {'name': 'fork', 'icon': Icons.restaurant, 'category': 'Kitchen'},
    {'name': 'knife', 'icon': Icons.restaurant, 'category': 'Kitchen'},
    {'name': 'spoon', 'icon': Icons.restaurant, 'category': 'Kitchen'},
    {'name': 'bowl', 'icon': Icons.soup_kitchen, 'category': 'Kitchen'},

    // Food
    {'name': 'banana', 'icon': Icons.breakfast_dining, 'category': 'Food'},
    {'name': 'apple', 'icon': Icons.apple, 'category': 'Food'},
    {'name': 'sandwich', 'icon': Icons.lunch_dining, 'category': 'Food'},
    {'name': 'orange', 'icon': Icons.breakfast_dining, 'category': 'Food'},
    {'name': 'broccoli', 'icon': Icons.eco, 'category': 'Food'},
    {'name': 'carrot', 'icon': Icons.eco, 'category': 'Food'},
    {'name': 'hot dog', 'icon': Icons.lunch_dining, 'category': 'Food'},
    {'name': 'pizza', 'icon': Icons.local_pizza, 'category': 'Food'},
    {'name': 'donut', 'icon': Icons.donut_small, 'category': 'Food'},
    {'name': 'cake', 'icon': Icons.cake, 'category': 'Food'},

    // Furniture
    {'name': 'chair', 'icon': Icons.chair, 'category': 'Furniture'},
    {'name': 'couch', 'icon': Icons.weekend, 'category': 'Furniture'},
    {
      'name': 'potted plant',
      'icon': Icons.local_florist,
      'category': 'Furniture',
    },
    {'name': 'bed', 'icon': Icons.bed, 'category': 'Furniture'},
    {
      'name': 'dining table',
      'icon': Icons.table_restaurant,
      'category': 'Furniture',
    },
    {'name': 'toilet', 'icon': Icons.wc, 'category': 'Furniture'},

    // Electronics
    {'name': 'tv', 'icon': Icons.tv, 'category': 'Electronics'},
    {'name': 'laptop', 'icon': Icons.laptop, 'category': 'Electronics'},
    {'name': 'mouse', 'icon': Icons.mouse, 'category': 'Electronics'},
    {
      'name': 'remote',
      'icon': Icons.settings_remote,
      'category': 'Electronics',
    },
    {'name': 'keyboard', 'icon': Icons.keyboard, 'category': 'Electronics'},
    {
      'name': 'cell phone',
      'icon': Icons.phone_android,
      'category': 'Electronics',
    },

    // Appliances
    {'name': 'microwave', 'icon': Icons.microwave, 'category': 'Appliances'},
    {'name': 'oven', 'icon': Icons.countertops, 'category': 'Appliances'},
    {
      'name': 'toaster',
      'icon': Icons.breakfast_dining,
      'category': 'Appliances',
    },
    {'name': 'sink', 'icon': Icons.water_drop, 'category': 'Appliances'},
    {'name': 'refrigerator', 'icon': Icons.kitchen, 'category': 'Appliances'},

    // Other Items
    {'name': 'book', 'icon': Icons.book, 'category': 'Other'},
    {'name': 'clock', 'icon': Icons.access_time, 'category': 'Other'},
    {'name': 'vase', 'icon': Icons.local_florist, 'category': 'Other'},
    {'name': 'scissors', 'icon': Icons.content_cut, 'category': 'Other'},
    {'name': 'teddy bear', 'icon': Icons.toys, 'category': 'Other'},
    {'name': 'hair drier', 'icon': Icons.air, 'category': 'Other'},
    {
      'name': 'toothbrush',
      'icon': Icons.cleaning_services,
      'category': 'Other',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.enableSpeech) {
      _setupSpeechRecognition();
    }
  }

  void _setupSpeechRecognition() async {
    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          print('🎤 STT status: $status');

          // Jab bhi speech stop ho - kisi bhi reason se
          if (status == 'notListening' ||
              status == 'done' ||
              status == 'timeout') {
            _stopListeningState();
          }
        },
        onError: (error) {
          print('❌ STT error: $error');
          _stopListeningState();
        },
      );
      print('🎤 Speech available: $_speechAvailable');
    } catch (e) {
      print('❌ Speech init error: $e');
      _speechAvailable = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Centralized function to stop listening state
  /// Yeh ensure karta hai ke saari jagah se consistent stop ho
  void _stopListeningState() {
    // Cancel all timers
    _listeningTimer?.cancel();
    _listeningTimer = null;
    _syncCheckTimer?.cancel();
    _syncCheckTimer = null;

    if (_isListening) {
      _isListening = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Periodic check to sync UI state with actual speech state
  void _startPeriodicSyncCheck() {
    _syncCheckTimer?.cancel();
    _syncCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Agar humara state listening hai but speech actually nahi sun rahi
      if (_isListening && !_speech.isListening) {
        print('🔄 Sync fix: speech stopped but UI state was still listening');
        _stopListeningState();
      }

      // Agar listening done ho gayi, timer band karo
      if (!_isListening) {
        timer.cancel();
      }
    });
  }

  void _toggleListening() async {
    // Try to (re-)initialize if not available yet
    if (!_speechAvailable) {
      await _setupAndHandleAvailability();
      if (!_speechAvailable) {
        _stopListeningState();
        return;
      }
    }

    // Agar already listening hai to stop karo
    if (_isListening) {
      await _speech.stop();
      _stopListeningState();
      return;
    }

    // Start listening
    _recognizedText.value = '';
    _isListening = true;
    setState(() {});

    // Safety timer - 35 seconds baad force stop
    // Agar kisi wajah se onStatus fire na ho
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 35), () {
      print('⏰ Safety timer triggered - force stopping');
      if (_isListening) {
        _speech.stop();
        _stopListeningState();
      }
    });

    // Start periodic sync check
    _startPeriodicSyncCheck();

    try {
      await _speech.listen(
        onResult: (result) {
          print(
            '📝 Result: ${result.recognizedWords} | Final: ${result.finalResult}',
          );
          _recognizedText.value = result.recognizedWords;

          if (result.finalResult) {
            final finalText = _recognizedText.value.trim();

            // Stop listening state first
            _stopListeningState();

            // Then process the text
            if (finalText.isNotEmpty) {
              _processRecognizedText(finalText);
            }
          }
        },
        localeId: null,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
      );
    } catch (e) {
      print('❌ Listen error: $e');
      _stopListeningState();
    }
  }

  // Helper that attempts initialization and updates state properly
  Future<void> _setupAndHandleAvailability() async {
    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          print('🎤 STT status: $status');
          if (status == 'notListening' ||
              status == 'done' ||
              status == 'timeout') {
            _stopListeningState();
          }
        },
        onError: (error) {
          print('❌ STT error: $error');
          _stopListeningState();
        },
      );
    } catch (e) {
      _speechAvailable = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  // helper: collect candidate matches from your lists
  void _processRecognizedText(String text) {
    if (text.isEmpty) {
      return;
    }

    final lower = text.toLowerCase();

    // Build a list of candidate items with display label and a canonical name to send downstream
    final List<Map<String, dynamic>> candidates = [];

    // check commonObjects first (they have 'label' and 'name')
    for (var obj in commonObjects) {
      final name = (obj['name'] as String).toLowerCase();
      final label = (obj['label'] as String).toLowerCase();
      if (lower.contains(name) || lower.contains(label)) {
        candidates.add({
          'name': obj['name'] as String,
          'label': obj['label'] as String,
          'icon': obj['icon'] as IconData,
        });
      }
    }

    // check allObjects (they have 'name' and sometimes no 'label')
    for (var obj in allObjects) {
      final name = (obj['name'] as String).toLowerCase();
      final label = (obj['label'] as String?)?.toLowerCase() ?? name;
      final already = candidates.any(
        (c) => (c['name'] as String).toLowerCase() == name,
      );
      if (!already && (lower.contains(name) || lower.contains(label))) {
        candidates.add({
          'name': obj['name'] as String,
          'label': (obj['label'] as String?) ?? obj['name'] as String,
          'icon': obj['icon'] as IconData,
        });
      }
    }

    if (candidates.isEmpty) {
      return;
    }

    if (candidates.length == 1) {
      widget.onObjectSelected(candidates.first['name'] as String);
      return;
    }

    _showMultipleSelectionDialog(candidates);
  }

  void _showMultipleSelectionDialog(List<Map<String, dynamic>> candidates) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Select item'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = candidates[index];
                return ListTile(
                  leading: Icon(
                    c['icon'] as IconData,
                    color: AppTheme.primaryTeal,
                  ),
                  title: Text(c['label'] as String),
                  subtitle: Text(
                    c['name'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onObjectSelected(c['name'] as String);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title with voice button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'what_to_find'.tr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.enableSpeech)
                    IconButton(
                      onPressed: _toggleListening,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : AppTheme.primaryTeal,
                      ),
                      iconSize: 32,
                    ),
                ],
              ),
            ),

            // Recognized text
            if (widget.enableSpeech)
              Obx(
                () => _recognizedText.value.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          'Recognized: ${_recognizedText.value}',
                          style: const TextStyle(
                            color: AppTheme.primaryTeal,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

            const SizedBox(height: 20),

            // Object grid
            Flexible(
              child: _showAllObjects
                  ? _buildAllObjectsList()
                  : _buildCommonObjectsGrid(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonObjectsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: commonObjects.length,
      itemBuilder: (context, index) {
        final obj = commonObjects[index];
        final isAction = obj['isAction'] == true;

        return _ObjectTile(
          icon: obj['icon'] as IconData,
          label: obj['label'] as String,
          isAction: isAction,
          onTap: () {
            if (isAction) {
              setState(() => _showAllObjects = true);
            } else {
              widget.onObjectSelected(obj['name'] as String);
            }
          },
        );
      },
    );
  }

  Widget _buildAllObjectsList() {
    // Group by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var obj in allObjects) {
      final category = obj['category'] as String? ?? 'Other';
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(obj);
    }

    return Column(
      children: [
        // Back button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showAllObjects = false),
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                'All Objects (${allObjects.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Categorized list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final category = grouped.keys.elementAt(index);
              final items = grouped[category]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ),

                  // Category items
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map((obj) {
                      return InkWell(
                        onTap: () =>
                            widget.onObjectSelected(obj['name'] as String),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryTeal.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                obj['icon'] as IconData,
                                size: 18,
                                color: AppTheme.primaryTeal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                obj['name'] as String,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Cancel all timers
    _listeningTimer?.cancel();
    _syncCheckTimer?.cancel();

    // Stop and cancel speech
    if (_speechAvailable) {
      _speech.stop();
      _speech.cancel();
    }

    super.dispose();
  }
}

class _ObjectTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isAction;

  const _ObjectTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isAction
                ? AppTheme.primaryTeal.withOpacity(0.2)
                : AppTheme.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAction
                  ? AppTheme.primaryTeal.withOpacity(0.6)
                  : AppTheme.primaryTeal.withOpacity(0.3),
              width: isAction ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primaryTeal, size: isAction ? 32 : 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: isAction ? 11 : 12,
                  fontWeight: isAction ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
