library editors;

import 'package:combos/combos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// * abstractions

const defaultEditorsDelay = Duration(milliseconds: 300);

abstract class EditorBase<T> {
  EditorBase({this.onChanged});
  final ValueChanged<T> onChanged;
  bool get enabled => true;
  set enabled(bool value) {}

  List<EditorBase> _parents;

  @protected
  void change(T value) {
    _parents?.forEach((_) => _.change(value));
    if (onChanged != null) onChanged(value);
  }
}

abstract class EditorsGroup<T> extends EditorBase<T> {
  EditorsGroup({ValueChanged<T> onChanged}) : super(onChanged: onChanged) {
    editors.forEach(attach);
  }

  List<EditorBase<T>> get editors;

  void attach(EditorBase editor) => (editor._parents ??= []).add(this);
  void dettach(EditorBase editor) => editor._parents?.remove(this);

  @override
  bool get enabled => editors.first.enabled;
  @override
  set enabled(bool value) => editors.forEach((_) => _.enabled = value);
}

mixin VisualEditorMixin<T> on EditorBase<T> {
  Widget build([BuildContext context]);
}

mixin ElementEditorMixin<T> on VisualEditorMixin<T> {
  void initElement(String title, T value, bool enabled) {
    _title = title;
    this.value = value;
    _enabled = enabled;
  }

  String _title;
  T value;
  String get title => _title;
  bool _enabled;
  bool get _isGroup => this is EditorsGroup;
  @override
  bool get enabled => _isGroup ? super.enabled : _enabled;
  @override
  set enabled(bool value) {
    if (_isGroup) {
      _enabled = value;
    } else {
      super.enabled = value;
    }
  }
}

abstract class ElementEditor<T> extends EditorBase<T>
    with VisualEditorMixin<T>, ElementEditorMixin<T> {
  ElementEditor(
      {String title, T value, bool enabled = true, ValueChanged<T> onChanged})
      : assert(enabled != null),
        super(onChanged: onChanged) {
    initElement(title, value, enabled);
  }
}

abstract class ConstrainedEditor<T> extends ElementEditor<T> {
  ConstrainedEditor({
    this.constraints,
    String title,
    T value,
    bool enabled = true,
    ValueChanged<T> onChanged,
  }) : super(
          title: title,
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );

  final BoxConstraints constraints;

  @protected
  Widget buildConstrained([BuildContext context]);

  @override
  Widget build([BuildContext context]) {
    final widget = buildConstrained(context);
    return constraints == null
        ? widget
        : ConstrainedBox(constraints: constraints, child: widget);
  }
}

// * string

abstract class StringEditorBase<T> extends ConstrainedEditor<T> {
  StringEditorBase({
    this.decoration,
    this.delay = defaultEditorsDelay,
    BoxConstraints constraints = const BoxConstraints(maxWidth: 200),
    String title,
    T value,
    bool enabled = true,
    ValueChanged<T> onChanged,
  }) : super(
          constraints: constraints,
          title: title,
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );

  final InputDecoration decoration;
  final Duration delay;
}

class StringEditor extends StringEditorBase<String> {
  StringEditor({
    InputDecoration decoration,
    Duration delay = defaultEditorsDelay,
    BoxConstraints constraints = const BoxConstraints(maxWidth: 200),
    String title,
    String value,
    bool enabled = true,
    ValueChanged<String> onChanged,
  }) : super(
          decoration: decoration,
          delay: delay,
          constraints: constraints,
          title: title,
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );

  @override
  Widget buildConstrained([BuildContext context]) => _StringEditor(
        value: value,
        onChanged: change,
        enabled: enabled,
        title: title,
        decoration: decoration,
        delay: delay,
      );
}

class _StringEditor extends StatefulWidget {
  const _StringEditor({
    Key key,
    @required this.value,
    @required this.onChanged,
    @required this.enabled,
    @required this.title,
    @required this.decoration,
    @required this.delay,
  }) : super(key: key);

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String title;
  final InputDecoration decoration;
  final Duration delay;

  @override
  _StringEditorState createState() => _StringEditorState(value);
}

class _StringEditorState extends State<_StringEditor> {
  _StringEditorState(String value)
      : _controller = TextEditingController(text: value);

  final TextEditingController _controller;
  String _previousValue;
  DateTime _timestamp;

  @override
  void initState() {
    super.initState();
    if (widget.onChanged != null) {
      _controller.addListener(() async {
        if (_controller.text == _previousValue) return;
        final value = _previousValue = _controller.text;
        final timestamp = _timestamp = DateTime.now();
        final delay = widget.delay;
        if (delay != null && delay != Duration.zero) {
          await Future.delayed(delay);
        }
        if (timestamp == _timestamp) widget.onChanged(value);
      });
    }
  }

  @override
  void didUpdateWidget(_StringEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != oldWidget.value && value != _controller.text) {
      _controller.text = value;
    }
    if (widget.enabled != oldWidget.enabled) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ?? widget.title?.isNotEmpty == true
        ? InputDecoration(labelText: widget.title)
        : null;
    return TextField(
        controller: _controller,
        enabled: widget.enabled,
        decoration: decoration);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}

// * int

class IntEditor extends StringEditorBase<int> {
  IntEditor({
    this.withIncrementer = false,
    InputDecoration decoration,
    Duration delay = defaultEditorsDelay,
    BoxConstraints constraints = const BoxConstraints(maxWidth: 200),
    String title,
    int value,
    bool enabled = true,
    ValueChanged<int> onChanged,
  }) : super(
          decoration: decoration,
          delay: delay,
          constraints: constraints,
          title: title,
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );

