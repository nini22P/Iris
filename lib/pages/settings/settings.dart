import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:iris/pages/settings/about.dart';
import 'package:iris/pages/settings/general.dart';
import 'package:iris/pages/settings/libraries.dart';

class Settings extends HookWidget {
  const Settings({super.key});

  static const title = 'Settings';

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);

    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: const [
              SingleChildScrollView(
                child: General(),
              ),
              SingleChildScrollView(
                child: About(),
              ),
              Libraries(),
            ],
          ),
        ),
        Divider(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
          height: 0,
        ),
        Container(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TabBar(
                    controller: tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'General'),
                      Tab(text: 'About'),
                      Tab(text: 'Libraries'),
                    ]),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
