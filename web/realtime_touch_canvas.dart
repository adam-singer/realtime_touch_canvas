library realtime_touch_canvas;
import 'dart:html';
import 'dart:math' as Math;
import 'rtclient.dart';
import 'drive_v2_schema.dart' as drive;
import 'dart:json' as JSON;
import 'package:js/js.dart' as js;
import 'package:logging/logging.dart';

part 'logger_setup.dart';
part 'multi_touch_model.dart';

RealtimeTouchCanvas realtimeTouchCanvas;
MultiTouchModel model;
RealTimeLoader rtl;

class RealtimeTouchCanvas {
  Map lines;
  List colors = const["red", "green", "yellow", "blue", "magenta", "orangered"];
  CanvasElement canvas;
  CanvasRenderingContext2D context;
  Math.Random random = new Math.Random();

  int mouseId = 0;
  bool mouseMoving = false;

  void run() {
    canvas = new CanvasElement();
    context = canvas.getContext("2d");
    DivElement div = document.query("#div");
    div.children.add(canvas);
    canvas.width = div.scrollWidth;
    canvas.height= div.scrollHeight;

    context.lineWidth = 20;
    context.lineCap = "round";
    lines = {};
    canvas.onTouchStart.listen(preDraw);
    canvas.onTouchMove.listen(draw);

    // Used for testing on non-touch
    canvas.onMouseDown.listen(preDrawMouse);
    canvas.onMouseMove.listen(drawMouse);
    canvas.onMouseUp.listen(drawMouseStop);
  }

  clear() => context.clearRect(0, 0, canvas.width, canvas.height);
 
  
  preDraw(TouchEvent event) {
    event.touches.forEach((Touch t) {
       var id = t.identifier;
       var mycolor = colors[(random.nextDouble()*colors.length).floor().toInt()];
       lines[id] = new Line(t.page.x, t.page.y, mycolor);
    });

    event.preventDefault();
  }

  draw(TouchEvent event) {
    event.touches.forEach((Touch t) {
      var id = t.identifier;
      var moveX = t.page.x - lines[id].x;
      var moveY = t.page.y - lines[id].y;
      move(lines[id], moveX, moveY);
      lines[id].moveX = moveX;
      lines[id].moveY = moveY;
      model.addLine(lines[id]);
      
      lines[id].x = lines[id].x + moveX;
      lines[id].y = lines[id].y + moveY;
    });

    event.preventDefault();
  }

  move(line, changeX, changeY) {
    context.strokeStyle = line.color;
    context.beginPath();
    context.moveTo(line.x, line.y);

    context.lineTo(line.x + changeX, line.y + changeY);
    context.stroke();
    context.closePath();
  }


  drawMouseStop(MouseEvent event) => mouseMoving = false;
  preDrawMouse(MouseEvent event) {
    mouseMoving = true;
    mouseId++;
    var id = mouseId.toString();
    var mycolor = colors[(random.nextDouble()*colors.length).floor().toInt()];
    lines[id] = new Line(event.layer.x, event.layer.y, mycolor);
    event.preventDefault();
  }

  drawMouse(MouseEvent event) {
    if (!mouseMoving) return;

    var id = mouseId.toString();
    var moveX = event.layer.x - lines[id].x;
    var moveY = event.layer.y - lines[id].y;
    move(lines[id], moveX, moveY);
    lines[id].moveX = moveX;
    lines[id].moveY = moveY;
    model.addLine(lines[id]);
    lines[id].x = lines[id].x + moveX;
    lines[id].y = lines[id].y + moveY;

    event.preventDefault();
  }
}

void main() {
  _setupLogger();
  Logger logger = new Logger("main");
  ButtonElement newCanvasButton = query("#createNewCanvasButton");
  ButtonElement openButton = query("#openButton");
  ButtonElement clearButton = query("#clearButton");
  ButtonElement shareButton = query("#shareButton");
  ButtonElement driveButton = query("#openDriveButton");
  InputElement fileIdInput = query("#fileIdInput");
  
  driveButton.onClick.listen((MouseEvent event) {
    js.scoped(() {
      js.context.createPicker();
    });
  });
  
  shareButton.onClick.listen((MouseEvent event) {
    if (model != null) {
      js.scoped(() {
        var shareClient = new js.Proxy(gapi.drive.share.ShareClient, '299615367852.apps.googleusercontent.com');
        var fileId = fileIdInput.value;
        shareClient.setItemIds(js.array([shareClient]));
        shareClient.showSettingsDialog();
      });
    }
  });
  
  clearButton.onClick.listen((MouseEvent event) {
    if (model != null) {
      model.clear();
    }
  });
  
  openButton.onClick.listen((MouseEvent event) {
    logger.fine("openButton ${fileIdInput.value}");
    if (fileIdInput.value.isEmpty) {
      logger.fine("fileIdInput is empty");
      return;
    }

    var fileId = fileIdInput.value;

    if (model != null) {
      model.close();
    }

    if (rtl != null) {
      model = new MultiTouchModel(newModel: false);
      loadRealTimeFile(fileId, model.onFileLoaded, model.initializeModel);
    } else {
      rtl = new RealTimeLoader(clientId: '299615367852.apps.googleusercontent.com', apiKey: 'AIzaSyC8UF7N5I5b42FFU1ieDumfZ2MFdCHY_M8');
      rtl.start().then((bool isComplete) {
        logger.fine("isComplete = ${isComplete}");
        model = new MultiTouchModel(newModel: false);
        loadRealTimeFile(fileId, model.onFileLoaded, model.initializeModel);
      });
    }
  });

  newCanvasButton.onClick.listen((MouseEvent event) {
    rtl = new RealTimeLoader(clientId: '299615367852.apps.googleusercontent.com', apiKey: 'AIzaSyC8UF7N5I5b42FFU1ieDumfZ2MFdCHY_M8');

    rtl.start().then((bool isComplete) {
      logger.fine("isComplete = ${isComplete}");
      createRealTimeFile("dartMultiTouchCanvas").then((drive.File data) {
        logger.fine("dartMultiTouchCanvas file created, data = ${data}");
        String fileId = data.id;
        logger.fine("fileId=$fileId");
        fileIdInput.value = fileId;
        getFileMetadata(fileId).then((List data) {
          logger.fine("fileId=$fileId, data = ${data}");
        });

        model = new MultiTouchModel(newModel: true);
        loadRealTimeFile(fileId, model.onFileLoaded, model.initializeModel);
      });
    });
  });
}
