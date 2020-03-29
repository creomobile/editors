library editors;

import 'package:combos/combos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:titles/titles.dart';

// * abstractions

const defaultEditorsDelay = Duration(milliseconds: 300);

class EditorParameters {
  const EditorParameters({
    this.enabled,
    this.constraints,
  });

  static const defaultParameters = EditorParameters(enabled: true);

  final bool enabled;
  final BoxConstraints constraints;

  EditorParameters copyWith({
    bool enabled,
    BoxConstraints constraints,
  }) =>
      EditorParameters(
        enabled: enabled ?? this.enabled,
        constraints: constraints ?? this.constraints,
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
    this.ignoreParentContraints = false,
    @required this.child,
  })  : assert(ignoreParentContraints != null),
        super(key: key);

  final EditorParameters parameters;
  final EditorValueChanged onValueChanged;
  final VoidCallback onValuesChanged;
  final Widget child;

  /// if true, parent context constraints will not be merged with current
  final bool ignoreParentContraints;

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
    final def = parentData == null
        ? EditorParameters.defaultParameters
        : parentData.parameters;
    final my = widget.parameters;
    final merged = my == null
        ? def
        : def == null
            ? my
            : EditorParameters(
                enabled: my.enabled ?? def.enabled,
                constraints: widget.ignoreParentContraints
                    ? my.constraints
                    : ComboContext.mergeConstraints(
                        my.constraints, def.constraints),
              );
    return EditorsContextData(
      widget,
      merged,
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
        }
      },
    );
  }
}

class EditorsContextData extends InheritedWidget {
  EditorsContextData(this.widget, this.parameters, this.change)
      : super(child: widget.child);
  final EditorsContext widget;
  final EditorParameters parameters;
  final EditorValueChanged change;

  @override
  bool updateShouldNotify(EditorsContextData oldWidget) =>
      widget.parameters != oldWidget.widget.parameters;
}

abstract class EditorsBuilder {
  Widget build();
}

class EditorsBuilderImpl implements EditorsBuilder {
  const EditorsBuilderImpl(this._builder);
  final WidgetBuilder _builder;
  @override
  Widget build() => Builder(builder: _builder);
}

class EditorsChildBuilder implements EditorsBuilder {
  const EditorsChildBuilder(this._child);
  static const separator = EditorsChildBuilder(SizedBox(width: 16, height: 16));
  final Widget _child;
  @override
  Widget build() => _child;
}

abstract class Editor<T> implements EditorsBuilder {
  Editor({this.title, this.onChanged, this.value});

  final _key = GlobalKey<_EditorState>();
  dynamic title;
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

  TitlePlacement getTitlePlacement(BuildContext context) =>
      (TitlesContext.of(context)?.parameters ??
              TitleParameters.defaultParameters)
          .placement;

  EditorParameters _parameters;

  /// Editor parameters from current context.
  /// Available only after [build] called.
  @protected
  EditorParameters get parameters => _parameters;

  /// Changes the value of editor, raises 'onChanged' events
  /// and repaint editor view
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
  Widget buildBase(BuildContext context);

  @protected
  Widget buildConstrained(BuildContext context, [Widget child]) {
    final constraints = _parameters.constraints;
    child ??= buildBase(context);
    final titlePlacement = getTitlePlacement(context);
    if (titlePlacement == TitlePlacement.top) {
      child = child.buildTitled(title, TitlePlacement.top);
    }
    if (constraints != null) {
      child = ConstrainedBox(constraints: constraints, child: child);
    }
    if (titlePlacement == TitlePlacement.left ||
        titlePlacement == TitlePlacement.right) {
      child = child.buildTitled(title, titlePlacement);
    }
    return child;
  }

  /// Builds editor widget.
  /// Can be showed only one widget per editor widget at the same time
  @override
  Widget build() => _Editor(
      key: _key,
      editor: this,
      builder: (context) {
        _parameters = context
                .dependOnInheritedWidgetOfExactType<EditorsContextData>()
                ?.parameters ??
            EditorParameters.defaultParameters;
        return buildConstrained(context);
      });
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
  void safeSetState() {
    if (mounted) setState(() {});
  }

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
    dynamic title,
    T value,
    ValueChanged<T> onChanged,
  }) : super(
          title: title,
          value: value,
          onChanged: onChanged,
        );

  final InputDecoration decoration;
  final TextAlign textAlign;
  final Duration delay;

  InputDecoration getDecoration(BuildContext context) {
    final titlePlacement = getTitlePlacement(context);

    if (decoration != null) return decoration;
    InputDecoration createLabelDecoration() =>
        InputDecoration(labelText: title.toString());

    switch (titlePlacement) {
      case TitlePlacement.label:
        return createLabelDecoration();
      case TitlePlacement.placeholder:
        return InputDecoration(hintText: title.toString());
      default:
        return titlePlacement == null ? createLabelDecoration() : null;
    }
  }
}

