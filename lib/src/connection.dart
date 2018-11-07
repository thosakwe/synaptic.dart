import 'dart:math';

var connections = 0;

class Connection<T> {
  static final _rnd = new Random();

  // TODO: What is the type of these...?
  final T from, to;

  final ID = uid();

  double weight;

  var gain = 1;

  // TODO: gater?
  var gater;

  Connection(this.from, this.to, [this.weight]) {
    assert(from != null && to != null, 'Connection Error: Invalid neurons');
    weight ??= _rnd.nextDouble() * .2 - .1;
  }

  static int uid() => connections++;
}
