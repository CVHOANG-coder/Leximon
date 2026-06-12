import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/lottie/dotlottie_decoder.dart';
import '../../../core/routes/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    // Dự phòng: nếu animation tải lỗi / quá lâu thì vẫn vào home.
    Future.delayed(const Duration(seconds: 6), _goHome);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(RouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    // Nền đen đồng màu với hoạt ảnh logo (hoạt ảnh có nền đen).
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.72,
              height: MediaQuery.of(context).size.width * 0.72,
              child: Lottie.asset(
                'assets/lotties/logo_animation.lottie',
                controller: _controller,
                fit: BoxFit.contain,
                decoder: dotLottieDecoder,
                onLoaded: (composition) {
                  // Chạy một lần đúng theo độ dài animation rồi vào home.
                  _controller
                    ..duration = composition.duration
                    ..forward().whenComplete(_goHome);
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFC542), // sunshine gold cho nổi trên nền đen
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              AppConstants.tagline,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
