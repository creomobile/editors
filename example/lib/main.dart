import 'package:editors/editors.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
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
  List<ElementEditor> _editors;

  @override
  void initState() {
    super.initState();
    _editors = _buildEditors();
  }

  List<ElementEditor> _buildEditors() => [
        StringEditor(title: 'String value', onChanged: _onChanged),
      ];

  void _onChanged(value) => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editors Sample App')),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: ListView(children: [
              const SizedBox(height: 16),
              ..._editors.map((editor) => Row(
                    children: [
                      editor.build(),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: 'value: ',
                                style: const TextStyle(color: Colors.grey)),
                            TextSpan(text: '${editor.value}'),
                          ]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.tune),
                        color: Colors.blueAccent,
                        onPressed: () {},
                      )
                    ],
                  )),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      );
}
