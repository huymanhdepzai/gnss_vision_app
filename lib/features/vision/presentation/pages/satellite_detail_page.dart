import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'satellite_page.dart';

class SatelliteDetailScreen extends StatefulWidget {
  final SatelliteData satellite;
  final Color themeColor;

  const SatelliteDetailScreen({
    Key? key,
    required this.satellite,
    required this.themeColor,
  }) : super(key: key);

  @override
  State<SatelliteDetailScreen> createState() => _SatelliteDetailScreenState();
}

class _SatelliteDetailScreenState extends State<SatelliteDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.themeColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            _buildHeroHeader(),
                            const SizedBox(height: 30),
                            _buildMainStatsGrid(),
                            const SizedBox(height: 20),
                            _buildSignalSection(),
                            const SizedBox(height: 20),
                            _buildTechnicalDetails(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Text(
            "CHI TIẾT VỆ TINH",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        Hero(
          tag: 'sat_icon_${widget.satellite.prn}',
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [widget.themeColor, widget.themeColor.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.themeColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.satellite_alt_rounded, size: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Hero(
          tag: 'sat_prn_${widget.satellite.prn}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              "PRN #${widget.satellite.prn}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: widget.themeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.themeColor.withOpacity(0.3)),
          ),
          child: Text(
            widget.satellite.system,
            style: TextStyle(
              color: widget.themeColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainStatsGrid() {
    return Row(
      children: [
        _buildStatCard(
          "SNR",
          "${widget.satellite.snr.toStringAsFixed(1)}",
          "dB-Hz",
          Icons.signal_cellular_alt_rounded,
        ),
        const SizedBox(width: 15),
        _buildStatCard(
          "CỐ ĐỊNH",
          widget.satellite.usedInFix ? "ĐANG DÙNG" : "KHÔNG",
          "",
          widget.satellite.usedInFix ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
          isHighlight: widget.satellite.usedInFix,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit, IconData icon, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHighlight ? widget.themeColor.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isHighlight ? widget.themeColor : Colors.white38, size: 24),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      unit,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CƯỜNG ĐỘ TÍN HIỆU",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (widget.satellite.snr / 50).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: widget.themeColor,
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Text(
                "${widget.satellite.snr.toInt()}%",
                style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.satellite.snr > 30 ? "Tín hiệu mạnh và ổn định" : "Tín hiệu trung bình",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "THÔNG SỐ",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),
          _buildDetailRow("Độ cao (Elevation)", "${widget.satellite.elevation.toStringAsFixed(2)}°", Icons.height_rounded),
          const Divider(color: Colors.white10, height: 30),
          _buildDetailRow("Góc phương vị (Azimuth)", "${widget.satellite.azimuth.toStringAsFixed(2)}°", Icons.explore_rounded),
          const Divider(color: Colors.white10, height: 30),
          _buildDetailRow("Hệ thống", widget.satellite.system, Icons.language_rounded),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: widget.themeColor, size: 20),
        ),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
