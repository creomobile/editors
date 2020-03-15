library demo_items;

import 'package:combos/combos.dart';
import 'package:editors/editors.dart';
import 'package:flutter/material.dart';

typedef ChildBuilder<TProperties> = Widget Function(TProperties properties);

abstract class DemoItemBase<TProperties> extends StatefulWidget {
  const DemoItemBase(
      {Key key, @required this.properties, @required this.childBuilder})
      : super(key: key);

  final TProperties properties;
  final ChildBuilder<TProperties> childBuilder;
}

abstract class DemoItemStateBase<TProperties>
    extends State<DemoItemBase<TProperties>> {
  final _comboKey = GlobalKey<ComboState>();

  Widget buildChild() => widget.childBuilder(widget.properties);
  Widget buildProperties();

  @override
  Widget build(BuildContext context) => Row(children: [
        buildChild(),
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
                maxHeight: MediaQuery.of(context).size.height / 3,
                maxWidth: 232),
            child: Material(
              elevation: 4,
              child: EditorsContext(
                onValueChanged: (_, __) {
                  setState(() {});
                  return true;
                },
                child: buildProperties(),
              ),
            ),
          ),
        ),
      ]);
}
