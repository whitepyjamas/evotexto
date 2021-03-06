import 'package:client/src/firebase.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:shared/html_model.dart';

import '../locator.dart';
import 'common.dart';

class DeepRouter {
  final BuildContext context;
  final _firebase = locator<Firebase>();

  DeepRouter(
    this.context,
  ) {
    _checkInitialLink().then((_) => initDynamicLinks());
  }

  void initDynamicLinks() async {
    _firebase.onLink(
      onSuccess: _follow,
      onError: (e) async => print(e),
    );
  }

  Future _checkInitialLink() async {
    _follow((await _firebase.getInitialLink()));
  }

  Future _follow(PendingDynamicLinkData data) async {
    var deep = data?.link;
    if (deep != null) {
      final map = deep.queryParameters;
      final link = LinkData(url: map[urlKey], title: map[titleKey]);
      print('following $link to ${deep.path}');
      safePushNamed(context, deep.path, link);
    }
  }
}
