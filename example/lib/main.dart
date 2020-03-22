import 'package:combos/combos.dart';
import 'package:combos_example/main.dart';
import 'package:editors/editors.dart';
import 'package:flutter/material.dart';
import 'package:demo_items/demo_items.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App();

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: ThemeData(
            inputDecorationTheme:
                const InputDecorationTheme(border: OutlineInputBorder())),
        title: 'Editors Sample App',
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({Key key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final stringEditor = StringEditor(title: 'String Editor');
  final intEditor = IntEditor(title: 'Int Editor');
  final boolEditor = BoolEditor(title: 'Bool Editor', value: false);
  final enumEditor = EnumEditor<MainAxisAlignment>(
      title: 'Enum Editor', getList: () => [null, ...MainAxisAlignment.values]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editors Sample App')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DemoItem<StringProperties>(
                properties: StringProperties(),
                childBuilder: (properties, modifiedEditor) => EditorsContext(
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
                childBuilder: (properties, modifiedEditor) => EditorsContext(
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
                childBuilder: (properties, modifiedEditor) => EditorsContext(
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
                childBuilder: (properties, modifiedEditor) {
                  final editorsContext = EditorsContext(
                    onValueChanged: (editor, value) {
                      properties.value.value = value;
                      return true;
                    },
                    child: () {
                      enumEditor.value = properties.value.value;
                      return enumEditor.build();
                    }(),
                  );
                  //return editorsContext;
                  return ComboContext(
                    parameters: ComboParameters(
                      popupContraints: properties.popupWidth.value == null
                          ? null
                          : BoxConstraints(
                              maxWidth: properties.popupWidth.value.toDouble(),
                            ),
                    ),
                    child:
                        properties.comboProperties.apply(child: editorsContext),
                  );
                },
              ),
            ],
          ),
        ]),
      );
}

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
  Widget buildProperties() {
    final editors = widget.properties.editors;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      itemCount: editors.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => editors[index].build(),
    );
  }
}

class ElementProperties {
  final enabled = BoolEditor(title: 'Enabled', value: true);
  final titlePlacement = EnumEditor<TitlePlacement>(
      title: 'Title Placement',
      getList: () => [null, ...TitlePlacement.values]);
  final maxWidth = IntEditor(title: 'MaxWidth', value: 200);

  List<EditorsBuilder> get editors => [enabled, titlePlacement, maxWidth];
}

class StringProperties extends ElementProperties {
  final value = StringEditor(title: 'Value');

  @override
  List<EditorsBuilder> get editors => [value, ...super.editors];
}

class IntProperties extends ElementProperties {
  final value = IntEditor(title: 'Value');
  final minValue = IntEditor(title: 'Min Value');
  final maxValue = IntEditor(title: 'Max Value');
  final withIncrementer = BoolEditor(title: 'With Incrementer', value: true);

  @override
  List<EditorsBuilder> get editors =>
      [minValue, maxValue, withIncrementer, value, ...super.editors];
}

class BoolProperties extends ElementProperties {
  final value = BoolEditor(value: false, title: 'Value');

  @override
  List<EditorsBuilder> get editors => [value, ...super.editors];
}

class EnumProperties extends ElementProperties {
  factory EnumProperties() {
    final comboProperties = ComboProperties(withChildDecorator: false)
      ..position.value = PopupPosition.bottomMatch;
    final popupWidth = IntEditor(
        title: 'Popup Width',
        onChanged: (value) => comboProperties.position.value =
            value == null ? PopupPosition.bottomMatch : PopupPosition.bottom);
    return EnumProperties._(popupWidth, comboProperties);
  }
  EnumProperties._(this.popupWidth, this.comboProperties);

  final value = EnumEditor<MainAxisAlignment>(
      title: 'Value', getList: () => [null, ...MainAxisAlignment.values]);
  final IntEditor popupWidth;
  final ComboProperties comboProperties;

  @override
  List<EditorsBuilder> get editors => [
        value,
        ...super.editors,
        const EditorsSeparator('Combo Properties'),
        popupWidth,
        ...comboProperties.editors,
      ];
}
