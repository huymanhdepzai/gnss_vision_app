import 'package:flutter/material.dart';

class SatelliteData {
  final int prn;
  final double elevation;
  final double azimuth;
  final double snr;
  final String system;
  final bool usedInFix;

  SatelliteData({
    required this.prn,
    required this.elevation,
    required this.azimuth,
    required this.snr,
    required this.system,
    required this.usedInFix,
  });
}

const Map<String, Color> kSatelliteSystemColors = {
  'GPS': Color(0xFF00D4FF),
  'GLONASS': Color(0xFFFF5252),
  'GALILEO': Color(0xFFB388FF),
  'BEIDOU': Color(0xFF69F0AE),
  'QZSS': Color(0xFFFFAB40),
};

const Map<String, String> kSatelliteSystemLabels = {
  'ALL': 'Tất cả',
  'GPS': 'GPS',
  'GLONASS': 'GLO',
  'GALILEO': 'GAL',
  'BEIDOU': 'BDS',
  'QZSS': 'QZSS',
};

const List<String> kFilterSystems = ['ALL', 'GPS', 'GLONASS', 'GALILEO', 'BEIDOU'];
