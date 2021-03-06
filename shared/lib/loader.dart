import 'package:http/http.dart';

const String Root = 'https://evo-lutio.livejournal.com/';

class Loader {
  Future<String> page(int index) {
    return Client()
        .get(Root + '?skip=${index * 50}')
        .then((value) => value.body);
  }

  Future<String> body(String url) {
    return Client().get(url).then((value) => value.body);
  }
}
