import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/gnss_vision_icon.dart';
import '../../../../core/widgets/modern_animations.dart';
import '../../../../core/widgets/modern_ui.dart';
import '../../../map/presentation/pages/map_home_page.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          state.maybeWhen(
            authenticated: (user) {
              context.showModernSnackBar(
                message: 'Xin chào, ${user.displayName}',
                icon: Icons.check_circle_rounded,
                color: AppTheme.successColor,
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MapHomeScreenV2()),
              );
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
            child: _buildBody(context),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.2,
          colors: [
            context.primaryColor.withOpacity(context.isDark ? 0.12 : 0.08),
            context.backgroundColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding * 1.5),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo Section - Clean & Balanced
              const EntranceAnimation(
                type: EntranceType.scaleFade,
                duration: Duration(milliseconds: 1200),
                child: AnimatedGnssVisionIcon(size: 150),
              ),

              const SizedBox(height: UIConsts.spacing2XL),

              // Brand & Tagline - Minimalist
              EntranceAnimation(
                delay: const Duration(milliseconds: 400),
                child: Column(
                  children: [
                    Text(
                      'GNSS VISION',
                      style: context.theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: UIConsts.spacingSM),
                    Text(
                      'SMART NAVIGATION SYSTEM',
                      style: context.theme.textTheme.labelMedium?.copyWith(
                        color: context.textSecondaryColor,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Login Action - High focus, zero clutter
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
                      borderRadius: UIConsts.radius2XL,
                      child: ModernButton(
                        text: 'Tiếp tục với Google',
                        icon: Icons.login_rounded,
                        onPressed: () {
                          context.read<AuthBloc>().add(const AuthEvent.loginWithGoogleRequested());
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Footer - Discreet
              EntranceAnimation(
                delay: const Duration(milliseconds: 1200),
                type: EntranceType.fadeOnly,
                child: Opacity(
                  opacity: 0.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFooterLink('Điều khoản'),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('•', style: TextStyle(fontSize: 10)),
                      ),
                      _buildFooterLink('Bảo mật'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UIConsts.spacingLG),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return GestureDetector(
      onTap: () {},
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
}