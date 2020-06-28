import 'dart:async';
import 'dart:convert';

import 'package:exolutio/src/comment.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loader.dart';

enum Tag {
  letters,
  others,
}

class Model extends ChangeNotifier {
  Model(
    this.loader,
    this.prefs,
  ) {
    _savePosition
        .throttle(
          (event) => TimerStream(
            true,
            Duration(milliseconds: 500),
          ),
          trailing: true,
        )
        .listen((value) => value());
  }

  final Loader loader;
  final SharedPreferences prefs;
  final _articlePagesCache = <List<dom.Element>>[];
  final _articlesCache = Map<String, Article>();
  final _savePosition = PublishSubject<Function>();

  List<Link> operator [](Tag tag) {
    switch (tag) {
      case Tag.letters:
        return _articles(_isLetter);
      case Tag.others:
        return _articles(_isNotLetter);
      default:
        throw UnimplementedError();
    }
  }

  Future<List<dom.Element>> _page(int index) {
    if (_articlePagesCache.length > index) {
      return Future.value(_articlePagesCache[index]);
    } else {
      return _loadPage(index).then((e) {
        _articlePagesCache.add(e);
        return e;
      });
    }
  }

  Future<List<dom.Element>> _loadPage(int index) => loader
      .page(index)
      .then(parse)
      .then((value) => value.querySelectorAll('dt.entry-title'));

  FutureOr<Article> article(Link link) =>
      _articlesCache[link.url] ??
      loader
          .body(link.url)
          .then(parse)
          .then((value) => _getArticle(link, value))
          .then((value) => _articlesCache[link.url] = value);

  bool get any => _articlePagesCache.isNotEmpty;

  void loadMore() {
    _page(_articlePagesCache.length).then((value) => notifyListeners());
  }

  void refresh() {
    _articlesCache.clear();
    _articlePagesCache.clear();
    loadMore();
  }

  bool isRead(Link link) => prefs.containsKey(link.url);

  double getPosition(Article article) {
    if (prefs.containsKey(article.url)) {
      return prefs.getDouble(article.url);
    } else {
      return 0.0;
    }
  }

  void savePosition(Article article, double position) {
    _savePosition.add(() {
      if (position <= 0) {
        prefs.remove(article.url);
      } else {
        prefs.setDouble(article.url, position);
      }
      notifyListeners();
    });
  }

  bool _isNotLetter(e) => !_isLetter(e);
  bool _isLetter(e) => e.text.contains('Письмо:');

  List<Link> _articles(bool test(element)) => _articlePagesCache.isEmpty
      ? []
      : _articlePagesCache
          .reduce((value, element) {
            value.addAll(element);
            return value;
          })
          .where(test)
          .map((e) => e.children.first)
          .where((element) => element.text.isNotEmpty)
          .map((e) => Link(
                e.attributes['href'],
                e.text,
              ))
          .toList();

  Article _getArticle(Link link, dom.Document value) {
    return Article(
      link.url,
      link.title,
      _getArticleText(value),
      _getUndynamicComments(value),
    );
  }

  String _getArticleText(dom.Document value) {
    return value.querySelector('article.b-singlepost-body').outerHtml;
  }

  // if where() directly in _getComments it doesn't work TODO
  List<Comment> _getUndynamicComments(dom.Document value) {
    return _getComments(value)
        .where((e) => e.article?.isNotEmpty ?? false)
        .toList();
  }

  List<Comment> _getComments(dom.Document value) {
    const commentsSource = 'Site.page = ';
    final script = value.body
        .querySelectorAll('script')
        .firstWhere((e) => e.innerHtml.contains(commentsSource))
        .nodes
        .first
        .text;

    final start = script.indexOf(commentsSource) + 'Site.page = '.length;
    final temp = script.substring(start, script.length - 1);
    final end = temp.indexOf('Site.');

    final json = temp.substring(0, end).trim().replaceAll(';', '');
    final user = jsonDecode(json);

    return user['comments'].map((e) => Comment.map(e)).cast<Comment>().toList();
  }
}

class Link {
  Link(this.url, this.title);

  final String url;
  final String title;
}

class Article {
  Article(
    this.url,
    this.title,
    this.text,
    this.comments,
  );

  final String url;
  final String title;
  final String text;
  final List<Comment> comments;
}
