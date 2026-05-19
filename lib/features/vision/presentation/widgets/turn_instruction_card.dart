import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../map/domain/entities/navigation_step.dart';

class TurnInstructionCard extends StatelessWidget {
  final NavigationStep? currentStep;
  final String distanceText;
  final String durationText;
  final String destinationName;
  final double progressPercentage;

  const TurnInstructionCard({
    Key? key,
    this.currentStep,
    this.distanceText = '',
    this.durationText = '',
    this.destinationName = '',
    this.progressPercentage = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentStep == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.75),
            Colors.black.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMainInstruction(context),
                if (destinationName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDestinationBar(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainInstruction(BuildContext context) {
    return Row(
      children: [
        _buildManeuverIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getInstructionText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.straighten_rounded,
                    color: AppTheme.secondaryColor.withOpacity(0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDistance(currentStep!.distance),
                    style: TextStyle(
                      color: AppTheme.secondaryColor.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (currentStep!.name != null &&
                      currentStep!.name!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        currentStep!.name!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManeuverIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(_getManeuverIcon(), color: Colors.white, size: 24),
    );
  }

  Widget _buildDestinationBar(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progressPercentage.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  IconData _getManeuverIcon() {
    if (currentStep == null) return Icons.navigation_rounded;

    final modifier = currentStep!.maneuverModifier?.toLowerCase() ?? '';
    switch (currentStep!.maneuverType) {
      case ManeuverType.depart:
        return Icons.navigation_rounded;
      case ManeuverType.arrive:
        return Icons.flag_rounded;
      case ManeuverType.turn:
        if (modifier.contains('left')) {
          return modifier.contains('sharp')
              ? Icons.turn_sharp_left_rounded
              : Icons.turn_left_rounded;
        } else if (modifier.contains('right')) {
          return modifier.contains('sharp')
              ? Icons.turn_sharp_right_rounded
              : Icons.turn_right_rounded;
        } else if (modifier.contains('uturn')) {
          return Icons.u_turn_left_rounded;
        }
        return Icons.turn_slight_right_rounded;
      case ManeuverType.fork:
        if (modifier.contains('left')) {
          return Icons.fork_left_rounded;
        }
        return Icons.fork_right_rounded;
      case ManeuverType.roundabout:
        return Icons.roundabout_right_rounded;
      case ManeuverType.merge:
        return Icons.merge_type_rounded;
      case ManeuverType.onRamp:
        return Icons.drive_eta_rounded;
      case ManeuverType.offRamp:
        return Icons.exit_to_app_rounded;
      case ManeuverType.ferry:
        return Icons.directions_boat_rounded;
      case ManeuverType.continueStraight:
        return Icons.straight_rounded;
      case ManeuverType.endOfRoad:
        return Icons.stop_rounded;
      case ManeuverType.newName:
        return Icons.straight_rounded;
      case ManeuverType.notification:
        return Icons.info_rounded;
    }
  }

  String _getInstructionText() {
    if (currentStep == null) return '';
    String instruction = currentStep!.instruction;
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), '');
    if (instruction.isEmpty) {
      switch (currentStep!.maneuverType) {
        case ManeuverType.depart:
          return 'Bắt đầu hành trình';
        case ManeuverType.arrive:
          return 'Đã đến đích';
        case ManeuverType.turn:
          final mod = currentStep!.maneuverModifier ?? '';
          if (mod.contains('left')) return 'Rẽ trái';
          if (mod.contains('right')) return 'Rẽ phải';
          return 'Rẽ';
        case ManeuverType.continueStraight:
          return 'Đi thẳng';
        default:
          return 'Tiếp tục';
      }
    }
    return instruction;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
