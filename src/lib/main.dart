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
  bool isManual = false;
  String? nextUrl;
  int page = 0;
  bool isShowInvisible = false;

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

  Future<void> removeLinkElement(String href) async {
    await controller.runJavaScript('''
      (function() {
        const targetHref = "$href"; // Replace "xxx" with the desired href value
        const element = document.querySelector('a[href="' + targetHref + '"]');
        if (element && element.parentNode) {
          element.parentNode.remove();
        }
      })();
      ''');
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
                var decodedItems = decodedLinks.map(
                  (e) => CrawlItem.fromJson(e),
                );
                if (isManual && invisibleList.isNotEmpty) {
                  for (var item in invisibleList) {
                    if (decodedItems.any((e) => e.href == item) == false) {
                      continue;
                    }
                    await removeLinkElement(item);
                  }
                }

                //hide trending
                await controller.runJavaScript('''
                  (function() {
                    const h2Elements = document.getElementsByTagName('h2');
                    for (let h2 of h2Elements) {
                      if (h2.innerText.trim() === "Trending 3d Hentai Moments") {
                        let parent = h2.parentNode;
                        while (parent) {
                          if (parent.getAttribute("data-block") === "moments") {
                            parent.remove();
                          }
                          parent = parent.parentNode;
                        }
                        return; // Return the innerText if found
                      }
                    }
                    return; // Return null if no matching element is found
                  })();
                  ''');
                //hide premium = goR-Rvpremium-n-overlay
                await controller.runJavaScript('''
                    (function() {
                      const element = document.querySelector('div.goR-Rvpremium-n-overlay');
                      if (element) {
                        element.remove();
                      }
                    })();
                    ''');
                //hide ad = goR-Rvright-rectangle goR-Rvright-rectangle--video goR-Rv goR-Rvno-ts-init
                await controller.runJavaScript('''
                    (function() {
                      const element = document.querySelector('div.goR-Rvright-rectangle.goR-Rvright-rectangle--video.goR-Rv.goR-Rvno-ts-init');
                      if (element) {
                        element.remove();
                      }
                    })();
                    ''');

                setState(() {
                  for (var item in invisibleList) {
                    decodedLinks.removeWhere((e) => e['href'] == item);
                  }
                  for (var item in decodedItems) {
                    if (crawlItems.any((e) => e.href == item.href)) continue;
                    crawlItems.add(item);
                  }
                  page++;
                });
                nextUrl =
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
                if (nextUrl != null &&
                    nextUrl!.isNotEmpty &&
                    isManual == false &&
                    crawlItems.length <= 1000) {
                  await loadRequest(Uri.parse(nextUrl!));
                }
              },
            ),
          );
  }

  Future<void> loadRequest(Uri uri) async {
    nextUrl = null;
    await controller.loadRequest(uri);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          isManual == false
              ? null
              : AppBar(
                title: null,
                bottom:
                    isManual
                        ? TabBar(
                          controller: _tabController,
                          tabs: const [Tab(text: 'Tab 1'), Tab(text: 'Tab 2')],
                        )
                        : null,
              ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          Column(
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
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  page = 0;
                                  loadRequest(Uri.parse(txtUrl.text));
                                },
                        child: Text('Crawl'),
                      ),
                      Visibility(
                        visible: isManual,
                        child: TextButton(
                          onPressed:
                              nextUrl == null
                                  ? null
                                  : () {
                                    loadRequest(Uri.parse(nextUrl!));
                                  },
                          child: Text('Next page'),
                        ),
                      ),
                      Text('Page: $page, ${crawlItems.length} items'),
                      Checkbox(
                        value: isShowInvisible,
                        onChanged: (value) {
                          setState(() {
                            isShowInvisible = value ?? false;
                          });
                        },
                      ),
                      const Text('Show invisible'),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: crawlItems.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = crawlItems[index];
                    return Visibility(
                      visible: item.isInvisible == false || isShowInvisible,
                      child: Row(
                        children: [
                          Column(
                            children: [
                              TextButton(
                                onPressed: () {
                                  invisibleList.add(item.href);
                                  removeLinkElement(item.href);
                                  File file = File(invisibleFilePath);
                                  file.writeAsStringSync(
                                    jsonEncode(invisibleList),
                                  );
                                  setState(() {
                                    crawlItems.removeAt(index);
                                  });
                                },
                                child: Text('Unfollow'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    item.isInvisible = true;
                                  });
                                },
                                child: Text('Invisible'),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: Image.network(item.image, fit: BoxFit.cover),
                          ),
                          SizedBox(width: 60, child: Text(item.duration)),
                          GestureDetector(
                            onTap: () async {
                              final Uri url = Uri.parse(item.href);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              } else {
                                // show error
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(item.title)),
                                  );
                                }
                              }
                            },
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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
