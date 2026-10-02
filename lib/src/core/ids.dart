import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'ids.g.dart';

/// Indirection so tests get stable, readable row ids.
abstract interface class IdGenerator {
  String next();
}

class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  static const _uuid = Uuid();

  @override
  String next() => _uuid.v4();
}

class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator([this.prefix = 'id']);

  final String prefix;
  int _n = 0;

  @override
  String next() => '$prefix-${++_n}';
}

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidGenerator();
