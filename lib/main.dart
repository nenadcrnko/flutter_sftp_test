// -------- server --------
// server: william-blount.dreamhost.com
// username: flutter_ftp
// password: 67IbyHP3PVF0
// upload directory: photos

// -------- import all packages --------
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssh/ssh.dart';

import 'globals.dart' as globals;

// -------- application start point --------
void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: "SFTP Test App", home: HomePage());
  }
}

// -------- home page --------
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // -------- render home page with AppBar and Buttons (second button only if picture exists) --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("SFTP Test App"),
          backgroundColor: Colors.blue[900],
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.info),
              onPressed: () {
                showInfo(
                    context,
                    'About the app',
                    'SFTP Test App   Version 1.0\n\n'
                        'Developed by Crnko\n\n'
                        'Take the picture from the camera and send to server.');
              },
            ),

            // exit icon only on Android platform
            Platform.isAndroid
                ? IconButton(
                    icon: Icon(Icons.exit_to_app),
                    onPressed: () {
                      SystemChannels.platform
                          .invokeMethod('SystemNavigator.pop');
                    },
                  )
                : Container(),
          ],
        ),
        body: Center(
          child: Column(children: <Widget>[
            // show picture from camera or nothing on start
            globals.picPath == null
                ? Container()
                : Image.file(File(globals.picPath)),

            SizedBox(height: 20),
            ButtonTheme(
              minWidth: 150.0,
              height: 40.0,
              child: FlatButton(
                child:
                    Text("Take Picture", style: TextStyle(color: Colors.white)),
                color: Colors.blue[700],
                onPressed: () {
                  _showCamera(context);
                },
              ),
            ),
            SizedBox(height: 20),
            globals.picPath != null
                ? ButtonTheme(
                    minWidth: 150.0,
                    height: 40.0,
                    child: FlatButton(
                      child: Text("Send to Server",
                          style: TextStyle(color: Colors.white)),
                      color: Colors.blue[700],
                      onPressed: () {
                        _sendServer(context);
                      },
                    ),
                  )
                : Container(),
          ]),
        ));
  }

  // -------- call Second Class for camera support --------
  void _showCamera(BuildContext context) async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => TakePicture(camera: camera)));

    setState(() {
      globals.picPath = result;
    });
  }

  // -------- send file to Server if exists --------
  void _sendServer(BuildContext context) async {
    try {
      var client = new SSHClient(
        host: 'william-blount.dreamhost.com',
        port: 22,
        username: 'flutter_ftp',
        passwordOrKey: '67IbyHP3PVF0',
      );
      // -------- connection is OK --------
      final resultConnect = await client.connect();

      // -------- uploading problem --------
      if (resultConnect.toString() == 'session_connected') {
        var result = await client.connectSFTP();
        if (result == "sftp_connected") {
          print("Uploading..." + globals.picPath);

//sftp://william-blount.dreamhost.com//home/flutter_ftp/photos

          final resultUpload = await client.sftpUpload(
            path: globals.picPath,
            toPath:
                "photos/", // maybe wrong server path, some security problem or error in package:ssh/ssh.dart
            callback: (progress) async {
              print(progress);
            },
          );
          print("Upload: " + resultUpload.toString());

          globals.sentServer = true;
        }
      }

      await client.disconnect();
    } catch (e) {
      print(e);
      globals.sentServer = false;
    }

    if (globals.sentServer == true) {
      showInfo(context, 'Upload file', 'The file is uploaded to the server');
    } else {
      showInfo(context, 'Upload file', 'Error during upload');
    }

    setState(() {});
  }

  // -------- general function for show dialog box --------
  showInfo(BuildContext context, String title, String message) {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("Close"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

// -------- second class for capture picture --------
class TakePicture extends StatefulWidget {
  final CameraDescription camera;
  TakePicture({@required this.camera});

  @override
  _TakePictureState createState() => _TakePictureState();
}

// -------- take the picture --------
class _TakePictureState extends State<TakePicture> {
  CameraController _cameraController;
  Future<void> _initializeCameraControllerFuture;

  @override
  void initState() {
    super.initState();
    _cameraController =
        CameraController(widget.camera, ResolutionPreset.medium);
    _initializeCameraControllerFuture = _cameraController.initialize();
  }

  void _takePicture(BuildContext context) async {
    try {
      await _initializeCameraControllerFuture;

      final path =
          join((await getTemporaryDirectory()).path, '${DateTime.now()}.png');
      await _cameraController.takePicture(path);
      Navigator.pop(context, path);
    } catch (e) {
      print(e);
    }
  }

  // -------- UI with cammera button --------
  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      FutureBuilder(
        future: _initializeCameraControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_cameraController);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FloatingActionButton(
              backgroundColor: Colors.black,
              child: Icon(Icons.camera),
              onPressed: () {
                _takePicture(context);
              },
            ),
          ),
        ),
      )
    ]);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
