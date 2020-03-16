library editors;

import 'package:combos/combos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// * abstractions

const defaultEditorsDelay = Duration(milliseconds: 300);

enum TitlePlacement { none, label, placeholder, left, right, top }

class EditorParameters {
  const EditorParameters(
      {this.enabled, this.constraints, this.titlePlacement, this.titleStyle});

  final bool enabled;
  final BoxConstraints constraints;
  final TitlePlacement titlePlacement;
  final TextStyle titleStyle;

  EditorParameters copyWith({
    bool enabled,
    BoxConstraints constraints,
    TitlePlacement titlePlacement,
    TextStyle titleStyle,
  }) =>
      EditorParameters(
        enabled: enabled ?? this.enabled,
        constraints: constraints ?? this.constraints,
        titlePlacement: titlePlacement ?? this.titlePlacement,
        titleStyle: titleStyle ?? this.titleStyle,
      );
}

// Return true to cancel the notification bubbling. Return false (or null) to
// allow the notification to continue to be dispatched to further ancestors.
typedef EditorValueChanged = bool Function(Editor editor, dynamic value);
typedef EditorParametersGetter = EditorParameters Function();

class EditorsContext extends StatefulWidget {
  const EditorsContext({
    Key key,
    this.parameters,
    this.onValueChanged,
    this.onValuesChanged,
    @required this.child,
  }) : super(key: key);
  final EditorParameters parameters;
  final EditorValueChanged onValueChanged;
  final VoidCallback onValuesChanged;
  final Widget child;

  static EditorsContextData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EditorsContextData>();

  @override
  _EditorsContextState createState() => _EditorsContextState();
}

class _EditorsContextState extends State<EditorsContext> {
  Object _token;
  @override
  Widget build(BuildContext context) {
    final parentData = EditorsContext.of(context);
    return EditorsContextData(
      widget,
      () {
        final params = widget.parameters;
        final parent = parentData?.parameters;
        return params == null
            ? parent
            : parent == null
                ? params
                : EditorParameters(
                    enabled: params.enabled ?? parent.enabled,
                    constraints: params.constraints ?? parent.constraints,
                    titlePlacement:
                        params.titlePlacement ?? parent.titlePlacement,
                    titleStyle: params.titleStyle ?? parent.titleStyle,
                  );
      },
      // ignore: missing_return
      (editor, value) {
        final onValueChanged = widget.onValueChanged;
        if (onValueChanged == null || !onValueChanged(editor, value)) {
          parentData?.change(editor, value);
        }
        final onValuesChanged = widget.onValuesChanged;
        if (onValuesChanged != null) {
          final token = _token = Object();
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            if (token == _token && mounted) onValuesChanged();
          });
          // Future.delayed(Duration(milliseconds: 1)).then((_) {
          //   if (token == _token && mounted) onValuesChanged();
          // });
        }
      },
    );
  }
}

class EditorsContextData extends InheritedWidget {
  EditorsContextData(this.widget, this._parametersGetter, this.change)
      : super(child: widget.child);
  final EditorsContext widget;
  final EditorParametersGetter _parametersGetter;
  final EditorValueChanged change;

  EditorParameters get parameters => _parametersGetter();

  @override
  bool updateShouldNotify(EditorsContextData oldWidget) =>
      widget.parameters != oldWidget.widget.parameters;
}

abstract class Editor<T> {
  Editor({this.title, this.onChanged, this.value});
  final _key = GlobalKey<_EditorState>();
  String title;
  final ValueChanged<T> onChanged;
  T value;

  static Editor of(BuildContext context) =>
      context.findAncestorStateOfType<_EditorState>()?.editor;

  EditorsContextData getContextData() {
    final state = _key.currentState;
    return state?.mounted == true
        ? state.context.dependOnInheritedWidgetOfExactType<EditorsContextData>()
        : null;
  }

  EditorParameters getParameters() => getContextData()?.parameters;

  void change(T value) {
    if (this.value == value) return;
    this.value = value;
    if (onChanged != null) onChanged(value);
    final data = getContextData();
    if (data == null) return;
    data.change(this, value);
    _key.currentState.safeSetState();
  }

  @protected
  Widget buildBase(BuildContext context, EditorParameters parameters);

  @protected
  Widget buildConstrained(BuildContext context, EditorParameters parameters) {
    final constraints = parameters?.constraints;
    final child = buildBase(context, parameters);
    return constraints == null
        ? child
        : ConstrainedBox(constraints: constraints, child: child);
  }

  @protected
  Widget buildTitle(BuildContext context, EditorParameters parameters) =>
      Text(title, style: parameters?.titleStyle);

