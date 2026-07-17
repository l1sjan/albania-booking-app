import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ShimmerListingsSliver extends StatefulWidget {
  const ShimmerListingsSliver({super.key});

  @override
  State<ShimmerListingsSliver> createState() => _ShimmerListingsSliverState();
}

class _ShimmerListingsSliverState extends State<ShimmerListingsSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = (_controller.value * 4) - 2;

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 124),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(position - 1, 0),
                          end: Alignment(position + 1, 0),
                          colors: [
                            const Color(0xFFE6E0D9),
                            AppPalette.warmSurface,
                            const Color(0xFFE6E0D9),
                          ],
                          stops: const [0.2, 0.5, 0.8],
                        ).createShader(bounds);
                      },
                      child: const _ListingSkeleton(),
                    ),
                  ),
                ),
              );
            }, childCount: 3),
          ),
        );
      },
    );
  }
}

class _ListingSkeleton extends StatelessWidget {
  const _ListingSkeleton();

  @override
  Widget build(BuildContext context) {
    const fill = AppPalette.warmField;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppPalette.warmSurface,
          border: Border.fromBorderSide(
            BorderSide(color: AppPalette.warmOutline),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 620) {
              return const SizedBox(
                height: 292,
                child: Row(
                  children: [
                    Expanded(flex: 4, child: ColoredBox(color: fill)),
                    Expanded(flex: 5, child: _SkeletonDetails(fill: fill)),
                  ],
                ),
              );
            }

            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ColoredBox(color: fill),
                ),
                _SkeletonDetails(fill: fill),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonDetails extends StatelessWidget {
  const _SkeletonDetails({required this.fill});

  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SkeletonLine(width: 240, height: 24, color: fill),
          const SizedBox(height: 12),
          _SkeletonLine(width: 170, height: 16, color: fill),
          const SizedBox(height: 16),
          _SkeletonLine(width: double.infinity, height: 14, color: fill),
          const SizedBox(height: 8),
          _SkeletonLine(width: 280, height: 14, color: fill),
          const SizedBox(height: 22),
          _SkeletonLine(width: 130, height: 22, color: fill),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
