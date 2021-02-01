// -------- server --------
// server: william-blount.dreamhost.com
// username: flutter_ftp
// password: 67IbyHP3PVF0
// upload directory: photos
// https://github.com/nenadcrnko/flutter_sftp_test

// -------- import all packages --------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssh/ssh.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'globals.dart' as globals;

// -------- application start point --------
void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: "SFTP Test App", home: HomePage());
  }
}





// -------------------------------------------------------------------
// -------- home page --------
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // -------- render home page with AppBar and Buttons  --------
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
              _showInfo(
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
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            },
          )
              : Container(),
        ],
      ),
      body: ListView(children: <Widget>[
        Column(children: <Widget>[
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
              Text("Show Firebase", style: TextStyle(color: Colors.white)),
              color: Colors.blue[700],
              onPressed: () {
                _showFirebase(context);
              },
            ),
          ),

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

          SizedBox(height: 20),
          globals.picPath != null
              ? ButtonTheme(
            minWidth: 150.0,
            height: 40.0,
            child: FlatButton(
              child: Text("Send to Firebase",
                  style: TextStyle(color: Colors.white)),
              color: Colors.blue[700],
              onPressed: () {
                _sendFirebase(context);
              },
            ),
          )
              : Container(),
        ]),
      ]),
    );
  }

  // -------- call Second Class for camera support --------
  void _showCamera(BuildContext context) async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => TakePicture(camera: camera)));

    setState(() {
      globals.picPath = result;
      globals.imageFile = File(globals.picPath);
    });
  }

  // -------- call Third Class for Firebase --------
  void _showFirebase(BuildContext context) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => FireBasePicture()));

    setState(() {
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
      await client.connectSFTP();

      // -------- uploading problem --------
      if (resultConnect.toString() == 'session_connected') {
        final resultUpload = await client.sftpUpload(
          path: globals.picPath,
          toPath: "./photos",
          callback: (progress) async {
            print(progress);
          },
        );
        if (resultUpload == 'upload_success') globals.sentServer = true;
      }
      await client.disconnect();
    } catch (e) {
      print(e);
      globals.sentServer = false;
    }

    if (globals.sentServer == true) {
      _showInfo(context, 'Upload file', 'The file is uploaded to the server');
    } else {
      _showInfo(context, 'Upload file', 'Error during upload');
    }

    setState(() {});
  }

  // -------- send file to Server if exists --------
  void _sendFirebase(BuildContext context) async {
    final file = File(globals.picPath);
    final bytes = await file.readAsBytes();
    String picdata = jsonEncode(bytes);
    Firestore.instance.collection('dbphotos').document()
        .setData({ 'name': globals.picPath, 'value': picdata });
    _showInfo(context, 'Uploaded to Firebase', 'Collection of documents dbphotos');
  }

  // -------- general function for show dialog box --------
  _showInfo(BuildContext context, String title, String message) {
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





// -------------------------------------------------------------------
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





// -------------------------------------------------------------------
// -------- Show Firebase data --------
class FireBasePicture extends StatefulWidget {
  @override
  _FireBasePictureState createState() {
    return _FireBasePictureState();
  }
}

class _FireBasePictureState extends State<FireBasePicture> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Firebase Pictures'), backgroundColor: Colors.blue[900]),
      body: _table(context),
    );
  }

  Widget _table(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('dbphotos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();

        return _rows(context, snapshot.data.documents);
      },
    );
  }

  Widget _rows(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((data) => _onePicture(context, data)).toList(),
    );
  }

  Widget _onePicture(BuildContext context, DocumentSnapshot data) {
    final onepic = OnePicture.fromSnapshot(data);

    return Padding(
      key: ValueKey(onepic.name),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: ListTile(
          title: Text(onepic.name + "\n" + onepic.value.toString().substring(0,100) + "..." ),
          trailing: Text('jSON'),   //Text(onepic.value)
          onTap: () => {},
        ),
      ),
    );
  }
}

class OnePicture {
  final String name;
  final String value;
  final DocumentReference reference;

  OnePicture.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['value'] != null),
        name = map['name'],
        value = map['value'];

  OnePicture.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Record<$name:$value>";
}