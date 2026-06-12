
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/satellite_data.dart';

class GnssAnalysisView extends StatelessWidget {
  final List<SatelliteData> satellites;
  final List<Map<String, dynamic>> history;

  const GnssAnalysisView({
    super.key, 
    required this.satellites,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (satellites.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.analytics_outlined,
        title: "Chưa có dữ liệu phân tích",
        subtitle: "Vui lòng đợi nhận tín hiệu từ vệ tinh GNSS",
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: UIConsts.spacingLG),
      child: Column(
        children: [
          _buildSignalSummary(context),
          SizedBox(height: UIConsts.spacingLG),
          _buildHistoryChart(context),
          SizedBox(height: UIConsts.spacingLG),
          _buildConstellationAnalysis(context),
          SizedBox(height: UIConsts.spacingLG),
          _buildSnrDistribution(context),
          SizedBox(height: UIConsts.spacingLG),
          _buildDataTable(context),
          SizedBox(height: UIConsts.spacing2XL * 2),
        ],
      ),
    );
  }

  Widget _buildSignalSummary(BuildContext context) {
    final usedInFix = satellites.where((s) => s.usedInFix).length;
    final total = satellites.length;
    final avgSnr = satellites.map((s) => s.snr).reduce((a, b) => a + b) / total;
    
    int excellent = satellites.where((s) => s.snr >= 35).length;
    int good = satellites.where((s) => s.snr >= 25 && s.snr < 35).length;
    int fair = satellites.where((s) => s.snr >= 15 && s.snr < 25).length;
    int poor = satellites.where((s) => s.snr < 15).length;

    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      child: ModernCard(
        accentColor: AppTheme.primaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModernSectionHeader(
              title: "TỔNG QUAN TÍN HIỆU",
              icon: Icons.assessment_rounded,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: UIConsts.spacingLG),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularStat("SỬ DỤNG", "$usedInFix/$total", usedInFix / total, AppTheme.successColor),
                _buildCircularStat("SNR TB", "${avgSnr.toStringAsFixed(1)}", avgSnr / 50, AppTheme.secondaryColor),
              ],
            ),
            SizedBox(height: UIConsts.spacingLG),
            const Text(
              "PHÂN LOẠI CHẤT LƯỢNG",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            SizedBox(height: UIConsts.spacingMD),
            _buildQualityBar("Xuất sắc (>= 35 dB)", excellent, total, AppTheme.successColor),
            _buildQualityBar("Tốt (25 - 35 dB)", good, total, AppTheme.secondaryColor),
            _buildQualityBar("Trung bình (15 - 25 dB)", fair, total, AppTheme.warningColor),
            _buildQualityBar("Yếu (< 15 dB)", poor, total, AppTheme.accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularStat(String label, String value, double percent, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 6,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        SizedBox(height: UIConsts.spacingSM),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQualityBar(String label, int count, int total, Color color) {
    double percent = total > 0 ? count / total : 0;
    return Padding(
      padding: EdgeInsets.only(bottom: UIConsts.spacingSM),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
              Text("$count", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          SizedBox(height: 4),
          ModernProgressBar(progress: percent, color: color, height: 4),
        ],
      ),
    );
  }

  Widget _buildHistoryChart(BuildContext context) {
    if (history.length < 2) {
      return ModernCard(
        accentColor: AppTheme.secondaryColor,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(UIConsts.spacingLG),
            child: Text("Đang thu thập dữ liệu lịch sử...", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ),
      );
    }

    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      delay: const Duration(milliseconds: 50),
      child: ModernCard(
        accentColor: AppTheme.secondaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModernSectionHeader(
              title: "BIẾN ĐỘNG THEO THỜI GIAN",
              icon: Icons.show_chart_rounded,
              color: AppTheme.secondaryColor,
            ),
            SizedBox(height: UIConsts.spacingLG),
            Container(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: GnssLineChartPainter(
                  history: history,
                  snrColor: AppTheme.secondaryColor,
                  satColor: AppTheme.successColor,
                ),
              ),
            ),
            SizedBox(height: UIConsts.spacingMD),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem("SNR TB (dB-Hz)", AppTheme.secondaryColor),
                SizedBox(width: UIConsts.spacingLG),
                _buildLegendItem("Vệ tinh đã dùng", AppTheme.successColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstellationAnalysis(BuildContext context) {
    final Map<String, int> counts = {};
    final Map<String, int> usedCounts = {};
    
    for (var s in satellites) {
      counts[s.system] = (counts[s.system] ?? 0) + 1;
      if (s.usedInFix) {
        usedCounts[s.system] = (usedCounts[s.system] ?? 0) + 1;
      }
    }

    final sortedSystems = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      delay: const Duration(milliseconds: 100),
      child: ModernCard(
        accentColor: AppTheme.secondaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModernSectionHeader(
              title: "PHÂN TÍCH HỆ THỐNG",
              icon: Icons.pie_chart_rounded,
              color: AppTheme.secondaryColor,
            ),
            SizedBox(height: UIConsts.spacingLG),
            ...sortedSystems.map((sys) {
              final total = counts[sys] ?? 0;
              final used = usedCounts[sys] ?? 0;
              final color = kSatelliteSystemColors[sys] ?? Colors.white;
              
              return Padding(
                padding: EdgeInsets.only(bottom: UIConsts.spacingMD),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      child: Text(sys, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          ModernProgressBar(progress: total / satellites.length, color: color.withOpacity(0.3), height: 16),
                          ModernProgressBar(progress: used / satellites.length, color: color, height: 16),
                        ],
                      ),
                    ),
                    SizedBox(width: UIConsts.spacingMD),
                    Container(
                      width: 45,
                      child: Text("$used/$total", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: UIConsts.spacingSM),
            Row(
              children: [
                _buildLegendItem("Đã dùng", AppTheme.primaryColor),
                SizedBox(width: UIConsts.spacingMD),
                _buildLegendItem("Trong tầm", AppTheme.primaryColor.withOpacity(0.3)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }

  Widget _buildSnrDistribution(BuildContext context) {
    // Sử dụng sắp xếp ổn định theo Hệ thống và PRN để các cột không bị nhảy vị trí khi SNR thay đổi
    final displaySats = List<SatelliteData>.from(satellites)
      ..sort((a, b) {
        int sysComp = a.system.compareTo(b.system);
        if (sysComp != 0) return sysComp;
        return a.prn.compareTo(b.prn);
      });

    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      delay: const Duration(milliseconds: 200),
      child: ModernCard(
        accentColor: AppTheme.successColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModernSectionHeader(
              title: "PHỔ TÍN HIỆU SNR",
              icon: Icons.bar_chart_rounded,
              color: AppTheme.successColor,
            ),
            SizedBox(height: UIConsts.spacingLG),
            Container(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displaySats.length,
                itemBuilder: (context, index) {
                  final sat = displaySats[index];
                  final color = kSatelliteSystemColors[sat.system] ?? Colors.white;
                  final heightFactor = (sat.snr / 50).clamp(0.05, 1.0);
                  
                  return Container(
                    key: ValueKey('snr_bar_${sat.system}_${sat.prn}'),
                    width: 30,
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(sat.snr.toStringAsFixed(0), 
                          style: TextStyle(
                            fontSize: 9, 
                            color: sat.usedInFix ? color : color.withOpacity(0.5), 
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          width: 12,
                          height: 120 * heightFactor,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: sat.usedInFix 
                                ? [color, color.withOpacity(0.3)]
                                : [color.withOpacity(0.4), color.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              if (sat.usedInFix) 
                                BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, spreadRadius: 1),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Transform.rotate(
                          angle: -pi / 4,
                          child: Text("${sat.system[0]}${sat.prn}", 
                            style: TextStyle(
                              fontSize: 8, 
                              color: sat.usedInFix ? Colors.white70 : Colors.white24,
                              fontWeight: sat.usedInFix ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(BuildContext context) {
    return EntranceAnimation(
      type: EntranceType.fadeSlideUp,
      delay: const Duration(milliseconds: 300),
      child: ModernCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(UIConsts.spacingLG),
              child: ModernSectionHeader(
                title: "CHI TIẾT DỮ LIỆU",
                icon: Icons.table_chart_rounded,
                color: Colors.white,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                headingTextStyle: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                columns: const [
                  DataColumn(label: Text("SYS")),
                  DataColumn(label: Text("PRN")),
                  DataColumn(label: Text("SNR")),
                  DataColumn(label: Text("ELEV")),
                  DataColumn(label: Text("AZIM")),
                  DataColumn(label: Text("FIX")),
                ],
                rows: satellites.map((sat) {
                  final color = kSatelliteSystemColors[sat.system] ?? Colors.white;
                  return DataRow(cells: [
                    DataCell(Text(sat.system, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))),
                    DataCell(Text("${sat.prn}", style: const TextStyle(fontSize: 11))),
                    DataCell(Text("${sat.snr.toStringAsFixed(1)}", style: TextStyle(color: _getSnrColor(sat.snr), fontWeight: FontWeight.bold, fontSize: 11))),
                    DataCell(Text("${sat.elevation.toStringAsFixed(0)}°", style: const TextStyle(fontSize: 11))),
                    DataCell(Text("${sat.azimuth.toStringAsFixed(0)}°", style: const TextStyle(fontSize: 11))),
                    DataCell(Icon(sat.usedInFix ? Icons.check_circle_rounded : Icons.cancel_outlined, 
                        color: sat.usedInFix ? AppTheme.successColor : Colors.white24, size: 16)),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSnrColor(double snr) {
    if (snr >= 35) return AppTheme.successColor;
    if (snr >= 25) return AppTheme.secondaryColor;
    if (snr >= 15) return AppTheme.warningColor;
    return AppTheme.accentColor;
  }
}

class GnssLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;
  final Color snrColor;
  final Color satColor;

  GnssLineChartPainter({
    required this.history,
    required this.snrColor,
    required this.satColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final double labelHeight = 24.0;
    final double chartHeight = size.height - labelHeight;

    final paintSnr = Paint()
      ..color = snrColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final paintSat = Paint()
      ..color = satColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final paintGrid = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw Grid
    for (int i = 0; i <= 4; i++) {
      double y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final double stepX = size.width / (history.length > 1 ? history.length - 1 : 1);
    
    final Path pathSnr = Path();
    final Path pathSat = Path();

    for (int i = 0; i < history.length; i++) {
      final double x = i * stepX;
      
      final double snr = (history[i]['avgSnr'] as double).clamp(0, 50);
      final double ySnr = chartHeight - (snr / 50 * chartHeight);
      
      final double sats = (history[i]['usedInFix'] as int).toDouble().clamp(0, 20);
      final double ySat = chartHeight - (sats / 20 * chartHeight);

      if (i == 0) {
        pathSnr.moveTo(x, ySnr);
        pathSat.moveTo(x, ySat);
      } else {
        pathSnr.lineTo(x, ySnr);
        pathSat.lineTo(x, ySat);
      }
    }

    // Draw paths with glow
    canvas.drawPath(pathSnr, paintSnr);
    canvas.drawPath(pathSat, paintSat);
    
    // Fill area under SNR path
    final Path fillPathSnr = Path.from(pathSnr)
      ..lineTo(history.length > 1 ? (history.length - 1) * stepX : 0, chartHeight)
      ..lineTo(0, chartHeight)
      ..close();
    
    canvas.drawPath(
      fillPathSnr, 
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [snrColor.withOpacity(0.2), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight))
    );

    // Draw Time Labels (X-axis)
    final int labelCount = history.length < 5 ? history.length : 5;
    if (labelCount > 1) {
      final DateFormat formatter = DateFormat('HH:mm:ss');
      for (int i = 0; i < labelCount; i++) {
        final int index = ((history.length - 1) * i / (labelCount - 1)).round();
        if (index >= history.length) continue;

        final DateTime time = history[index]['timestamp'];
        final String timeStr = formatter.format(time);

        final textPainter = TextPainter(
          text: TextSpan(
            text: timeStr,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        double x = index * stepX;
        // Adjust alignment for edge cases
        if (i == 0) {
          x = 0;
        } else if (i == labelCount - 1) {
          x = size.width - textPainter.width;
        } else {
          x -= textPainter.width / 2;
        }

        textPainter.paint(canvas, Offset(x, chartHeight + 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant GnssLineChartPainter oldDelegate) => true;
}