  @protected
  Widget buildTitled(BuildContext context, EditorParameters parameters) {
    final child = buildConstrained(context, parameters);
    switch (parameters?.titlePlacement) {
      case TitlePlacement.left:
        return Row(children: [
          buildTitle(context, parameters),
          const SizedBox(width: 16),
          child,
        ]);
      case TitlePlacement.right:
        return Row(children: [
          child,
          const SizedBox(width: 16),
          buildTitle(context, parameters),
        ]);
      case TitlePlacement.top:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          buildTitle(context, parameters),
          child,
        ]);
        break;
      default:
        return child;
    }
  }

  Widget build() => _Editor(
      key: _key,
      editor: this,
      builder: (context) => buildTitled(
          context,
          context
              .dependOnInheritedWidgetOfExactType<EditorsContextData>()
              ?.parameters));
}

class _Editor extends StatefulWidget {
  const _Editor({Key key, @required this.editor, @required this.builder})
      : super(key: key);
  final Editor editor;
  final WidgetBuilder builder;
  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  void safeSetState() => setState(() {});
  Editor get editor => widget.editor;
  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// * string

abstract class StringEditorBase<T> extends Editor<T> {
  StringEditorBase({
    this.decoration,
    this.textAlign,
    this.delay = defaultEditorsDelay,
    String title,
    T value,
    ValueChanged<T> onChanged,
  }) : super(title: title, value: value, onChanged: onChanged);

  final InputDecoration decoration;
  final TextAlign textAlign;
  final Duration delay;

  InputDecoration getDecoration(EditorParameters parameters) {
    if (decoration != null) return decoration;
    InputDecoration createLabelDecoration() =>
        InputDecoration(labelText: title);

    switch (parameters?.titlePlacement) {
      case TitlePlacement.label:
        return createLabelDecoration();
      case TitlePlacement.placeholder:
        return InputDecoration(hintText: title);
      default:
        return parameters?.titlePlacement == null
            ? createLabelDecoration()
            : null;
    }
  }
}

class StringEditor extends StringEditorBase<String> {
  StringEditor({
    InputDecoration decoration,
    TextAlign textAlign,
    Duration delay = defaultEditorsDelay,
    String title,
    String value,
    ValueChanged<String> onChanged,
  }) : super(
          decoration: decoration,
          textAlign: textAlign,
          delay: delay,
          title: title,
          value: value,
          onChanged: onChanged,
        );

  @override
  Widget buildBase(BuildContext context, EditorParameters parameters) =>
      StringEditorInput(
        value: value,
        onChanged: (value) => change(value),
        enabled: parameters?.enabled ?? true,
        title: title,
        decoration: getDecoration(parameters),
        textAlign: textAlign ?? TextAlign.left,
        delay: delay,
      );
}

class StringEditorInput extends StatefulWidget {
  const StringEditorInput({
    Key key,
    @required this.value,
    @required this.onChanged,
    @required this.enabled,
    @required this.title,
    @required this.textAlign,
    @required this.decoration,
    this.inputFormatters,
    @required this.delay,
  })  : assert(textAlign != null),
        assert(enabled != null),
        super(key: key);

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String title;
  final TextAlign textAlign;
  final InputDecoration decoration;
  final List<TextInputFormatter> inputFormatters;
  final Duration delay;

  @override
  StringEditorInputState createState() => StringEditorInputState(value);
}

class StringEditorInputState extends State<StringEditorInput> {
  StringEditorInputState(String value)
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
  void didUpdateWidget(StringEditorInput oldWidget) {
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
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        enabled: widget.enabled,
        decoration: widget.decoration ?? const InputDecoration(),
        inputFormatters: widget.inputFormatters,
        textAlign: widget.textAlign,
      );

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}

// * int

typedef IncrementerDecoratorBuilder = Widget Function(
    BuildContext context,
    Widget input,
    IntEditor editor,
    EditorParameters parameters,
    WidgetBuilder titleBuilder,
    VoidCallback inc,
    VoidCallback dec);

class IntEditor extends StringEditorBase<int> {
  IntEditor({
    this.minValue,
    this.maxValue,
    this.withIncrementer = true,
    this.incrementerDecoratorBuilder = buildDefaultIncrementerDecorator,
    InputDecoration decoration,
    TextAlign textAlign,
    Duration delay = defaultEditorsDelay,
    String title,
    int value,
    ValueChanged<int> onChanged,
  })  : assert(withIncrementer != null),
        assert(!withIncrementer || incrementerDecoratorBuilder != null),
        super(
          decoration: decoration,
          textAlign: textAlign,
          delay: delay,
          title: title,
          value: value,
          onChanged: onChanged,
        );

  int minValue;
  int maxValue;
  bool withIncrementer;
  final IncrementerDecoratorBuilder incrementerDecoratorBuilder;

  @override
  Widget buildBase(BuildContext context, EditorParameters parameters) {
    final input = StringEditorInput(
      key: ValueKey(minValue),
      value: value?.toString() ?? '',
      onChanged: change == null ? null : (_) => change(int.tryParse(_)),
      enabled: parameters?.enabled ?? true,
      title: title,
      decoration: getDecoration(parameters),
      textAlign:
          textAlign ?? withIncrementer ? TextAlign.center : TextAlign.right,
      inputFormatters: [
        _IntTextInputFormatter(minValue: minValue, maxValue: maxValue)
      ],
      delay: delay,
    );

    return withIncrementer && incrementerDecoratorBuilder != null
        ? incrementerDecoratorBuilder(
            context,
            input,
            this,
            parameters,
            (context) => buildTitle(context, parameters),
            value == null || maxValue == null || value < maxValue
                ? () => change((value ?? minValue ?? 0) + 1)
                : null,
            value == null || minValue == null || value > minValue
                ? () => change((value ?? minValue ?? 0) - 1)
                : null,
          )
        : input;
  }

