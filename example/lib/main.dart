import 'package:combos/combos.dart';
import 'package:editors/editors.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'Editors Sample App', home: HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({Key key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editors Sample App')),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 550),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DemoItem<StringEditor, StringProperties>(
                editor: StringEditor(title: 'String value'),
                properties: StringProperties(),
                assignValue: (editor, properties) =>
                    properties.value.value = editor.value,
                assignProperties: (editor, properties) {
                  editor.value = properties.value.value;
                  return const EditorParameters();
                },
              ),
              const SizedBox(height: 16),
              DemoItem<IntEditor, IntProperties>(
                editor: IntEditor(title: 'Int value'),
                properties: IntProperties(),
                assignValue: (editor, properties) =>
                    properties.value.value = editor.value,
                assignProperties: (editor, properties) {
                  editor.value = properties.value.value;
                  editor.minValue = properties.minValue.value;
                  editor.maxValue = properties.maxValue.value;
                  editor.withIncrementer = properties.withIncrementer.value;
                  return const EditorParameters();
                },
              ),
              const SizedBox(height: 16),
              DemoItem<BoolEditor, BoolProperties>(
                editor: BoolEditor(title: 'Bool value', value: false),
                properties: BoolProperties(),
                assignValue: (editor, properties) =>
                    properties.value.value = editor.value,
                assignProperties: (editor, properties) {
                  editor.value = properties.value.value;
                  return const EditorParameters();
                },
              ),
              const SizedBox(height: 16),
              DemoItem<EnumEditor<MainAxisAlignment>, EnumProperties>(
                editor: EnumEditor<MainAxisAlignment>(
                    title: 'Enum value',
                    getList: () => [null, ...MainAxisAlignment.values]),
                properties: EnumProperties(),
                assignValue: (editor, properties) =>
                    properties.value.value = editor.value,
                assignProperties: (editor, properties) {
                  editor.value = properties.value.value;
                  return const EditorParameters();
                },
              ),
            ]),
          ),
        ),
      );
}

typedef AssignValue<TEditor, TProperties> = void Function(
    TEditor editor, TProperties properties);
typedef AssignProperties<TEditor, TProperties> = EditorParameters Function(
    TEditor editor, TProperties properties);

class DemoItem<TEditor extends Editor, TProperties extends ElementProperties>
    extends StatefulWidget {
  const DemoItem({
    Key key,
    @required this.editor,
    @required this.properties,
    @required this.assignValue,
    @required this.assignProperties,
  }) : super(key: key);

  final TEditor editor;
  final TProperties properties;
  final AssignValue<TEditor, TProperties> assignValue;
  final AssignProperties<TEditor, TProperties> assignProperties;

  @override
  _DemoItemState createState() => _DemoItemState<TEditor, TProperties>();
}

class _DemoItemState<TEditor extends Editor,
        TProperties extends ElementProperties>
    extends State<DemoItem<TEditor, TProperties>> {
  final _comboKey = GlobalKey<ComboState>();
  EditorParameters _parameters =
      const EditorParameters(constraints: BoxConstraints(maxWidth: 200));

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final properties = widget.properties;
    final assignValue = widget.assignValue;
    final assignProperties = widget.assignProperties;

    return Row(children: [
      EditorsContext(
          parameters: _parameters,
          onValueChanged: (editor, value) {
            assignValue(editor, properties);
            return true;
          },
          child: editor.build()),
      const SizedBox(width: 16),
      Combo(
        key: _comboKey,
        autoOpen: PopupAutoOpen.none,
        position: PopupPosition.right,
        child: IconButton(
          icon: const Icon(Icons.tune),
          color: Colors.blueAccent,
          onPressed: () => _comboKey.currentState.open(),
        ),
        popupBuilder: (context, mirrored) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height / 3, maxWidth: 232),
          child: Material(
            elevation: 4,
            child: EditorsContext(
              onValueChanged: (_, __) {
                _parameters = assignProperties(editor, properties).copyWith(
                  enabled: properties.enabled.value,
                  constraints: BoxConstraints(
                      maxWidth: properties.maxWidth.value.toDouble()),
                  titlePlacement: properties.titlePlacement.value,
                );
                setState(() {});
                return true;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                physics: ClampingScrollPhysics(),
                children: properties.editors.map((e) => e.build()).toList(),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class ElementProperties {
  final enabled = BoolEditor(title: 'Enabled', value: true);
  final titlePlacement = EnumEditor<TitlePlacement>(
      title: 'Title Placement',
      getList: () => [null, ...TitlePlacement.values]);
  final maxWidth = IntEditor(title: 'MaxWidth', value: 200);

  List<Editor> get editors => [enabled, titlePlacement, maxWidth];
}

class StringProperties extends ElementProperties {
  final value = StringEditor(title: 'Value');

  @override
  List<Editor> get editors => [value, ...super.editors];
}

class IntProperties extends ElementProperties {
  final value = IntEditor(title: 'Value');
  final minValue = IntEditor(title: 'Min Value');
  final maxValue = IntEditor(title: 'Max Value');
  final withIncrementer = BoolEditor(title: 'With Incrementer', value: true);

  @override
  List<Editor> get editors =>
      [minValue, maxValue, withIncrementer, value, ...super.editors];
}

class BoolProperties extends ElementProperties {
  final value = BoolEditor(value: false, title: 'Value');

  @override
  List<Editor> get editors => [value, ...super.editors];
}

class EnumProperties extends ElementProperties {
  final value = EnumEditor<MainAxisAlignment>(
      title: 'Value', getList: () => [null, ...MainAxisAlignment.values]);

  @override
  List<Editor> get editors => [value, ...super.editors];
}
