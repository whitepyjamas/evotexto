import 'dart:io';

import 'package:firebase_cloud_messaging_backend/firebase_cloud_messaging_backend.dart';
import 'package:firedart/firedart.dart';
import 'package:shared/html_model.dart';
import 'package:shared/loader.dart';

void main() async {
  final links = Firestore(
    'exolutio',
    auth: await _firebaseAuth(),
  ).collection('links');

  final current = await HtmlModel(Loader()).loadMore();
  final earlier = (await links.get()).map((e) => Link.fromMap(e.map)).toList();

  final notifier = FirebaseCloudMessagingServer(
    _credentials(),
    'exolutio',
  );

  final added = missing(
    from: earlier,
    list: current,
  ).map((e) => _notify(e, links, notifier));

  final clean = missing(
    from: current,
    list: earlier,
  ).map((e) => _delete(e, links));

  if ((await Future.wait(added.followedBy(clean))).length > 0) {
    print('Firestore updated');
  } else {
    print('No changes found');
  }

  exit(0);
}

Iterable<Link> missing({Iterable<Link> from, Iterable<Link> list}) {
  return list.where((e) => _notAny(from, e));
}

Future<FirebaseAuth> _firebaseAuth() async {
  return await FirebaseAuth(
    // Firebase : Settings : General
    Platform.environment['FIREBASE_WEB_API_KEY'],
    await VolatileStore(),
  )
    ..signInAnonymously();
}

Future _notify(
  Link link,
  CollectionReference links,
  FirebaseCloudMessagingServer notifier,
) async {
  print('Found new link: $link');
  await links.add(link.toMap());
  print('Link added to database');
  await _send(notifier, link);
  print('Users notified');
}

Future _delete(Link link, CollectionReference links) async {
  await links.document(link.url).delete();
  print('Removed old link: $link');
}

JWTClaim _credentials() {
  return JWTClaim.from(
    File.fromUri(
      Uri.file(
        // https://cloud.google.com/kubernetes-engine/docs/tutorials/authenticating-to-cloud-platform
        Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'],
      ),
    ),
  );
}

Future<ServerResult> _send(
  FirebaseCloudMessagingServer server,
  Link link,
) {
  return server.send(
    Send(
      message: Message(
        notification: Notification(
          title: 'Новая статья!',
          body: '${link.title} - перейти к чтению.',
        ),
        topic: 'new-content',
        data: link.toMap()..['click_action'] = 'FLUTTER_NOTIFICATION_CLICK',
        android: AndroidConfig(
          priority: AndroidMessagePriority.HIGH,
        ),
      ),
    ),
  );
}

bool _notAny(Iterable<Link> list, Link link) {
  return !list.any((e) => e.url == link.url);
}
