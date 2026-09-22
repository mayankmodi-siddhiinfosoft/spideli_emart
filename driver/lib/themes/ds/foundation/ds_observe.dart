import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Rebuilds whenever an observable (`.obs`) read inside [builder] changes,
/// like `Obx` — but reading no observable is allowed (it just never rebuilds)
/// instead of throwing "improper use of GetX".
///
/// Use it where content is built lazily (e.g. [DsAsync]'s `builder`) or where
/// a child widget reads controller state in its own `build`, so those reads
/// are tracked by an observer that runs at the same time as the read.
class DsObserve extends StatefulWidget {
  final WidgetBuilder builder;

  const DsObserve({super.key, required this.builder});

  @override
  State<DsObserve> createState() => _DsObserveState();
}

class _DsObserveState extends State<DsObserve> {
  final RxNotifier _observer = RxNotifier();
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _observer.listen((_) {
      if (mounted) setState(() {});
    }, cancelOnError: false);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _observer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = RxInterface.proxy;
    RxInterface.proxy = _observer;
    try {
      return widget.builder(context);
    } finally {
      RxInterface.proxy = previous;
    }
  }
}
