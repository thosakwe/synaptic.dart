import 'layer.dart';

/// represents a connection from one layer to another, and keeps track of its weight and gain
var layerConnections = 0;

class LayerConnection {
  final Layer from, to;
}
