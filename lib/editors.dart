library editors;

import 'package:flutter/material.dart';

/// A Calculator.
abstract class Editor<T> {
  Editor({this.title, this.value});
  final String title;
  T value;
  Widget get widget;
}

class StringEditor extends Editor<String> {
  @override
  // TODO: implement widget
  Widget get widget => throw UnimplementedError();
}
