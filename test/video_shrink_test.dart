import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/video_shrink.dart';

/// Video evidence is at most 1 MB (19 Oct 2026). The encoder is Android's;
/// here a fake stands in for it and answers the size it "made".
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('shrink'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A fake encoder answering [sizes] in turn; writes each output so the
  /// tidy-up of a too-big attempt is visible.
  ({Compress compress, List<int> rates, List<String> outs}) fake(List<int> sizes) {
    final rates = <int>[], outs = <String>[];
    Future<int> compress(String input, String output, int rate) async {
      rates.add(rate);
      outs.add(output);
      File(output).writeAsStringSync('clip');
      return sizes[rates.length - 1];
    }

    return (compress: compress, rates: rates, outs: outs);
  }

  test('a clip that fits on the first try is kept as is', () async {
    final f = fake([900 * 1024]);
    final out = await shrinkVideo('in.mp4', tmp.path, compress: f.compress);
    expect(out, f.outs.single);
    expect(f.rates, [videoBitrates.first]);
  });

  test('an encoder that overshoots gets one more try at a lower bitrate', () async {
    final f = fake([maxVideoBytes + 1, 700 * 1024]);
    final out = await shrinkVideo('in.mp4', tmp.path, compress: f.compress);
    expect(out, f.outs.last);
    expect(f.rates, videoBitrates);
    expect(File(f.outs.first).existsSync(), isFalse, reason: 'the attempt that missed is deleted');
  });

  test('a clip no attempt fits is refused, and nothing is left behind', () async {
    final f = fake([3 * maxVideoBytes, 2 * maxVideoBytes]);
    expect(await shrinkVideo('in.mp4', tmp.path, compress: f.compress), isNull);
    expect(tmp.listSync(), isEmpty);
  });

  test('exactly 1 MB is allowed, as the API allows it', () async {
    final f = fake([maxVideoBytes]);
    expect(await shrinkVideo('in.mp4', tmp.path, compress: f.compress), isNotNull);
  });

  test('an encoder error reaches the caller, which shows it', () async {
    Future<int> broken(String i, String o, int r) async => throw Exception('no encoder');
    expect(shrinkVideo('in.mp4', tmp.path, compress: broken), throwsException);
  });

  test('the budget: 20 s at the first bitrate plus sound fits under 1 MB', () {
    const soundBitrate = 48000;
    final bytes = maxVideoSeconds * (videoBitrates.first + soundBitrate) / 8;
    expect(bytes, lessThan(maxVideoBytes * 0.95));
  });
}