  @override
  Widget buildTitled(BuildContext context, EditorParameters parameters) =>
      parameters?.titlePlacement != TitlePlacement.top || !withIncrementer
          ? super.buildTitled(context, parameters)
          : super.buildConstrained(context, parameters);

  static Widget buildDefaultIncrementerDecorator(
      BuildContext context,
      Widget input,
      IntEditor editor,
      EditorParameters parameters,
      WidgetBuilder titleBuilder,
      VoidCallback inc,
      VoidCallback dec) {
    return Row(children: [
      IconButton(icon: Icon(Icons.remove), onPressed: dec),
      Expanded(
          child: parameters?.titlePlacement == TitlePlacement.top
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleBuilder(context), input])
              : input),
      IconButton(icon: Icon(Icons.add), onPressed: inc),
    ]);
  }
}

// * bool

class BoolEditor extends Editor<bool> {
  BoolEditor({String title, @required bool value, ValueChanged<bool> onChanged})
      : assert(value != null),
        super(title: title, value: value, onChanged: onChanged);

  ListTileControlAffinity getBoolPlacement(
      BuildContext context, EditorParameters parameters) {
    switch (parameters?.titlePlacement) {
      case TitlePlacement.left:
        return ListTileControlAffinity.trailing;
      case TitlePlacement.right:
        return ListTileControlAffinity.leading;
      default:
        return kIsWeb
            ? ListTileControlAffinity.leading
            : ListTileControlAffinity.platform;
    }
  }

  @override
  Widget buildTitled(BuildContext context, EditorParameters parameters) =>
      super.buildConstrained(context, parameters);

  @override
  Widget buildBase(BuildContext context, EditorParameters parameters) =>
      CheckboxListTile(
        value: value,
        onChanged: parameters?.enabled ?? true ? change : null,
        title: title == null ? null : Text(title),
        controlAffinity: getBoolPlacement(context, parameters),
      );
}

// * enum

class EnumEditor<T> extends Editor<T> {
  EnumEditor({
    @required this.getList,
    this.itemBuilder = defaultItemBuilder,
    this.childBuilder = defaultChildBuilder,
    //this.popupBuilder,
    this.getIsSelectable,
    String title,
    T value,
    ValueChanged<T> onChanged,
  })  : assert(getList != null),
        super(
          title: title,
          value: value,
          onChanged: onChanged,
        );

  final PopupGetList<T> getList;
  final PopupListItemBuilder<T> childBuilder;
  final PopupListItemBuilder<T> itemBuilder;
  //final ListPopupBuilder<T> popupBuilder;
  final GetIsSelectable<T> getIsSelectable;

  final _comboKey = GlobalKey<SelectorComboState>();

  void open() => _comboKey.currentState?.open();
  void close() => _comboKey.currentState?.close();

  @override
  Widget buildBase(BuildContext context, EditorParameters parameters) =>
      SelectorCombo<T>(
        key: _comboKey,
        selected: value,
        getList: getList,
        itemBuilder: itemBuilder,
        childBuilder: childBuilder,
        onItemTapped: change,
        //popupBuilder: popupBuilder,
        //getIsSelectable: getIsSelectable,
      );

  static String _getItemText(item) {
    final s = item?.toString();
    if (s?.isNotEmpty != true) return '';
    return s.contains('.') ? _TextHelper.enumToString(item) : s;
  }

  static Widget defaultItemBuilder(BuildContext context, item) =>
      ListTile(title: Text(_getItemText(item)));

  static Widget defaultChildBuilder(BuildContext context, item) {
    Widget child;
    final editor = Editor.of(context);
    final parameters = editor.getParameters();
    final hasTitle = editor != null && parameters?.titlePlacement == null ||
        parameters.titlePlacement == TitlePlacement.label ||
        parameters.titlePlacement == TitlePlacement.placeholder;
    if (item == null && editor != null && hasTitle) {
      child =
          Text(editor?.title ?? '', style: const TextStyle(color: Colors.grey));
    }
    final tile = ListTile(title: child ?? Text(_getItemText(item)));
    return Row(
      children: [
        Expanded(
            child: item == null || !hasTitle
                ? tile
                : Stack(children: [
                    tile,
                    IgnorePointer(
                        child: Text(
                      editor?.title ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ))
                  ])),
        const Icon(Icons.arrow_drop_down),
      ],
    );
  }
}

// * helpers

class _IntTextInputFormatter extends TextInputFormatter {
  _IntTextInputFormatter({this.minValue, this.maxValue});

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

class _TextHelper {
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
