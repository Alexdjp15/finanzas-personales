import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../domain/models/models.dart';
import '../../../domain/services/dashboard_visuals.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

enum DistributionMode { pockets, accounts }

/// Distinct hues that stay legible on both the dark and the light palette.
const List<Color> _sliceColors = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFA855F7),
  Color(0xFFEF4444),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF84CC16),
];

Color distributionColorAt(int index) => _sliceColors[index % _sliceColors.length];

/// Interactive donut chart. Hover/tap a wedge to highlight it and read its
/// amount and percentage in the centre; the legend carries tooltips too.
class PocketDistributionChart extends StatefulWidget {
  const PocketDistributionChart({
    super.key,
    required this.accounts,
    required this.pockets,
  });

  final List<Account> accounts;
  final List<Pocket> pockets;

  @override
  State<PocketDistributionChart> createState() => _PocketDistributionChartState();
}

class _PocketDistributionChartState extends State<PocketDistributionChart> {
  DistributionMode _mode = DistributionMode.pockets;
  int? _touchedIndex;

  DistributionResult get _result => _mode == DistributionMode.pockets
      ? DashboardVisuals.byPocket(widget.pockets)
      : DashboardVisuals.byAccount(widget.accounts, widget.pockets);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final result = _result;

    return Container(
      decoration: AppDecorations.card(
        backgroundColor: colors.surfaceCard,
        borderColor: colors.borderSubtle,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Text(
                'Distribución del Patrimonio',
                style: AppTypography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              SegmentedButton<DistributionMode>(
                key: const Key('distribution_mode_selector'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DistributionMode.pockets, label: Text('Por Bolsillos')),
                  ButtonSegment(value: DistributionMode.accounts, label: Text('Por Cuentas Banco')),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) => setState(() {
                  _mode = selection.first;
                  _touchedIndex = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: result.isEmpty
                ? Padding(
                    key: const ValueKey('distribution_empty'),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aún no hay saldos positivos para graficar.',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  )
                : _buildChartBody(context, colors, result),
          ),
          if (result.excludedNegativeCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${result.excludedNegativeCount} elemento(s) con saldo cero o negativo no se muestran en el gráfico.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartBody(BuildContext context, AppPalette colors, DistributionResult result) {
    final touched = (_touchedIndex != null && _touchedIndex! < result.slices.length)
        ? result.slices[_touchedIndex!]
        : null;

    final chart = SizedBox(
      key: ValueKey('distribution_chart_${_mode.name}'),
      height: 240,
      width: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 70,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index = response?.touchedSection?.touchedSectionIndex;
                  final next = (event.isInterestedForInteractions && index != null && index >= 0) ? index : null;
                  if (next != _touchedIndex) setState(() => _touchedIndex = next);
                },
              ),
              sections: [
                for (var i = 0; i < result.slices.length; i++)
                  PieChartSectionData(
                    value: result.slices[i].amount.toDouble(),
                    color: distributionColorAt(i),
                    radius: i == _touchedIndex ? 58 : 48,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touched?.label ?? 'Total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.cop(touched?.amount ?? result.total),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                ),
                if (touched != null)
                  Text(
                    '${touched.percentage.toStringAsFixed(1)} %',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.brandAccent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final legend = Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (var i = 0; i < result.slices.length; i++)
          MouseRegion(
            onEnter: (_) => setState(() => _touchedIndex = i),
            onExit: (_) => setState(() => _touchedIndex = null),
            child: Tooltip(
              message:
                  '${result.slices[i].label}: ${Formatters.cop(result.slices[i].amount)} (${result.slices[i].percentage.toStringAsFixed(1)} %)',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: distributionColorAt(i), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      '${result.slices[i].label} · ${result.slices[i].percentage.toStringAsFixed(0)} %',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == _touchedIndex ? FontWeight.w700 : FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      key: ValueKey('distribution_body_${_mode.name}'),
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              chart,
              const SizedBox(width: 32),
              Expanded(child: legend),
            ],
          );
        }
        return Column(children: [chart, const SizedBox(height: 16), legend]);
      },
    );
  }
}
