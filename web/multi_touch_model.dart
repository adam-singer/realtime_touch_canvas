part of realtime_touch_canvas;

class ValueChangedEvent {
  var property;
  var newValue;
  var oldValue;
  ValueChangedEvent(this.property, this.newValue, this.oldValue);
}

class MultiTouchModel {
  Logger _logger = new Logger("MultiTouchModel");
  js.Proxy _doc;
  js.Proxy get document => _doc;
  bool newModel;

  List _defaultLines = [];
  String _linesName = "lines";
  js.Proxy _lines;
  
  void clear() {
    if (_lines != null) {
      js.scoped(() {
        _lines.clear();
      });
    }
  }
  
  void addLine(Line line) {
    
    _logger.fine("line.toJson() = ${line.toJson()}");
    
    js.scoped(() {
      _lines.push(line.toJson());
    });
    
    _logger.fine("leaving line.toJson() = ${line.toJson()}");
  }

  void _linesOnRemovedValuesChangedEvent(removedValues) {
    realtimeTouchCanvas.clear();
  }
  
  void _linesOnAddValuesChangedEvent(addedValue) {
    _logger.fine("_linesOnAddValuesChangedEvent addedValue = ${addedValue}");
    _logger.fine("_linesOnAddValuesChangedEvent addedValue.index = ${addedValue.index}");
    var insertedLine = _lines.get(addedValue.index);
    var line = new Line.fromJson(insertedLine);
    realtimeTouchCanvas.move(line, line.moveX, line.moveY);
  }


  MultiTouchModel({bool this.newModel: true});

  void initializeModel(js.Proxy model) {
    _logger.fine("creating new model $newModel");

    if (newModel) {
      _createNewModel(model);
    }
  }

  void onFileLoaded(js.Proxy doc) {
    _bindModel(doc);
    realtimeTouchCanvas = new RealtimeTouchCanvas();
    realtimeTouchCanvas.run();
    /// Fill in previous lines if they exist.
    if (!newModel && _lines != null) {
      for (int i = 0; i < _lines.length; i++) {
        var jsonLine = _lines.get(i);
        var line = new Line.fromJson(jsonLine);
        realtimeTouchCanvas.move(line, line.moveX, line.moveY);
      }
    }
    
    _logger.fine("onFileLoaded leaving");
  }

  void _createNewModel(js.Proxy model) {
    _logger.fine("_createNewModel adding list");
    var list = model.createList(js.array(_defaultLines));
    model.getRoot().set(_linesName, list);
  }

  void _bindModel(js.Proxy doc) {
    _doc = doc;
    js.retain(_doc);

    _logger.fine("retained _doc");

    _lines = doc.getModel().getRoot().get(_linesName);

    _lines.addEventListener(gapi.drive.realtime.EventType.VALUES_ADDED, new js.Callback.many(_linesOnAddValuesChangedEvent));
    _lines.addEventListener(gapi.drive.realtime.EventType.VALUES_REMOVED, new js.Callback.many(_linesOnRemovedValuesChangedEvent));
    js.retain(_lines);
    _logger.fine("retained _lines");
  }

  void close() {
    js.scoped((){
      js.release(_doc);
    });
  }
}


class Line {
  int x;
  int y;
  String color;
  int moveX = 0;
  int moveY = 0;
  Line([this.x=0,this.y=0,this.color="red"]);
  Line.fromJson(String json) {
    // TODO(adam): use the new serilizer
    Map map = JSON.parse(json);
    if (map.containsKey("x")) {
      this.x = map["x"];
    }

    if (map.containsKey("y")) {
      this.y = map["y"];
    }

    if (map.containsKey("color")) {
      this.color = map["color"];
    }

    if (map.containsKey("moveX")) {
      this.moveX = map["moveX"];
    }

    if (map.containsKey("moveY")) {
      this.moveY = map["moveY"];
    }
  }

  String toJson() => JSON.stringify({ "x": x, "y": y, "color": color, "moveX": moveX, "moveY": moveY});

}

