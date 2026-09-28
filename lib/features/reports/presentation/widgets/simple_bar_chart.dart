import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SimpleBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final Color? barColor;
  final double maxHeight;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.barColor,
    this.maxHeight = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'Aucune donnée',
          style: TextStyle(color: AppColors.textSec(context)),
        ),
      );
    }

    final maxValue = data.fold<double>(
      0,
      (max, item) =>
          (item['revenue'] as double) > max ? item['revenue'] as double : max,
    );

    final color = barColor ?? AppColors.green(context);

    return SizedBox(
      height: maxHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((item) {
          final revenue = item['revenue'] as double;
          final date = item['date'] as DateTime;
          final ratio = maxValue > 0 ? revenue / maxValue : 0.0;
          final barHeight = ratio * maxHeight;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (revenue > 0)
                  Text(
                    _formatShort(revenue),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSec(context),
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: barHeight < 4 ? 4 : barHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDay(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSec(context),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDay(DateTime date) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[date.weekday - 1];
  }

  String _formatShort(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}
