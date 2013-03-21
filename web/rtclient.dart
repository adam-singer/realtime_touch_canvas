library rtclient;

import 'dart:html';
import 'dart:async';
import 'package:js/js.dart' as js;
import 'dart:json' as JSON;
import 'package:logging/logging.dart';
import 'oauth2_v2_schema.dart' as oauth2;
import 'drive_v2_schema.dart' as drive;

Timer timer;

Logger _rtclientLogger = new Logger('rtclient');

js.Proxy _gapi;
js.Proxy get gapi => _gapi;

/**
 * Address of the RealTime server.
 */
const REALTIME_SERVICE_ADDRESS = 'https://docs.google.com/otservice/';


/**
 * OAuth 2.0 scope for installing Drive Apps.
 */
const INSTALL_SCOPE = 'https://www.googleapis.com/auth/drive.install';


/**
 * OAuth 2.0 scope for opening and creating files.
 */
const FILE_SCOPE = 'https://www.googleapis.com/auth/drive.file';


/**
 * MIME type for newly created RealTime files.
 */
const REALTIME_MIMETYPE = 'application/vnd.google-apps.drive-sdk';

/**
 * Parses the url parameters to this page and returns them as an object.
 */
Map getParams() {
  var params = {};
  try {
    var queryString = window.location.search;
    _rtclientLogger.fine("window.location.search = ${window.location.search}");
    if (queryString != null && queryString.length > 0) {
      // split up the query string and store in an object
      var paramStrs = queryString.substring(1).split('&');
      for (var i = 0; i < paramStrs.length; i++) {
        var paramStr = paramStrs[i].split('=');
        params[paramStr[0]] = paramStr[1];
      }
    }
    _rtclientLogger.fine("params = ${params}");
  } catch (ex) {
    _rtclientLogger.fine("ex = $ex");
  }
  return params;
}

/**
 * Instance of the url parameters.
 */
Map get params => getParams();

/**
 * Creates a new RealTime file.
 * [title] {string} title of the newly created file.
 * callback {Function} the callback to call after creation.
 */
Future<drive.File> createRealTimeFile([String title="default title"]) {
  var completer = new Completer();
  js.scoped(() {
    _gapi.client.load('drive', 'v2', new js.Callback.once(() {
      var request = _gapi.client.drive.files.insert(js.map({
        'resource' : {
          'mimeType' : REALTIME_MIMETYPE,
          'title' : title
        }
      }));
      request.execute(new js.Callback.once((js.Proxy jsonResp, var rawResp) {
        _rtclientLogger.fine("rawResp = $rawResp");
        var data = JSON.parse(rawResp);
        var file = new drive.File.fromJson(data[0]['result']);
        completer.complete(file);
      }));
    }));
  });

  return completer.future;
}

/**
 * Fetches the metadata for a RealTime file.
 * [fileId] {string} the file to load metadata for.
 * callback {Function} the callback to be called on completion, with signature:
 *
 *    function onGetFileMetadata(file) {}
 *
 * where the file parameter is a Google Drive API file resource instance.
 */
Future<List> getFileMetadata(String fileId) {
  var completer = new Completer();

  js.scoped(() {
    _gapi.client.load('drive', 'v2', new js.Callback.once(() {
      var request = _gapi.client.drive.files.get(js.map({
        'fileId': fileId
      }));

      request.execute(new js.Callback.once((js.Proxy jsonResp, var rawResp) {
        var data = JSON.parse(rawResp);
        completer.complete(data);
      }));

    }));
  });

  return completer.future;
}


shareRealTimeFile(String appId, String fileId) {
  // NOTE: This is not possible until this is a hosted solution.
  // Depends on the Open With url location
  js.scoped(() {
    var s = new js.Proxy(_gapi.drive.share.ShareClient, appId);
    s.setItemIds([fileId]);
    s.showSettingsDialog();
  });
}

typedef void onFileLoadedCallback(js.Proxy doc);
typedef void initializeModelCallback(js.Proxy model);

/**
 * Loads and starts listening to a RealTime file.
 * [fileId] {string} the file ID to load.
 * [onFileLoaded] {Function} the callback to call when the file is loaded.
 * [initializeModel] {Function} the callback to call when the model is first created.
 */
void loadRealTimeFile(String fileId, onFileLoadedCallback onFileLoaded, initializeModelCallback initializeModel) {
  if (_gapi == null) {
    _rtclientLogger.fine("_gapi == null, not able to loadRealTimeFile");
    return;
  }

  js.scoped(() {
    _gapi.drive.realtime.setServerAddress(REALTIME_SERVICE_ADDRESS);
    _gapi.drive.realtime.load(fileId,
        new js.Callback.once((var doc) {
          _rtclientLogger.fine("onFileLoaded callback");
          //js.context.console.log(doc);
          onFileLoaded(doc);
        }),
        new js.Callback.once((var model) {
          _rtclientLogger.fine("initializeModel callback");
          //js.context.console.log(model);
          initializeModel(model);
        }));
  });
}

