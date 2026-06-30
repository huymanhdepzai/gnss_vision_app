import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/gnss_vision_icon.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../map/presentation/pages/map_home_page.dart';
import '../bloc/auth_bloc.dart';

import '../../../trip/presentation/controllers/trip_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          state.maybeWhen(
            authenticated: (user, isBiometricEnabled) {
              context.showModernSnackBar(
                message: 'Xin chào, ${user.displayName}',
                icon: Icons.check_circle_rounded,
                color: AppTheme.successColor,
              );
              
              _navigateToHome(context);
            },
            error: (message) {
              context.showModernSnackBar(
                message: message,
                icon: Icons.error_outline_rounded,
                color: AppTheme.errorDark,
              );
            },
            orElse: () {},
          );
        },
        builder: (context, state) {
          return ModernLoadingOverlay(
            isLoading: state.maybeWhen(loading: () => true, orElse: () => false),
            message: 'Đang kết nối...',
            child: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuthState state) {
    return Stack(
      children: [
        // Background with Particle Animation
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.primaryColor.withOpacity(context.isDark ? 0.2 : 0.18),
                  context.backgroundColor,
                ],
              ),
            ),
          ),
        ),
        
        // Moving White Circular Nodes
        Positioned.fill(
          child: ParticleBackground(
            particleColor: (context.isDark ? Colors.white : context.primaryColor).withOpacity(context.isDark ? 0.15 : 0.35),
            particleCount: 25,
          ),
        ),

        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding * 1.5),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Logo Section - Floating
                EntranceAnimation(
                  type: EntranceType.scaleFade,
                  duration: const Duration(milliseconds: 1200),
                  child: FloatingWidget(
                    verticalOffset: 15,
                    duration: const Duration(seconds: 4),
                    child: const AnimatedGnssVisionIcon(size: 160),
                  ),
                ),

                const SizedBox(height: UIConsts.spacing3XL),

                // Brand & Tagline - Modern Typography
                EntranceAnimation(
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      Text(
                        'GNSS VISION',
                        style: context.theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: context.primaryColor,
                        ),
                      ),
                      const SizedBox(height: UIConsts.spacingMD),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(UIConsts.radiusFull),
                        ),
                        child: Text(
                          'SMART NAVIGATION SYSTEM',
                          style: context.theme.textTheme.labelMedium?.copyWith(
                            color: context.primaryColor,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Login Action - Card with Glassmorphism feel
                EntranceAnimation(
                  delay: const Duration(milliseconds: 800),
                  type: EntranceType.fadeSlideUp,
                  child: Column(
                    children: [
                      ModernCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIConsts.spacingLG,
                          vertical: UIConsts.spacingXL,
                        ),
                        borderRadius: UIConsts.radius3XL,
                        hasGlow: true,
                        accentColor: context.primaryColor,
                        child: Row(
                          children: [
                            Expanded(
                              child: ModernButton(
                                text: 'Tiếp tục với Google',
                                iconWidget: SvgPicture.asset(
                                  'assets/icons/google-icon-logo-svgrepo-com.svg',
                                  width: 20,
                                  height: 20,
                                ),
                                onPressed: () {
                                  context.read<AuthBloc>().add(const AuthEvent.loginWithGoogleRequested());
                                },
                              ),
                            ),
                            const SizedBox(width: UIConsts.spacingMD),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  final isBiometricEnabled = state.maybeWhen(
                                    unauthenticated: (enabled) => enabled,
                                    authenticated: (_, enabled) => enabled,
                                    orElse: () => false,
                                  );

                                  if (isBiometricEnabled) {
                                    context.read<AuthBloc>().add(const AuthEvent.biometricLoginRequested());
                                  } else {
                                    context.showModernSnackBar(
                                      message: 'Vui lòng đăng nhập bằng Google trước để kích hoạt sinh trắc học.',
                                      icon: Icons.info_outline_rounded,
                                      color: context.primaryColor,
                                      isTop: true,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(UIConsts.radiusLG),
                                child: SizedBox(
                                  width: UIConsts.buttonHeightLG,
                                  height: UIConsts.buttonHeightLG,
                                  child: Icon(
                                    Icons.fingerprint_rounded,
                                    color: context.primaryColor,
                                    size: 48,
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

                const Spacer(flex: 3),

                // Footer - Clean & Elegant
                EntranceAnimation(
                  delay: const Duration(milliseconds: 1200),
                  type: EntranceType.fadeOnly,
                  child: Opacity(
                    opacity: 0.6,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFooterLink(context, 'Điều khoản', () => _showTermsDialog(context)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text('|', style: TextStyle(color: context.textSecondaryColor.withOpacity(0.5))),
                            ),
                            _buildFooterLink(context, 'Bảo mật', () => _showPrivacyDialog(context)),
                          ],
                        ),
                        const SizedBox(height: UIConsts.spacingSM),
                        Text(
                          '© 2026 GNSS Vision Team',
                          style: TextStyle(fontSize: 10, color: context.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: UIConsts.spacingLG),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog(BuildContext context) {
    context.showModernDialog(
      child: ModernDialog(
        title: 'Điều khoản sử dụng',
        primaryActionText: 'ĐÃ HIỂU',
        onPrimaryAction: () => Navigator.pop(context),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.screenHeight * 0.4),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection('1. Chấp thuận', 'Bằng việc sử dụng GNSS Vision, bạn đồng ý tuân thủ các điều khoản này.'),
                _buildPolicySection('2. Trách nhiệm', 'Ứng dụng cung cấp hỗ trợ dẫn đường. Người dùng phải chịu trách nhiệm an toàn khi tham gia giao thông.'),
                _buildPolicySection('3. Bản quyền', 'Mọi nội dung, thuật toán và thiết kế thuộc sở hữu của Nguyễn Huy Mạnh.'),
                _buildPolicySection('4. Giới hạn', 'Chúng tôi không chịu trách nhiệm cho các thiệt hại do sai lệch tín hiệu GPS hoặc sử dụng sai cách.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    context.showModernDialog(
      child: ModernDialog(
        title: 'Chính sách bảo mật',
        // icon: Icons.security_rounded,
        primaryActionText: 'ĐÃ HIỂU',
        onPrimaryAction: () => Navigator.pop(context),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.screenHeight * 0.4),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection('1. Thu thập dữ liệu', 'Chúng tôi thu thập dữ liệu vị trí GPS để cung cấp tính năng dẫn đường thời gian thực.'),
                _buildPolicySection('2. Thông tin cá nhân', 'Dữ liệu đăng nhập từ Google được sử dụng để đồng bộ hóa tài khoản của bạn.'),
                _buildPolicySection('3. Bảo mật', 'Dữ liệu của bạn được mã hóa và không bao giờ được chia sẻ cho bên thứ ba vì mục đích quảng cáo.'),
                _buildPolicySection('4. Quyền hạn', 'Bạn có quyền xóa dữ liệu hành trình hoặc yêu cầu ngừng thu thập vị trí bất cứ lúc nào.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UIConsts.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MapHomeScreenV2()),
    );
  }

  void _showEnableBiometricDialog(BuildContext context) {
    context.showModernDialog(
      child: ModernDialog(
        title: 'Kích hoạt Sinh trắc học',
        content: const Text(
          'Bạn có muốn sử dụng Vân tay/Khuôn mặt để đăng nhập nhanh hơn vào lần sau không?',
          textAlign: TextAlign.center,
        ),
        primaryActionText: 'KÍCH HOẠT',
        secondaryActionText: 'BỎ QUA',
        onPrimaryAction: () {
          context.read<AuthBloc>().add(const AuthEvent.toggleBiometricRequested(true));
          Navigator.pop(context);
          _navigateToHome(context);
        },
        onSecondaryAction: () {
          Navigator.pop(context);
          _navigateToHome(context);
        },
      ),
    );
  }
}