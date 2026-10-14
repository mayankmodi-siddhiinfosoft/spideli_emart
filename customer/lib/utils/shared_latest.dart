import 'dart:async';

/// One subscription to a source stream, shared by every listener: each new
/// listener (a StreamBuilder built later, another tab) gets the latest value
/// at once instead of waiting, and the source opens once instead of once per
/// widget. The source is closed when the last listener leaves.
///
/// [stream] is the same instance on every read, so a widget that rebuilds
/// with it does not resubscribe.
class SharedLatest<T> {
  SharedLatest(this._open);

  final Stream<T> Function() _open;
  final List<MultiStreamController<T>> _listeners = [];
  StreamSubscription<T>? _source;
  bool _hasValue = false;
  T? _latest;
  (Object, StackTrace)? _error;

  /// The shared stream (multi-subscription).
  late final Stream<T> stream = Stream<T>.multi((controller) {
    _listeners.add(controller);
    if (_hasValue) {
      controller.add(_latest as T);
    } else if (_error != null) {
      controller.addError(_error!.$1, _error!.$2);
    }
    _source ??= _subscribe();
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isEmpty) {
        _source?.cancel();
        _source = null;
        _hasValue = false;
        _latest = null;
        _error = null;
      }
    };
  });

  StreamSubscription<T> _subscribe() => _open().listen(
        (value) {
          _hasValue = true;
          _latest = value;
          _error = null;
          for (final l in List.of(_listeners)) {
            l.add(value);
          }
        },
        onError: (Object e, StackTrace s) {
          _error = (e, s);
          for (final l in List.of(_listeners)) {
            l.addError(e, s);
          }
        },
      );

  /// Opens the source again for the current listeners, after it failed (a
  /// Firestore query ends with its error): the Retry of a screen. Nothing
  /// happens while it works or when nobody listens.
  void retry() {
    if (_error == null || _listeners.isEmpty) return;
    _source?.cancel();
    _error = null;
    _source = _subscribe();
  }

  /// Whether the source is open (someone listens).
  bool get isOpen => _source != null;
}