/**
 * Parses the state parameter passed from the Drive user interface after Open
 * With operations.
 * [stateParam] {string} the state URL parameter.
 */
parseState(stateParam) {

}

/**
 * Redirects the browser back to the current page with an appropriae file ID.
 * [fileId] {string} the file ID to redirect to.
 */
void redirectToFile(fileId) {
  window.location.href = '?fileId=$fileId';
}



class Authorizer {
  Logger _logger = new Logger('Authorizer');
  String clientId;
  String apiKey;


  /**
   * Creates a new Authorizer from the options.
   *
   * Two keys are required as mandatory, these are:
   *
   *    1. "clientId", the Client ID from the API console
   *    2. "apiKey", the API key from the API console
   */
  Authorizer({String this.clientId, String this.apiKey}) {
    _logger.fine("Creating");
  }

  /**
   * Start the authorization process.
   * @param onAuthComplete {Function} to call once authorization has completed.
   */
  start(onAuthComplete) {
    _logger.fine("start(onAuthComplete)");
    Function authorize = () {
      timer.cancel();
      js.scoped(() {
        _gapi.auth.authorize(
            js.map({
              'client_id': clientId,
              'scope': js.array([INSTALL_SCOPE, FILE_SCOPE]),
              'immediate': false
            }),
            new js.Callback.many(onAuthComplete));
      });
    };

    js.scoped(() {
      // TODO(adam): Move this into something that loads via script element
      // and on callback retains the js.Proxy.
      _gapi = js.context.gapi;
      js.retain(_gapi);
      _gapi.load('auth:client,drive-realtime,drive-share', new js.Callback.once((){
        _logger.fine("load: auth:client,drive-realtime,drive-share");
        _gapi.client.setApiKey(this.apiKey);
        
        timer = new Timer(const Duration(milliseconds: 10), authorize);
      }));
    });
  }

  /**
   * Reauthorize the client with no callback (used for authorization failure).
   */
  void reauthorize() {
    _logger.fine("reauthorize()");
    js.scoped(() {
      _gapi.auth.authorize(js.map({
            'client_id': clientId,
            'scope': js.array([FILE_SCOPE]),
            'immediate': true
          }), new js.Callback.once((js.Proxy authResult) {}));
    });
  }
}



class RealTimeLoader {
  Logger _logger = new Logger('RealTimeLoader');
  Function onFileLoaded;
  Function initializeModel;
  String defaultTitle;
  Authorizer authorizer;
  bool _connected;
  bool get connected => _connected;
  /**
   * Handles authorizing, parsing url parameters, loading and creating RealTime
   * documents.
   * @param options {Object} options for loader. Four keys are required as mandatory, these are:
   *
   *    1. "clientId", the Client ID from the API console
   *    2. "apiKey", the API key from the API console
   *    3. "initializeModel", the callback to call when the file is loaded.
   *    4. "onFileLoaded", the callback to call when the model is first created.
   *
   * and one key is optional:
   *
   *    1. "defaultTitle", the title of newly created RealTime files.
   */
  RealTimeLoader({this.defaultTitle, this.onFileLoaded, this.initializeModel, String clientId, String apiKey}) {
    _logger.fine("Creating");
    this.authorizer = new Authorizer(clientId: clientId, apiKey: apiKey);
  }

  /**
   * Starts the loader by authorizing. Return [true] if the real time client is fully loaded.
   */
  Future<bool> start() {
    var completer = new Completer();
    _logger.fine("start()");
    this.authorizer.start((js.Proxy authResult) {
      _logger.fine("authResult = ${authResult}");
      _logger.fine("authResult = ${JSON.parse(js.context.JSON.stringify(authResult))}");
      this.load().then((bool isComplete) {
        _connected = isComplete;
        completer.complete(isComplete);
      });
    });

    return completer.future;
  }

  /**
   * Loads or creates a RealTime file depending on the fileId and state url
   * parameters.
   */
  Future<bool> load() {
    var completer = new Completer();
    _logger.fine("load()");
    _logger.fine("params = ${params}");

    Function reAuth = () {
      _logger.fine("reAuth()");
      this.authorizer.reauthorize();
    };

    //js.scoped(() {
    //  _gapi.drive.realtime.setAuthFailCallback(new js.Callback.many(reAuth));
      completer.complete(true);
    //});

    return completer.future;
  }
}
