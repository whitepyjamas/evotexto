import 'package:exolutio/src/model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home/screen.dart';
import 'read/screen.dart';

class Exolutio extends StatelessWidget {
  const Exolutio(this.model, this.data);

  final Model model;
  final List<Link> data;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exolutio',
      theme: ThemeData.light().copyWith(
        textTheme: GoogleFonts.robotoCondensedTextTheme(
          ThemeData.light().textTheme,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.robotoCondensedTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      routes: {
        '/': (context) => HomeScreen(data),
        '/read': (context) => FutureBuilder(
              future: model.article(ModalRoute.of(context).settings.arguments),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error));
                    } else {
                      return ArticleScreen(snapshot.data);
                    }
                    break;
                  default:
                    return Center(child: CircularProgressIndicator());
                }
              },
            ),
      },
      // https://github.com/Sub6Resources/flutter_html/issues/294#issuecomment-637318948
      builder: (BuildContext context, Widget child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
        child: child,
      ),
    );
  }
}