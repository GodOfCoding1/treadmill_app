import 'package:flutter/material.dart';

const double kWideBreakpoint = 600;
const double kContentMaxWidth = 560;
const double kSheetMaxWidth = 480;

bool isLandscape(BuildContext context) =>
    MediaQuery.orientationOf(context) == Orientation.landscape;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

class AdaptiveConstraints extends StatelessWidget {
  const AdaptiveConstraints({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class OrientationLayout extends StatelessWidget {
  const OrientationLayout({
    super.key,
    required this.portrait,
    required this.landscape,
  });

  final WidgetBuilder portrait;
  final WidgetBuilder landscape;

  @override
  Widget build(BuildContext context) {
    return isLandscape(context) ? landscape(context) : portrait(context);
  }
}

Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  if (!isLandscape(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
          child: builder(context),
        ),
      );
    },
  );
}
