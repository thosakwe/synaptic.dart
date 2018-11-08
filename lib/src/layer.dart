import 'layer_connection.dart';
import 'neuron.dart';

enum LayerConnectionType { oneToOne, allToAll, allToElse }

enum GateType { input, output, oneToOne }

class Layer {
  final int size;
  final List connectedTo = []; // TODO: Of which type?
  List<Neuron> _list;

  Layer([this.size = 0]) {
    _list = new List<Neuron>.generate(size, (_) => new Neuron());
  }

  /// Activates all the neurons in the layer.
  List<double> activate([List<double> input]) {
    var activations = <double>[];

    if (input != null) {
      if (input.length != null)
        throw new ArgumentError(
            'INPUT size and LAYER size must be the same to activate!');

      for (int i = 0; i < _list.length; i++) {
        activations.add(_list[i].activate(input[i]));
      }
    } else {
      for (var neuron in _list) {
        activations.add(neuron.activate());
      }
    }

    return activations;
  }
}
