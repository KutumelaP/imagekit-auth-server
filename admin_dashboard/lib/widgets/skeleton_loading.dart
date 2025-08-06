import 'package:flutter/material.dart';

class SkeletonLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Duration duration;

  const SkeletonLoading({
    Key? key,
    required this.child,
    required this.isLoading,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEBEBF4),
                Color(0xFFF4F4F4),
                Color(0xFFEBEBF4),
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
              transform: GradientRotation(0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? child;

  const SkeletonCard({
    Key? key,
    this.width,
    this.height,
    this.borderRadius,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonText({
    Key? key,
    required this.width,
    this.height = 16,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

class SkeletonStatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: 24,
                    height: 24,
                    color: Colors.grey[300],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SkeletonText(width: 80, height: 28),
            const SizedBox(height: 4),
            SkeletonText(width: 120, height: 14),
          ],
        ),
      ),
    );
  }
}

class SkeletonActivityItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              width: 18,
              height: 18,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: double.infinity, height: 14),
                const SizedBox(height: 4),
                SkeletonText(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonQuickActionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 32,
                height: 32,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 12),
            SkeletonText(width: 100, height: 14),
          ],
        ),
      ),
    );
  }
}

class SkeletonDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header Skeleton
          SkeletonCard(
            height: 120,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonText(width: 250, height: 24),
                        const SizedBox(height: 8),
                        SkeletonText(width: 200, height: 16),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Grid Skeleton
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: List.generate(4, (index) => SkeletonStatCard()),
          ),
          const SizedBox(height: 24),
          
          // Charts Row Skeleton
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SkeletonCard(height: 350),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SkeletonCard(height: 350),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Actions Skeleton
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonText(width: 150, height: 20),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: List.generate(6, (index) => SkeletonQuickActionCard()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonTable extends StatelessWidget {
  final int rows;
  final int columns;

  const SkeletonTable({
    Key? key,
    this.rows = 5,
    this.columns = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: List.generate(
                columns,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SkeletonText(width: double.infinity, height: 16),
                  ),
                ),
              ),
            ),
            const Divider(),
            // Rows
            ...List.generate(
              rows,
              (rowIndex) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: List.generate(
                    columns,
                    (colIndex) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: SkeletonText(
                          width: double.infinity,
                          height: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 