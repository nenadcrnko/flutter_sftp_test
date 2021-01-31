# flutter_sftp_test

Flutter SFTP test.


Problematic part in project

void _sendServer(BuildContext context) async {
...
      // -------- connection is OK --------
      final resultConnect = await client.connect();

      // -------- uploading problem --------
      if (resultConnect.toString() == 'session_connected') {
        print("Uploading..." + globals.picPath);

        final resultUpload = await client.sftpUpload(
          path: globals.picPath,
          toPath: "./photos",     // maybe wrong server path, some security problem or error in package:ssh/ssh.dart
          callback: (progress) async {
            print(progress);
          },
        );
        print("Upload: " + resultUpload.toString());
...

