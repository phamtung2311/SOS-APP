import 'package:geolocator/geolocator.dart';

class TamperDetector {
  bool isMockLocation(Position position) {
    return position.isMocked;
  }
}
