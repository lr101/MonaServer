
import 'package:flutter/material.dart';

class CustomMenuItem<T> extends PopupMenuItem<T> {

  CustomMenuItem({super.key, required super.value, required String title, required IconData icon})
      : super(child:  ListTile(leading: Icon(icon), title: Text(title)));

}
