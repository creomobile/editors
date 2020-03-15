import 'package:combos/combos.dart';
import 'package:editors/editors.dart';
import 'package:flutter/material.dart';
import 'package:demo_items/demo_items.dart';

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
  final stringEditor = StringEditor(title: 'String value');
  final intEditor = IntEditor(title: 'Int value');
  final boolEditor = BoolEditor(title: 'Bool value', value: false);
  final enumEditor = EnumEditor<MainAxisAlignment>(
      title: 'Enum value', getList: () => [null, ...MainAxisAlignment.values]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editors Sample App')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DemoItem<StringProperties>(
                properties: StringProperties(),
                childBuilder: (properties) => EditorsContext(
                  onValueChanged: (editor, value) {
                    properties.value.value = value;
                    return true;
                  },
                  child: () {
                    stringEditor.value = properties.value.value;
                    return stringEditor.build();
                  }(),
                ),
              ),
              const SizedBox(height: 16),
              DemoItem<IntProperties>(
                properties: IntProperties(),
                childBuilder: (properties) => EditorsContext(
                  onValueChanged: (editor, value) {
                    properties.value.value = value;
                    return true;
                  },
                  child: () {
                    intEditor.value = properties.value.value;
                    intEditor.minValue = properties.minValue.value;
                    intEditor.maxValue = properties.maxValue.value;
                    intEditor.withIncrementer =
                        properties.withIncrementer.value;
                    return intEditor.build();
                  }(),
                ),
              ),
              const SizedBox(height: 16),
              DemoItem<BoolProperties>(
                properties: BoolProperties(),
                childBuilder: (properties) => EditorsContext(
                  onValueChanged: (editor, value) {
                    properties.value.value = value;
                    return true;
                  },
                  child: () {
                    boolEditor.value = properties.value.value;
                    return boolEditor.build();
                  }(),
                ),
              ),
              const SizedBox(height: 16),
              DemoItem<EnumProperties>(
                properties: EnumProperties(),
                childBuilder: (properties) => EditorsContext(
                  onValueChanged: (editor, value) {
                    properties.value.value = value;
                    return true;
                  },
                  child: () {
                    enumEditor.value = properties.value.value;
                    return enumEditor.build();
                  }(),
                ),
              ),
            ],
          ),
        ]),
      );
}

typedef ChildBuilder<TProperties> = Widget Function(TProperties properties);

class DemoItem<TProperties extends ElementProperties>
    extends DemoItemBase<TProperties> {
  const DemoItem({
    Key key,
    @required TProperties properties,
    @required ChildBuilder<TProperties> childBuilder,
  }) : super(key: key, properties: properties, childBuilder: childBuilder);
  @override
  DemoItemState<TProperties> createState() => DemoItemState<TProperties>();
}

class DemoItemState<TProperties extends ElementProperties>
    extends DemoItemStateBase<TProperties> {
  @override
  Widget buildChild() {
    final properties = widget.properties;
    return EditorsContext(
        parameters: EditorParameters(
          enabled: properties.enabled.value,
          constraints:
              BoxConstraints(maxWidth: properties.maxWidth.value.toDouble()),
          titlePlacement: properties.titlePlacement.value,
        ),
        child: super.buildChild());
  }

  @override
  Widget buildProperties() => ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        children: widget.properties.editors.map((e) => e.build()).toList(),
      );
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
