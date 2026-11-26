import 'package:flutter/material.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../theme/app_theme.dart';
import 'sensor_detail_sheet.dart';
import 'sensor_status_dot.dart';

/// 40 dp circular status button for the Home app bar header.
/// Hidden if no sensor node is paired.
class SensorStatusButton extends StatelessWidget {
  const SensorStatusButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watchSensorNode();
    if (controller == null || !controller.hasActiveNode || controller.state == NodeConnection.notPaired) {
      return const SizedBox.shrink();
    }

    final state = controller.state;
    final pct = controller.latest?.soil.percent;
    final pctStr = pct != null ? ', soil ${pct.toInt()} percent' : '';

    return Semantics(
      label: 'Sensor node, ${state.name}$pctStr',
      button: true,
      child: InkWell(
        onTap: () => SensorDetailSheet.show(context),
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.sensors_rounded,
                size: 22,
                color: AppColors.ink,
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cream, width: 2),
                  ),
                  child: SensorStatusDot(
                    state: state,
                    showLabel: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
