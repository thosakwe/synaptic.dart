import 'dart:math';
import 'neuron.dart';

var connections = 0;

class Connection {
  static final random = new Random();

  final Neuron from, to;

  final ID = uid();

  double weight;

  var gain = 1;

  // TODO: gater?
  var gater;

  Connection(this.from, this.to, [this.weight]) {
    assert(from != null && to != null, 'Connection Error: Invalid neurons');
    weight ??= random.nextDouble() * .2 - .1;
  }

  static int uid() => connections++;
}
