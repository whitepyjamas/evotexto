import 'dart:io';

import 'package:exolutio/src/html_model.dart';
import 'package:exolutio/src/loader.dart';
import 'package:firebase_cloud_messaging_backend/firebase_cloud_messaging_backend.dart';
import 'package:firedart/firedart.dart';

void main() async {
  Platform.environment.forEach((key, value) {
    print(key);
    print(value);
  });

  final server = FirebaseCloudMessagingServer(
    _credentials(),
    'exolutio',
  );

  final auth = await FirebaseAuth(
    // Firebase : Settings : General
    Platform.environment['FIREBASE_WEB_API_KEY'],
    await VolatileStore(),
  )
    ..signInAnonymously();

  final store = Firestore('exolutio', auth: auth);
  final links = store.collection('links');
  final current = await HtmlModel(Loader()).loadMore();
  final earlier = (await links.get()).map((e) => Link.fromMap(e.map)).toList();

  var updated = false;

  for (final link in current) {
    if (_notAny(earlier, link)) {
      print('Found new link: $link');
      await links.add(link.toMap());
      print('Link added to database');
      final response = await _broadcastNotification(server, link);
      print(
        'Link broadcasted. FCM response: { '
        'statusCode: ${response.statusCode}, '
        'successful: ${response.successful}, }',
      );
      updated = true;
      break;
    }
  }

  for (final link in earlier) {
    if (_notAny(current, link)) {
      await links.document(link.url).delete();
      print('Removed old link: $link');
    }
  }

  if (updated) {
    print('Firestore updated with new links');
  } else {
    print('No new links found');
  }

  exit(0);
}

JWTClaim _credentials() => JWTClaim.from(_credentialsFile);

File get _credentialsFile {
  return File.fromUri(
    Uri.file(
      // https://cloud.google.com/kubernetes-engine/docs/tutorials/authenticating-to-cloud-platform
      Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'],
    ),
  );
}

Future<ServerResult> _broadcastNotification(
    FirebaseCloudMessagingServer server, Link link) {
  return server.send(
    Send(
      message: Message(
        notification: Notification(
          body: 'Появилась новая статья - ${link.title}',
        ),
        topic: 'new-content',
        data: link.toMap()..['click_action'] = 'FLUTTER_NOTIFICATION_CLICK',
      ),
    ),
  );
}

bool _notAny(List<Link> list, Link link) {
  return !list.any((e) => e.url == link.url);
}
