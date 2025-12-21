import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../notifiers/unit_settings_notifier.dart';
import 'package:provider/provider.dart';

class WeatherFrogIconWidget extends StatelessWidget {
  final String? iconUrl;

  const WeatherFrogIconWidget({super.key, required this.iconUrl});

  @override
  Widget build(BuildContext context) {
    if (iconUrl == null) {
      return const Text("");
    }

    final isShowFrog = context.read<UnitSettingsNotifier>().showFrog;

    final int targetWidth = (MediaQuery.of(context).size.width * 0.9).round();

    return isShowFrog
        ? RepaintBoundary(
            child: iconUrl!.startsWith('http')
                ? Image.network(
                    iconUrl!,
                    cacheWidth: targetWidth,
                    filterQuality: FilterQuality.low,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Text("loading_text".tr());
                    },
                  )
                : Image.asset(
                    iconUrl!,
                    cacheWidth: targetWidth,
                    filterQuality: FilterQuality.low,
                  ),
          )
        : SizedBox.shrink();
  }
}
