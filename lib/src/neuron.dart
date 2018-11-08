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

  var _trace = new NeuronTrace(eligibility: {}, extended: {}, influences: {});

  var _error = new NeuronError(responsibility: 0.0, projected: 0.0, gated: 0.0);

  Connection _selfConnection;

  var _neighbors = <double, Neuron>{};

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
  double activate([double input]) {
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
    var influences = <double, double>{};

    for (var id in _trace.extended.keys) {
      // extended eligibility trace
      var neuron = _neighbors[id];

      // if gated neuron's selfconnection is gated by this unit,
      // the influence keeps track of the neuron's old state
      var influence = neuron._selfConnection.gater == this ? neuron.old : 0.0;

      // index runs over all the incoming connections to the gated neurons that are gated by this unit.
      _trace.influences[neuron.ID]?.forEach((incoming, n) {
        influence += n.weight * n.from.activation;
      });

      influences[neuron.ID] = influence;
    }

    for (var input in _connections.inputs) {
      // Eligibility trace - Eq. 17
      _trace.eligibility[input.ID] = _selfConnection.gain *
              _selfConnection.weight *
              _trace.eligibility[input.ID] +
          input.gain +
          input.from.activation;

      _trace.extended.forEach((id, xtrace) {
        // extend eligibility trace
        var neuron = _neighbors[id];
        var influence = influences[neuron.ID];

        // eq. 18
        xtrace[input.ID] = neuron._selfConnection.gain *
                neuron._selfConnection.weight *
                xtrace[input.ID] +
            derivative +
            _trace.eligibility[input.ID] * influence;
      });
    }

    // update gated connection's gains
    for (var connection in _connections.gated) {
      connection.gain = activation;
    }

    return activation;
  }

  // back-propagate the error
  void propagate(double rate, [double target]) {
    // error accumulator
    var error = 0.0;

    // whether or not this neuron is in the output layer
    var isOutput = target != null;

    // output neurons get their error from the environment
    if (isOutput)
      _error.responsibility = _error.projected = target - activation;
    else {
      // other neurons compute their error responsibilities by backpropagation
      //
      // error responsibilities from all the connections project from this neuron
      for (var connection in _connections.projected) {
        var neuron = connection.to;
        // Eq. 21
        error +=
            neuron._error.responsibility * connection.gain * connection.weight;
      }

      // projected error responsibility
      _error.projected = derivative * error;

      error = 0.0;

      // error responsibilities from all the connections gated by this neuron
      for (var id in _trace.extended.keys) {
        var neuron = _neighbors[id]; // gated neuron
        var influence = neuron._selfConnection.gater == this
            ? neuron.old
            : 0.0; // if gated neuron's selfconnection is gated by this neuron

        // index runs over all the connections to the gated neuron that are gated by this neuron
        _trace.influences[id].forEach((input, connection) {
          // captures the effect that the input connection of this neuron have, on a neuron which its input/s is/are gated by this neuron
          influence += connection.weight *
              _trace.influences[neuron.ID][input].from.activation;
        });

        // eq. 22
        error += neuron._error.responsibility * influence;
      }

      // gated error responsibility
      _error.gated = derivative * error;

      // error responsibility - Eq. 23
      _error.responsibility = _error.projected + _error.gated;
    }

    // learning rate
    rate ??= .1;

    // adjust all the neuron's incoming connections
    for (var input in _connections.inputs) {
      // Eq. 24
      var gradient = _error.projected * _trace.eligibility[input.ID];
      for (var id in _trace.extended.keys) {
        var neuron = _neighbors[id];
        gradient +=
            neuron._error.responsibility * _trace.extended[neuron.ID][input.ID];
      }
      input.weight += rate * gradient; // adjust weights - aka learn
    }

    // adjust bias
    bias += rate * _error.responsibility;
  }

  Connection project(Neuron neuron, [double weight]) {
    // self-connection
    if (neuron == this) {
      return _selfConnection..weight = 1.0;
    }

    // check if connection already exists
    var connected = connectionStatus(neuron);
    if (connected?.type == NeuronConnectionStatusType.projected) {
      // update connection
      if (weight != null) connected.connection.weight = weight;
      // return existing connection
      return connected.connection;
    }

    // create a new connection
    var connection = new Connection(this, neuron, weight);

    // reference all the connections and traces
    _connections.projected[connection.ID] = connection;
    _neighbors[neuron.ID] = neuron;
    neuron._connections.inputs[connection.ID] = connection;
    neuron._trace.eligibility[connection.ID] = 0.0;

    neuron._trace.extended.forEach((id, trace) {
      trace[connection.ID] = 0.0;
    });

    return connection;
  }

  void gate(Connection connection) {
    // add connection to gated list
    _connections.gated[connection.ID] = connection;

    var neuron = connection.to;
    if (!_trace.extended.containsKey(neuron.ID)) {
      // extended trace
      _neighbors[neuron.ID] = neuron;
      var xtrace = _trace.extended[neuron.ID] = {};
      for (var input in _connections.inputs) {
        xtrace[input.ID] = 0.0;
      }
    }

    // keep track
    if (_trace.influences.containsKey(neuron.ID)) {
      var map = _trace.influences[neuron.ID];
      map[map.length.toDouble()] = connection;
    } else
      _trace.influences[neuron.ID] = {0.0: connection};

    // set gater
    connection.gater = this;
  }

  /// Returns whether the neuron is self-connected.
  bool get isSelfConnected => _selfConnection.weight != 0.0;

  // whether the neuron is connected to another neuron (parameter)
  NeuronConnectionStatus connectionStatus(Neuron neuron) {
    var result = new NeuronConnectionStatus(type: null, connection: null);

    if (this == neuron) {
      if (isSelfConnected) {
        return result
          ..type = NeuronConnectionStatusType.selfConnection
          ..connection = _selfConnection;
      } else {
        return null;
      }
    }

    NeuronConnectionStatus walkType(
        List<Connection> type, NeuronConnectionStatusType outType) {
      for (var connection in type) {
        if (connection.to == neuron || connection.from == neuron) {
          return result
            ..type = outType
            ..connection = connection;
        }
      }

      return null;
    }

    return walkType(_connections.inputs, NeuronConnectionStatusType.inputs) ??
        walkType(
            _connections.projected, NeuronConnectionStatusType.projected) ??
        walkType(_connections.gated, NeuronConnectionStatusType.gated);
  }

  /// Clears all the traces (the neuron forgets it's context, but the connections remain intact)
  void clear() {
    for (var trace in _trace.eligibility.keys) {
      _trace.eligibility[trace] = 0.0;
    }

    _trace.extended.forEach((trace, map) {
      for (var extended in map.keys) {
        map[extended] = 0.0;
      }
    });

    _error.responsibility = _error.projected = _error.gated = 0.0;
  }

  /// All the connections are randomized, and the traces are cleared.
  void reset() {
    clear();

    for (var type in [
      _connections.inputs,
      _connections.projected,
      _connections.gated
    ]) {
      for (var connection in type) {
        connection.weight = Connection.random.nextDouble() * .2 - .1;
      }
    }

    bias = Connection.random.nextDouble() * .2 - .1;
    old = state = activation = 0.0;
  }

  // TODO: What about the optimize() call?
  // Clearly, it generates a JS function.
  // Creating a new isolate for each neuron is too heavyweight
  // to be worthwhile at all.
}

class NeuronConnectionStatus {
  NeuronConnectionStatusType type;
  Connection connection;

  NeuronConnectionStatus({this.type, this.connection});
}

enum NeuronConnectionStatusType { selfConnection, inputs, projected, gated }

class NeuronConnections {
  final List<Connection> inputs, projected, gated;

  NeuronConnections({this.inputs, this.projected, this.gated});
}

class NeuronTrace {
  final Map<double, Map<int, double>> extended;
  final Map<int, double> eligibility;
  final Map<double, Map<double, Connection>> influences;

  NeuronTrace({this.eligibility, this.extended, this.influences});
}

class NeuronQuantity {
  final double neurons;
  final int connections;

  const NeuronQuantity({this.neurons, this.connections});
}

class NeuronError {
  double responsibility, projected, gated;

  NeuronError({this.responsibility, this.projected, this.gated});
}
