import 'dart:convert';
import 'package:finding_buddy/utils/app_constants.dart';
import 'package:flutter/services.dart';

class SynonymService {
  SynonymService._();
  static final SynonymService instance = SynonymService._();

  Map<String, String> _synonymMap = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize synonyms from JSON file
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final jsonString = await rootBundle.loadString(AppConstants.synonymsPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Build reverse mapping: synonym -> model class
      _synonymMap = {};
      jsonData.forEach((modelClass, synonyms) {
        // Add the model class itself
        _synonymMap[modelClass.toLowerCase()] = modelClass.toLowerCase();

        // Add all synonyms
        if (synonyms is List) {
          for (final synonym in synonyms) {
            _synonymMap[synonym.toString().toLowerCase()] = modelClass
                .toLowerCase();
          }
        }
      });

      _isInitialized = true;
    } catch (e) {
      // Use default mapping if file not found
      _buildDefaultSynonyms();
      _isInitialized = true;
    }
  }

  /// Build default synonym mappings
  void _buildDefaultSynonyms() {
    _synonymMap = {
      // Person synonyms
      'person': 'person',
      'people': 'person',
      'human': 'person',
      'man': 'person',
      'woman': 'person',
      'child': 'person',
      'kid': 'person',
      'boy': 'person',
      'girl': 'person',

      // Bicycle synonyms
      'bicycle': 'bicycle',
      'bike': 'bicycle',
      'cycle': 'bicycle',
      'push bike': 'bicycle',

      // Car synonyms
      'car': 'car',
      'automobile': 'car',
      'vehicle': 'car',
      'sedan': 'car',
      'suv': 'car',
      'van': 'car',

      // Motorcycle synonyms
      'motorcycle': 'motorcycle',
      'motorbike': 'motorcycle',
      'scooter': 'motorcycle',

      // Airplane synonyms
      'airplane': 'airplane',
      'plane': 'airplane',
      'aircraft': 'airplane',
      'jet': 'airplane',
      'aeroplane': 'airplane',

      // Bus synonyms
      'bus': 'bus',
      'coach': 'bus',
      'shuttle': 'bus',

      // Train synonyms
      'train': 'train',
      'railway': 'train',
      'locomotive': 'train',
      'metro': 'train',
      'subway': 'train',

      // Truck synonyms
      'truck': 'truck',
      'lorry': 'truck',
      'pickup': 'truck',
      'delivery truck': 'truck',

      // Boat synonyms
      'boat': 'boat',
      'ship': 'boat',
      'vessel': 'boat',
      'yacht': 'boat',

      // Traffic light synonyms
      'traffic light': 'traffic light',
      'stoplight': 'traffic light',
      'signal': 'traffic light',
      'traffic signal': 'traffic light',

      // Fire hydrant synonyms
      'fire hydrant': 'fire hydrant',
      'hydrant': 'fire hydrant',
      'water hydrant': 'fire hydrant',

      // Stop sign synonyms
      'stop sign': 'stop sign',
      'stop': 'stop sign',

      // Parking meter synonyms
      'parking meter': 'parking meter',
      'meter': 'parking meter',

      // Bench synonyms
      'bench': 'bench',
      'seat': 'bench',
      'park bench': 'bench',

      // Bird synonyms
      'bird': 'bird',
      'pigeon': 'bird',
      'sparrow': 'bird',
      'crow': 'bird',
      'seagull': 'bird',

      // Cat synonyms
      'cat': 'cat',
      'kitten': 'cat',
      'kitty': 'cat',
      'feline': 'cat',

      // Dog synonyms
      'dog': 'dog',
      'puppy': 'dog',
      'doggy': 'dog',
      'canine': 'dog',
      'pup': 'dog',

      // Horse synonyms
      'horse': 'horse',
      'pony': 'horse',
      'stallion': 'horse',
      'mare': 'horse',

      // Sheep synonyms
      'sheep': 'sheep',
      'lamb': 'sheep',

      // Cow synonyms
      'cow': 'cow',
      'cattle': 'cow',
      'bull': 'cow',
      'calf': 'cow',

      // Elephant synonyms
      'elephant': 'elephant',

      // Bear synonyms
      'bear': 'bear',

      // Zebra synonyms
      'zebra': 'zebra',

      // Giraffe synonyms
      'giraffe': 'giraffe',

      // Backpack synonyms
      'backpack': 'backpack',
      'bag': 'backpack',
      'school bag': 'backpack',
      'rucksack': 'backpack',
      'knapsack': 'backpack',

      // Umbrella synonyms
      'umbrella': 'umbrella',
      'parasol': 'umbrella',

      // Handbag synonyms
      'handbag': 'handbag',
      'purse': 'handbag',
      'wallet': 'handbag',
      'clutch': 'handbag',
      'tote': 'handbag',

      // Tie synonyms
      'tie': 'tie',
      'necktie': 'tie',
      'bowtie': 'tie',

      // Suitcase synonyms
      'suitcase': 'suitcase',
      'luggage': 'suitcase',
      'baggage': 'suitcase',
      'travel bag': 'suitcase',

      // Frisbee synonyms
      'frisbee': 'frisbee',
      'disc': 'frisbee',
      'flying disc': 'frisbee',

      // Skis synonyms
      'skis': 'skis',
      'ski': 'skis',

      // Snowboard synonyms
      'snowboard': 'snowboard',

      // Sports ball synonyms
      'sports ball': 'sports ball',
      'ball': 'sports ball',
      'football': 'sports ball',
      'soccer ball': 'sports ball',
      'basketball': 'sports ball',
      'tennis ball': 'sports ball',
      'volleyball': 'sports ball',

      // Kite synonyms
      'kite': 'kite',

      // Baseball bat synonyms
      'baseball bat': 'baseball bat',
      'bat': 'baseball bat',

      // Baseball glove synonyms
      'baseball glove': 'baseball glove',
      'glove': 'baseball glove',
      'mitt': 'baseball glove',

      // Skateboard synonyms
      'skateboard': 'skateboard',
      'board': 'skateboard',

      // Surfboard synonyms
      'surfboard': 'surfboard',
      'surf board': 'surfboard',

      // Tennis racket synonyms
      'tennis racket': 'tennis racket',
      'racket': 'tennis racket',
      'racquet': 'tennis racket',

      // Bottle synonyms
      'bottle': 'bottle',
      'water bottle': 'bottle',
      'drink': 'bottle',
      'flask': 'bottle',

      // Wine glass synonyms
      'wine glass': 'wine glass',
      'glass': 'wine glass',
      'wine': 'wine glass',

      // Cup synonyms
      'cup': 'cup',
      'mug': 'cup',
      'coffee cup': 'cup',
      'tea cup': 'cup',
      'teacup': 'cup',

      // Fork synonyms
      'fork': 'fork',

      // Knife synonyms
      'knife': 'knife',
      'butter knife': 'knife',

      // Spoon synonyms
      'spoon': 'spoon',
      'teaspoon': 'spoon',
      'tablespoon': 'spoon',

      // Bowl synonyms
      'bowl': 'bowl',
      'dish': 'bowl',

      // Banana synonyms
      'banana': 'banana',

      // Apple synonyms
      'apple': 'apple',

      // Sandwich synonyms
      'sandwich': 'sandwich',
      'burger': 'sandwich',
      'hamburger': 'sandwich',
      'sub': 'sandwich',

      // Orange synonyms
      'orange': 'orange',

      // Broccoli synonyms
      'broccoli': 'broccoli',

      // Carrot synonyms
      'carrot': 'carrot',

      // Hot dog synonyms
      'hot dog': 'hot dog',
      'hotdog': 'hot dog',

      // Pizza synonyms
      'pizza': 'pizza',
      'pie': 'pizza',

      // Donut synonyms
      'donut': 'donut',
      'doughnut': 'donut',

      // Cake synonyms
      'cake': 'cake',
      'pastry': 'cake',

      // Chair synonyms
      'chair': 'chair',
      'stool': 'chair',

      // Couch synonyms
      'couch': 'couch',
      'sofa': 'couch',
      'settee': 'couch',
      'loveseat': 'couch',

      // Potted plant synonyms
      'potted plant': 'potted plant',
      'plant': 'potted plant',
      'pot plant': 'potted plant',
      'houseplant': 'potted plant',

      // Bed synonyms
      'bed': 'bed',
      'mattress': 'bed',

      // Dining table synonyms
      'dining table': 'dining table',
      'table': 'dining table',
      'desk': 'dining table',

      // Toilet synonyms
      'toilet': 'toilet',
      'wc': 'toilet',
      'commode': 'toilet',
      'lavatory': 'toilet',

      // TV synonyms
      'tv': 'tv',
      'television': 'tv',
      'monitor': 'tv',
      'screen': 'tv',
      'display': 'tv',

      // Laptop synonyms
      'laptop': 'laptop',
      'computer': 'laptop',
      'notebook': 'laptop',
      'macbook': 'laptop',
      'pc': 'laptop',

      // Mouse synonyms
      'mouse': 'mouse',
      'computer mouse': 'mouse',

      // Remote synonyms
      'remote': 'remote',
      'remote control': 'remote',
      'tv remote': 'remote',
      'controller': 'remote',
      'keys': 'remote',
      'key': 'remote',

      // Keyboard synonyms
      'keyboard': 'keyboard',
      'computer keyboard': 'keyboard',

      // Cell phone synonyms
      'cell phone': 'cell phone',
      'phone': 'cell phone',
      'mobile': 'cell phone',
      'mobile phone': 'cell phone',
      'cellphone': 'cell phone',
      'smartphone': 'cell phone',
      'iphone': 'cell phone',
      'android': 'cell phone',

      // Microwave synonyms
      'microwave': 'microwave',
      'microwave oven': 'microwave',

      // Oven synonyms
      'oven': 'oven',
      'stove': 'oven',
      'range': 'oven',

      // Toaster synonyms
      'toaster': 'toaster',

      // Sink synonyms
      'sink': 'sink',
      'basin': 'sink',
      'washbasin': 'sink',

      // Refrigerator synonyms
      'refrigerator': 'refrigerator',
      'fridge': 'refrigerator',
      'freezer': 'refrigerator',

      // Book synonyms
      'book': 'book',
      'novel': 'book',
      'textbook': 'book',
      'magazine': 'book',

      // Clock synonyms
      'clock': 'clock',
      'wall clock': 'clock',
      'watch': 'clock',

      // Vase synonyms
      'vase': 'vase',
      'flower vase': 'vase',

      // Scissors synonyms
      'scissors': 'scissors',
      'shears': 'scissors',

      // Teddy bear synonyms
      'teddy bear': 'teddy bear',
      'teddy': 'teddy bear',
      'stuffed animal': 'teddy bear',
      'plush toy': 'teddy bear',

      // Hair drier synonyms
      'hair drier': 'hair drier',
      'hair dryer': 'hair drier',
      'hairdryer': 'hair drier',
      'blow dryer': 'hair drier',

      // Toothbrush synonyms
      'toothbrush': 'toothbrush',
      'tooth brush': 'toothbrush',
    };
  }

  /// Resolve user input to model class
  /// Returns null if not supported
  String? resolveToModelClass(String userInput) {
    final normalized = userInput.toLowerCase().trim();

    // Direct match
    if (_synonymMap.containsKey(normalized)) {
      return _synonymMap[normalized];
    }

    // Partial match - find if user input contains a known synonym
    for (final entry in _synonymMap.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Check if a class is supported
  bool isSupported(String className) {
    return AppConstants.supportedClasses.contains(className.toLowerCase());
  }

  /// Extract object name from voice command
  /// Examples: "find my phone" -> "phone", "where is the bottle" -> "bottle"
  String? extractObjectFromCommand(String command) {
    final normalized = command.toLowerCase().trim();

    // Common command patterns
    final patterns = [
      RegExp(r'find (?:my |the |a )?(.+)'),
      RegExp(r'where is (?:my |the |a )?(.+)'),
      RegExp(r'locate (?:my |the |a )?(.+)'),
      RegExp(r'search for (?:my |the |a )?(.+)'),
      RegExp(r'look for (?:my |the |a )?(.+)'),
      RegExp(r'(?:my |the |a )?(.+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null && match.groupCount >= 1) {
        final extracted = match.group(1)?.trim();
        if (extracted != null && extracted.isNotEmpty) {
          return extracted;
        }
      }
    }

    return normalized;
  }

  /// Get all supported object names for display
  List<String> getSupportedObjects() {
    return AppConstants.supportedClasses.toList();
  }
}
