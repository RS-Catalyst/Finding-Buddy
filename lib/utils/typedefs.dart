import 'dart:typed_data';

import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';

typedef AnalyseImageCallback = ({
  Uint8List? imageBytes,
  List<DetectedObjectDm> detectedObjects,
});
