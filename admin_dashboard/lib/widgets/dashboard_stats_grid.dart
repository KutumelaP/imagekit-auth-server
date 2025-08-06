import 'package:flutter/material.dart';

class DashboardStatsGrid extends StatelessWidget {
  final BuildContext context;
  final int statValue;
  const DashboardStatsGrid(this.context, this.statValue, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual stats grid if needed
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Card(
          child: Center(child: Text('Stat 1: $statValue')),
        ),
        Card(
          child: Center(child: Text('Stat 2: $statValue')),
        ),
      ],
    );
  }
} 