class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Finding Buddy';
  static const String appVersion = '1.0.0';
  static const String wakePhrase = 'Hey Finding Buddy';

  // Model Paths
  static const String yolov8ModelPath = 'assets/model/yolov8s_float32.tflite';
  static const String yolov8_16ModelPath =
      'assets/model/yolov8s_float16.tflite';
  static const String yolov8LabelPath = 'assets/label/labels.txt';
  static const String synonymsPath = 'assets/synonyms.json';

  // Distance estimation constants
  static const double referenceObjectDistance = 3.0; // meters
  static const double referenceObjectCoverage = 0.10; // 10% of screen

  // Detection Settings
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.20; // Client requirement: 60%+
  static const double iouThreshold = 0.80;
  static const int ssdCompatibleImageWidth = 640;
  static const int ssdCompatibleImageHeight = 640;

  // Guidance Settings
  static const double guidanceUpdateInterval = 3.0; // seconds
  static const double reachedDistanceThreshold =
      0.5; // meters (bounding box area proxy)
  static const double boundingBoxAreaThresholdPercent =
      0.25; // 25% of screen = reached

  // Storage Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keySelectedLanguage = 'selected_language';
  static const String keyVoiceEnabled = 'voice_enabled';
  static const String keyHapticFeedback = 'haptic_feedback';
  static const String keyShowCameraPreview = 'show_camera_preview';
  static const String keyGuidanceFrequency = 'guidance_frequency';

  // Supported Languages
  static const String langEnglish = 'en';
  static const String langArabic = 'ar';

  // COCO Classes supported by YOLOv8
  static const List<String> supportedClasses = [
    "person",
    "bicycle",
    "car",
    "motorcycle",
    "airplane",
    "bus",
    "train",
    "truck",
    "boat",
    "traffic light",
    "fire hydrant",
    "stop sign",
    "parking meter",
    "bench",
    "bird",
    "cat",
    "dog",
    "horse",
    "sheep",
    "cow",
    "elephant",
    "bear",
    "zebra",
    "giraffe",
    "backpack",
    "umbrella",
    "handbag",
    "tie",
    "suitcase",
    "frisbee",
    "skis",
    "snowboard",
    "sports ball",
    "kite",
    "baseball bat",
    "baseball glove",
    "skateboard",
    "surfboard",
    "tennis racket",
    "bottle",
    "wine glass",
    "cup",
    "fork",
    "knife",
    "spoon",
    "bowl",
    "banana",
    "apple",
    "sandwich",
    "orange",
    "broccoli",
    "carrot",
    "hot dog",
    "pizza",
    "donut",
    "cake",
    "chair",
    "couch",
    "potted plant",
    "bed",
    "dining table",
    "toilet",
    "tv",
    "laptop",
    "mouse",
    "remote",
    "keyboard",
    "cell phone",
    "microwave",
    "oven",
    "toaster",
    "sink",
    "refrigerator",
    "book",
    "clock",
    "vase",
    "scissors",
    "teddy bear",
    "hair drier",
    "toothbrush",
  ];

  // Clock positions for guidance
  static const Map<int, String> clockPositions = {
    12: "12 o'clock",
    1: "1 o'clock",
    2: "2 o'clock",
    3: "3 o'clock",
    4: "4 o'clock",
    5: "5 o'clock",
    6: "6 o'clock",
    7: "7 o'clock",
    8: "8 o'clock",
    9: "9 o'clock",
    10: "10 o'clock",
    11: "11 o'clock",
  };

  // Arabic clock positions
  static const Map<int, String> clockPositionsArabic = {
    12: "الساعة ١٢",
    1: "الساعة ١",
    2: "الساعة ٢",
    3: "الساعة ٣",
    4: "الساعة ٤",
    5: "الساعة ٥",
    6: "الساعة ٦",
    7: "الساعة ٧",
    8: "الساعة ٨",
    9: "الساعة ٩",
    10: "الساعة ١٠",
    11: "الساعة ١١",
  };
}
