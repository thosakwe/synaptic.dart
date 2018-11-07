import 'dart:math';
import 'connection.dart';

var neurons = 0.0;

// sinh(x) = ( ex - e-x )/2
double _sinh(double x) {
  return ((pow(e, x)) - (pow(e, -x))) / 2;
}

// cosh(x) = ( e x + e -x )/2
double _cosh(double x) {
  return ((pow(e, x)) + (pow(e, -x))) / 2;
}

// tanh(x) = sinh(x)/cosh(x) = ( ex - e-x )/( ex + e-x )
double _tanh(double x) {
  return _sinh(x) / _cosh(x);
}

// Squashing functions
abstract class Squash {
  // eq. 5 & 5'
  static double logistic(double x, [bool derivate = false]) {
    var fx = 1 / (1 + exp(-x));
    if (!derivate) return fx;
    return fx * (1 - fx);
  }

  static double tanh(double x, [bool derivate = false]) {
    if (derivate) return (1 - pow(_tanh(x), 2)).toDouble();
    return _tanh(x);
  }

  static double identity(double x, [bool derivate = false]) {
    return derivate ? 1.0 : x;
  }

  static double hlim(double x, [bool derivate = false]) {
    return derivate ? 1.0 : x > 0.0 ? 1.0 : 0.0;
  }

  static double relu(double x, [bool derivate = false]) {
    if (derivate) return x > 0 ? 1.0 : 0.0;
    return x > 0 ? x : 0.0;
  }
}

class Neuron {
  double ID = uid();
  double derivative;
  double state = 0.0;
  double old = 0.0;
  double activation = 0.0;
  double bias = Connection.random.nextDouble() * .2 - 1;

  var _connections =
      new NeuronConnections(inputs: [], projected: [], gated: []);

  Connection _selfConnection;

  double Function(double, [bool]) squash = Squash.logistic;

  Neuron() {
    _selfConnection = new Connection(this, this, 0.0);
  }

  static double uid() {
    return neurons++;
  }

  static NeuronQuantity quantity() {
    return new NeuronQuantity(neurons: neurons, connections: connections);
  }

  // activate the neuron
  activate([double input]) {
    // activation from environment (for input neurons)
    if (input != null) {
      activation = input;
      derivative = 0.0;
      bias = 0.0;
      return activation;
    }

    // old state
    old = state;

    // eq.15
    state = _selfConnection.gain * _selfConnection.weight * state + bias;

    for (var input in _connections.inputs) {
      state += input.from.activation * input.weight * input.gain;
    }

    // eq.16
    activation = squash(state);

    // f'(s)
    derivative = squash(state, true);

    // update traces
    var influences = [];

    for (var id in trace.extended) {
      
    }
  }
}

class NeuronConnections {
  final List<Connection> inputs, projected, gated;

  NeuronConnections({this.inputs, this.projected, this.gated});
}

class NeuronQuantity {
  final double neurons;
  final int connections;

  const NeuronQuantity({this.neurons, this.connections});
}