class StringEditor extends StringEditorBase<String> {
  StringEditor({
    InputDecoration decoration,
    TextAlign textAlign,
    Duration delay = defaultEditorsDelay,
    dynamic title,
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
  Widget buildBase(BuildContext context) => StringEditorInput(
        value: value,
        onChanged: (value) => change(value),
        enabled: parameters.enabled,
        decoration: getDecoration(context),
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
    this.minValue = 0,
    this.maxValue,
    this.withIncrementer = true,
    this.incrementerDecoratorBuilder = buildDefaultIncrementerDecorator,
    InputDecoration decoration,
    TextAlign textAlign,
    Duration delay = defaultEditorsDelay,
    dynamic title,
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
  Widget buildBase(BuildContext context) {
    final parameters = this.parameters;
    final titleParameters = TitlesContext.of(context)?.parameters ??
        TitleParameters.defaultParameters;
    final withIncrementer =
        this.withIncrementer && incrementerDecoratorBuilder != null;
    final incrementerTitle =
        titleParameters.placement == TitlePlacement.top && withIncrementer;
    final enabled = parameters.enabled;
    Widget res = StringEditorInput(
      key: ValueKey(minValue),
      value: value?.toString() ?? '',
      onChanged: change == null ? null : (_) => change(int.tryParse(_)),
      enabled: parameters.enabled,
      decoration: getDecoration(context),
      textAlign:
          textAlign ?? withIncrementer ? TextAlign.center : TextAlign.right,
      inputFormatters: [
        _IntTextInputFormatter(minValue: minValue, maxValue: maxValue)
      ],
      delay: delay,
    );
    if (incrementerTitle) {
      res = TitlesContext(parameters: titleParameters, child: res);
    }
    if (withIncrementer) {
      res = incrementerDecoratorBuilder(
        context,
        res,
        this,
        parameters,
        (context) => titleParameters.builder(context, titleParameters, title),
        enabled && (value == null || maxValue == null || value < maxValue)
            ? () => change((value ?? minValue ?? 0) + 1)
            : null,
        enabled && (value == null || minValue == null || value > minValue)
            ? () => change((value ?? (minValue + 1) ?? 0) - 1)
            : null,
      );
    }
    if (incrementerTitle) {
      res = TitlesContext(
          parameters: titleParameters.copyWith(placement: TitlePlacement.none),
          child: res);
    }
    return res;
  }

  static Widget buildDefaultIncrementerDecorator(
      BuildContext context,
      Widget input,
      IntEditor editor,
      EditorParameters parameters,
      WidgetBuilder titleBuilder,
      VoidCallback inc,
      VoidCallback dec) {
    final titleParameters = TitlesContext.of(context)?.parameters ??
        TitleParameters.defaultParameters;
    return Row(children: [
      IconButton(icon: Icon(Icons.remove), onPressed: dec),
      Expanded(
          child: titleParameters.placement == TitlePlacement.top
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
  BoolEditor({
    dynamic title,
    bool value = false,
    ValueChanged<bool> onChanged,
  })  : assert(value != null),
        super(
          title: title,
          value: value,
          onChanged: onChanged,
        );

  ListTileControlAffinity getBoolPlacement(BuildContext context) {
    switch (super.getTitlePlacement(context)) {
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
  TitlePlacement getTitlePlacement(BuildContext context) => TitlePlacement.none;

  @override
  Widget buildBase(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: parameters.enabled ? change : null,
        title: title == null ? null : Text(title.toString()),
        controlAffinity: getBoolPlacement(context),
      );
}

// * enum

/// Signature for [EnumEditor.childBuilder], [EnumEditor.itemBuilder].
/// May return [Widget] or any object.
/// If it returns [Widget] it will be use to display the object
/// If it returns non [Widget] or null, returned object will be displayed as
/// [ListTile] with the title as [Object.toString] text
/// If [Object.toString] value contains one '.' symbol it will be parsed as
/// enum value
typedef EnumItemBuilder<T> = Function(BuildContext context, T item);

class EnumEditor<T> extends Editor<T> implements ComboController {
  EnumEditor({
    @required this.getList,
    this.itemBuilder = defaultItemBuilder,
    this.childBuilder = defaultChildBuilder,
    this.getIsSelectable,
    dynamic title,
    T value,
    ValueChanged<T> onChanged,
  })  : assert(getList != null),
        super(
          title: title,
          value: value,
          onChanged: onChanged,
        );

  final PopupGetList<T> getList;
  final EnumItemBuilder<T> childBuilder;
  final EnumItemBuilder<T> itemBuilder;
  final GetIsSelectable<T> getIsSelectable;

  final _comboKey = GlobalKey<SelectorComboState>();

  @override
  bool get opened => _comboKey.currentState?.opened == true;
  @override
  void open() => _comboKey.currentState?.open();
  @override
  void close() => _comboKey.currentState?.close();

  @override
  Widget buildBase(BuildContext context) {
    final parameters = this.parameters;
    final enabled = parameters.enabled;
    final titlePlacement = getTitlePlacement(context);
    return ComboContext(
      parameters: ComboParameters(
        enabled: enabled,
        childDecoratorBuilder: (context, comboParameters, controller, child) {
          final theme = Theme.of(context);
          final decoration = InputDecoration(
                  labelText: titlePlacement == null ||
                          titlePlacement == TitlePlacement.label
                      ? title.toString()
                      : null,
                  hintText: titlePlacement == TitlePlacement.placeholder
                      ? title.toString()
                      : null,
                  border: OutlineInputBorder())
              .applyDefaults(theme.inputDecorationTheme)
              .copyWith(enabled: enabled);
          return Stack(
            children: [
              Material(
                  borderRadius:
                      (decoration.border as OutlineInputBorder).borderRadius,
                  child: child),
              Positioned.fill(
                child: IgnorePointer(
                  child: InputDecorator(
                      decoration: decoration,
                      isFocused: controller.opened,
                      isEmpty: value == null,
                      expands: true),
                ),
              ),
            ],
          );
        },
      ),
      child: SelectorCombo<T>(
        key: _comboKey,
        selected: value,
        getList: getList,
        itemBuilder: (context, parameters, item, selected) => buildItem(
            context, item, (context, item) => itemBuilder(context, item)),
        childBuilder: (context, parameters, item) => buildItem(
            context, item, (context, item) => childBuilder(context, item),
            enabled: enabled),
        onSelectedChanged: change,
      ),
    );
  }

  static String _getItemText(item) {
    final value = item?.toString();
    if (value?.isNotEmpty != true) return '';
    final values = value.split('.');
    return values.length == 2 ? _TextHelper.camelToWords(values[1]) : value;
  }

  static Widget buildItem(BuildContext context, item, EnumItemBuilder builder,
      {bool enabled = true}) {
    item = builder(context, item);
    return item is Widget
        ? item
        : ListTile(enabled: enabled, title: Text(_getItemText(item)));
  }

  static dynamic defaultItemBuilder(BuildContext context, item,
          {bool enabled = true}) =>
      _getItemText(item);

  static dynamic defaultChildBuilder(BuildContext context, item) =>
      defaultItemBuilder(context, item,
          enabled: Editor.of(context).parameters.enabled);
}

// * helpers

abstract class _SimpleInputFormatter extends TextInputFormatter {
  String format(String oldValue, String newValue);

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

class _IntTextInputFormatter extends _SimpleInputFormatter {
  _IntTextInputFormatter({this.minValue, this.maxValue});

  final int minValue;
  final int maxValue;

  @override
  String format(String oldValue, String newValue) {
    if (newValue?.isNotEmpty != true) return '';
    if (newValue.contains('-')) return oldValue;

    var i = int.tryParse(newValue);
    if (i == null) return oldValue;
    if (minValue != null && i < minValue) i = minValue;
    if (maxValue != null && i > maxValue) i = maxValue;

    return i.toString();
  }
}

class _NumTextInputFormatter extends _SimpleInputFormatter {
  _NumTextInputFormatter({this.fractionDigits = 2, this.maxValue})
      : _maxValueStr = maxValue.toInt() == maxValue
            ? maxValue.toInt().toString()
            : maxValue.toStringAsFixed(fractionDigits);
  final int fractionDigits;
  final num maxValue;
  final String _maxValueStr;

  @override
  String format(String oldValue, String newValue) {
    // allow symbols removing
    if (newValue.length < oldValue.length) return newValue;

    final n = num.tryParse(newValue);

    // check for parse error and negative
    if (n == null || n < 0) return oldValue;

    // check for maximum allowed
    if (n <= maxValue) {
      final index = newValue.indexOf('.');
      // check fraction
      return index == -1 || newValue.length - index - 1 <= fractionDigits
          ? newValue
          : oldValue;
    }

    return _maxValueStr;
  }
}

class _TextHelper {
  static String camelToWords(String value) {
    final codes = value.runes
        .skip(1)
        .map((_) => String.fromCharCode(_))
        .map((_) => _.toUpperCase() == _ ? ' $_' : _)
        .expand((_) => _.runes);

    return value[0].toUpperCase() + String.fromCharCodes(codes);
  }
}
