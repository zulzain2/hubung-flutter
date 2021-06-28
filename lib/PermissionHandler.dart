import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


/// Example Flutter Application demonstrating the functionality of the
/// Permission Handler plugin.
class PermissionHandler extends StatelessWidget {

  static Permission? permission;

   @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }


static Future<String> requestPermission() async{

// You can request multiple permissions at once.
Map<Permission, PermissionStatus> status = await [
  Permission.contacts,
  Permission.phone,
  Permission.storage,
  Permission.camera,
  Permission.notification,
  Permission.microphone,
].request();

return "";

}




}


   



  