  final bool withIncrementer;

  @override
  Widget buildConstrained([BuildContext context]) => _StringEditor(
        value: value.toString(),
        onChanged: change == null ? null : (_) => change(int.tryParse(_)),
        enabled: enabled,
        title: title,
        decoration: decoration,
        delay: delay,
      );
}

// * bool

class BoolEditor extends ConstrainedEditor<bool> {
  BoolEditor({
    BoxConstraints constraints = const BoxConstraints(maxWidth: 200),
    String title,
    bool value,
    bool enabled = true,
    ValueChanged<bool> onChanged,
  }) : super(
          constraints: constraints,
          title: title,
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );

  @override
  Widget buildConstrained([BuildContext context]) => CheckboxListTile(
        value: value,
        onChanged: change,
        title: Text(title),
        controlAffinity: ListTileControlAffinity.leading,
      );
}

// * enum

class EnumEditor<T> extends ConstrainedEditor<T> {
  EnumEditor({
    @required this.getList,
    this.itemBuilder = defaultItemBuilder,
    this.childBuilder,
    this.popupBuilder,
    this.getIsSelectable,
    this.progressDecoratorBuilder = AwaitCombo.buildDefaultProgressDecorator,
    this.refreshOnOpened = false,
    this.waitChanged,
    this.progressPosition = ProgressPosition.popup,
    this.position = PopupPosition.bottomMatch,
    this.offset,
    this.autoMirror = true,
    this.requiredSpace,
    this.screenPadding = Combo.defaultScreenPadding,
    this.autoOpen = PopupAutoOpen.tap,
    this.autoClose = PopupAutoClose.tapOutsideWithChildIgnorePointer,
    this.animation = PopupAnimation.fade,
    this.animationDuration = Combo.defaultAnimationDuration,
    this.openedChanged,
    this.hoveredChanged,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    BoxConstraints constraints = const BoxConstraints(maxWidth: 200),
    String title,
    T value,
    bool enabled = true,
    ValueChanged<T> onChanged,
  })  : assert(getList != null),
        super(
          constraints: constraints,
          title: title,
          value: value,
          enabled: enabled,
          onChanged: onChanged,
        );

  final PopupGetList getList;
  final PopupListItemBuilder<T> childBuilder;
  final PopupListItemBuilder<T> itemBuilder;
  final ListPopupBuilder<T> popupBuilder;
  final GetIsSelectable<T> getIsSelectable;
  final ProgressDecoratorBuilder progressDecoratorBuilder;
  final bool refreshOnOpened;
  final ValueChanged<bool> waitChanged;
  final ProgressPosition progressPosition;
  final PopupPosition position;
  final Offset offset;
  final bool autoMirror;
  final double requiredSpace;
  final EdgeInsets screenPadding;
  final PopupAutoOpen autoOpen;
  final PopupAutoClose autoClose;
  final PopupAnimation animation;
  final Duration animationDuration;
  final ValueChanged<bool> openedChanged;
  final ValueChanged<bool> hoveredChanged;
  final Color focusColor;
  final Color hoverColor;
  final Color highlightColor;
  final Color splashColor;

  final _key = GlobalKey<SelectorComboState>();

  void open() => _key.currentState?.open();
  void close() => _key.currentState?.close();

  @override
  Widget buildConstrained([BuildContext context]) => SelectorCombo<T>(
        key: _key,
        selected: value,
        getList: getList,
        itemBuilder: itemBuilder,
        childBuilder: childBuilder,
        onItemTapped: change,
        popupBuilder: popupBuilder,
        getIsSelectable: getIsSelectable,
        progressDecoratorBuilder: progressDecoratorBuilder,
        refreshOnOpened: refreshOnOpened,
        waitChanged: waitChanged,
        progressPosition: progressPosition,
        position: position,
        offset: offset,
        autoMirror: autoMirror,
        requiredSpace: requiredSpace,
        screenPadding: screenPadding,
        autoOpen: autoOpen,
        autoClose: autoClose,
        animation: animation,
        animationDuration: animationDuration,
        openedChanged: openedChanged,
        hoveredChanged: hoveredChanged,
        focusColor: focusColor,
        hoverColor: hoverColor,
        highlightColor: highlightColor,
        splashColor: splashColor,
      );

  static Widget defaultItemBuilder(BuildContext context, item) =>
      ListTile(title: Text(TextHelper.enumToString(item)));
}

// * helpers

class IntTextInputFormatter extends TextInputFormatter {
  IntTextInputFormatter({this.minValue, this.maxValue});

  final int minValue;
  final int maxValue;

  String format(String oldValue, String newValue) {
    if (newValue?.isNotEmpty != true) return '';
    if (newValue.contains('-')) return oldValue;

    var i = int.tryParse(newValue);
    if (i == null) return oldValue;
    if (minValue != null && i < minValue) i = minValue;
    if (maxValue != null && i > maxValue) i = maxValue;

    return i.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final value = format(oldValue.text, newValue.text);
    return value != newValue.text
        ? newValue.copyWith(
            text: value,
            selection: TextSelection.collapsed(offset: value.length))
        : newValue.copyWith(text: value);
  }
}

class TextHelper {
  static String _camelToWords(String value) {
    final codes = value.runes
        .skip(1)
        .map((_) => String.fromCharCode(_))
        .map((_) => _.toUpperCase() == _ ? ' $_' : _)
        .expand((_) => _.runes);

    return value[0].toUpperCase() + String.fromCharCodes(codes);
  }

  static String enumToString(dynamic value) =>
      value == null ? '' : _camelToWords(value.toString().split('.')[1]);
}
