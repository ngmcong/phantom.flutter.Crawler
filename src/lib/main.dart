import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late final WebViewController controller;
  late final TabController _tabController;
  List<CrawlItem> crawlItems = [];
  List<String> invisibleList = [];
  bool isLoading = true;
  final TextEditingController txtUrl = TextEditingController();
  String invisibleFilePath = '';

  void initStateAsync() async {
    invisibleFilePath = '/Users/phantom/Downloads/invisible.txt';
    if (kDebugMode) {
      print(invisibleFilePath);
    }
    File file = File(invisibleFilePath);
    if (await file.exists()) {
      var content = await file.readAsString();
      dynamic decodedJson = jsonDecode(content);
      if (decodedJson is List) {
        invisibleList.addAll(decodedJson.cast<String>());
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    initStateAsync();

    _tabController = TabController(length: 2, vsync: this);

    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              // onProgress: (int progress) {
              //   if (kDebugMode) {
              //     print('WebView progress: $progress');
              //   }
              // },
              // onPageStarted: (String url) {
              //   if (kDebugMode) {
              //     print('WebView started loading: $url');
              //   }
              // },
              onPageFinished: (String url) async {
                await controller.runJavaScript('''
                    (function() {
                      const button = document.querySelector('button.root-64d24.size-big-64d24.color-brand-64d24.fullWidth-64d24');
                      if (button) {
                        button.click();
                      } else {
                        console.log('Button with the specified class not found.');
                        // Optionally, you could send a message back to Flutter using a JavascriptChannel
                      }
                    })();
                    ''');
                String linksJson =
                    await controller.runJavaScriptReturningResult('''
                    (function() {
                      const images = document.querySelector("div.main-wrap").querySelector("div.thumb-list.thumb-list--sidebar.thumb-list--middle-line.thumb-list--bigger-with-cube").querySelectorAll("div.thumb-list__item.video-thumb.video-thumb--type-video");
                      const imageData = Array.from(images).map(item => ({
                        href: item.querySelector("a.video-thumb__image-container.role-pop.thumb-image-container").getAttribute("href"),
                        image: item.querySelector("a.video-thumb__image-container.role-pop.thumb-image-container").querySelector("img").getAttribute("src"),
                        duration: item.querySelector("a.video-thumb__image-container.role-pop.thumb-image-container").querySelector("div[data-role=video-duration]").innerText,
                        title: item.querySelector("div.video-thumb-info").querySelector("a.root-48288").innerText,
                      }));
                      return JSON.stringify(imageData);
                    })();
                    ''')
                        as String? ??
                    '[]';
                List<dynamic> decodedLinks = jsonDecode(linksJson);
                setState(() {
                  for (var item in invisibleList) {
                    decodedLinks.removeWhere((e) => e['href'] == item);
                  }
                  crawlItems.addAll(
                    decodedLinks.map((e) => CrawlItem.fromJson(e)),
                  );
                });
                var nextUrl =
                    await controller.runJavaScriptReturningResult('''
                    (function() {
                      const element = document.querySelector("div.main-wrap").querySelector("a.prev-next-list-link.prev-next-list-link--next");
                      if (element) {
                        return element.getAttribute("href");
                      }
                      return '';
                    })();
                    ''')
                        as String? ??
                    '';
                if (nextUrl.isNotEmpty) {
                  await controller.loadRequest(Uri.parse(nextUrl));
                }
              },
              // onWebResourceError: (WebResourceError error) {
              //   if (kDebugMode) {
              //     print(
              //       'WebResourceError: ${error.description}, code: ${error.errorCode}',
              //     );
              //   }
              // },
            ),
          );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My WebView')),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                Column(
                  children: [
                    TextField(
                      controller: txtUrl,
                      // onChanged: (value) {
                      //   setState(() {
                      //     _inputText = value;
                      //   });
                      // },
                      decoration: const InputDecoration(
                        labelText: 'Enter text here',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    TextButton(
                      onPressed:
                          isLoading
                              ? null
                              : () {
                                controller.loadRequest(Uri.parse(txtUrl.text));
                              },
                      child: Text('Crawl'),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Align children to the start
                  children:
                      crawlItems
                          .map(
                            (e) => Visibility(
                              visible: e.isInvisible == false,
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          File file = File(invisibleFilePath);
                                          invisibleList.add(e.href);
                                          file.writeAsStringSync(
                                            jsonEncode(invisibleList),
                                          );
                                          setState(() {
                                            crawlItems.remove(
                                              crawlItems.firstWhere(
                                                (element) =>
                                                    element.href == e.href,
                                              ),
                                            );
                                          });
                                        },
                                        child: Text('Unfollow'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            e.isInvisible = true;
                                          });
                                        },
                                        child: Text('Invisible'),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Image.network(
                                      e.image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 60, child: Text(e.duration)),
                                  // Text(e.title),
                                  GestureDetector(
                                    onTap: () async {
                                      final Uri url = Uri.parse(e.href);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      } else {
                                        // show error
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(e.title)),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      e.title,
                                      style: TextStyle(
                                        // fontSize: 20,
                                        color: Colors.blueAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          WebViewWidget(controller: controller),
        ],
      ),
    );
  }
}

class CrawlItem {
  final String href;
  final String image;
  final String duration;
  final String title;
  bool isInvisible = false;

  CrawlItem({
    required this.href,
    required this.image,
    required this.duration,
    required this.title,
  });

  Map<String, dynamic> toJson() {
    return {'href': href, 'image': image, 'duration': duration, 'title': title};
  }

  factory CrawlItem.fromJson(Map<String, dynamic> json) {
    return CrawlItem(
      href: json['href'] as String,
      image: json['image'] as String,
      duration: json['duration'] as String,
      title: json['title'] as String,
    );
  }
}
