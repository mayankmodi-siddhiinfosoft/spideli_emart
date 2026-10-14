import 'dart:async';

import 'package:customer/utils/shared_latest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one source for every listener; a late listener gets the latest value', () async {
    int opened = 0;
    final source = StreamController<int>.broadcast();
    final shared = SharedLatest<int>(() {
      opened++;
      return source.stream;
    });
    final a = <int>[], b = <int>[];
    final sa = shared.stream.listen(a.add);
    source.add(1);
    await pumpEventQueue();
    final sb = shared.stream.listen(b.add);
    await pumpEventQueue();
    expect(b, [1], reason: 'a later listener starts from the latest value');
    source.add(2);
    await pumpEventQueue();
    expect(a, [1, 2]);
    expect(b, [1, 2]);
    expect(opened, 1, reason: 'the source is opened once');
    await sa.cancel();
    expect(shared.isOpen, isTrue);
    await sb.cancel();
    expect(shared.isOpen, isFalse, reason: 'closed when the last listener leaves');
    await source.close();
  });

  test('the stream is the same instance on every read', () {
    final shared = SharedLatest<int>(() => const Stream<int>.empty());
    expect(identical(shared.stream, shared.stream), isTrue);
  });

  test('an error reaches current and later listeners', () async {
    final source = StreamController<int>.broadcast();
    final shared = SharedLatest<int>(() => source.stream);
    final errors = <Object>[];
    final s1 = shared.stream.listen((_) {}, onError: errors.add);
    source.addError(StateError('offline'));
    await pumpEventQueue();
    final s2 = shared.stream.listen((_) {}, onError: errors.add);
    await pumpEventQueue();
    expect(errors.length, 2);
    await s1.cancel();
    await s2.cancel();
    await source.close();
  });

  test('retry opens the source again after an error, for the same listeners', () async {
    int opened = 0;
    final shared = SharedLatest<int>(() {
      opened++;
      return opened == 1 ? Stream<int>.error('permission-denied') : Stream<int>.value(7);
    });
    final values = <int>[];
    final errors = <Object>[];
    final sub = shared.stream.listen(values.add, onError: errors.add);
    await pumpEventQueue();
    expect(errors, ['permission-denied']);
    shared.retry();
    await pumpEventQueue();
    expect(values, [7]);
    expect(opened, 2);
    shared.retry();
    expect(opened, 2, reason: 'nothing to retry while it works');
    await sub.cancel();
  });
}
