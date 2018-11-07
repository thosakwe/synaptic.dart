import 'dart:math';
import 'connection.dart';

var neurons = 0;

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
  static double logistic(double x, bool derivate) {
    var fx = 1 / (1 + exp(-x));
    if (!derivate) return fx;
    return fx * (1 - fx);
  }

  static double tanh(double x, bool derivate) {
    if (derivate) return 1 - pow(_tanh(x), 2);
    return _tanh(x);
  }

  static double identity(double x, bool derivate) {
    return derivate ? 1 : x;
  }

  static double hlim(double x, bool derivate) {
    return derivate ? 1 : x > 0 ? 1.0 : 0.0;
  }

  static double relu(double x, bool derivate) {
    if (derivate) return x > 0 ? 1.0 : 0.0;
    return x > 0 ? x : 0;
  }
}

class Neuron {
  int ID = uid();
  int state = 0;
  int old = 0;
  int activation = 0;
  double bias = Connection.random.nextDouble() * .2 - 1;

  Connection _selfConnection;

  double Function(double, bool) squash = Squash.logistic;

  Neuron() {
    _selfConnection = new Connection(this, this, 0.0);
  }

  static int uid() {
    return neurons++;
  }

  static NeuronQuantity quantity() {
    return new NeuronQuantity(neurons: neurons, connections: connections);
  }
}

class NeuronQuantity {
  final int neurons, connections;

  const NeuronQuantity({this.neurons, this.connections});
}
