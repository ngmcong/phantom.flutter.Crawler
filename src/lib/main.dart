import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
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
  List<String>? sources;
  String? sourceSelected;
  List<String>? exists;
  String? currentUrl;
  List<String>? filterTitle;

  var tokenFilePath = '/Users/phantom/Downloads/token.txt';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email', // Request the user's email address
      'profile', // Request basic profile information
      'https://www.googleapis.com/auth/drive',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.readonly',
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/spreadsheets.readonly',
      // Add other scopes your app needs, e.g., for Google Drive, Sheets, etc.
    ],
  );

  GoogleSignInAccount? _currentUser;
  String _authStatus = 'Not signed in.';
  bool isCheckLogin = false;
  void initDriveState() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
        _authStatus =
            account != null
                ? 'Signed in: ${account.displayName}'
                : 'Not signed in.';
      });
    });
    _googleSignIn
        .signInSilently(); // Try to sign in silently if already authenticated
    if (kDebugMode) {
      print("_authStatus: $_authStatus");
      print("_currentUser: $_currentUser");
    }
    getDriveData();
  }

  void loginDrive() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
    if (kDebugMode) {
      print('token is ${googleAuth?.accessToken}');
    }
    if (googleAuth?.accessToken?.isNotEmpty == true) {
      File file = File(tokenFilePath);
      file.writeAsStringSync(googleAuth!.accessToken!);
      getDriveData(retry: true);
    }
  }

  void getDriveData({bool retry = false}) async {
    var ggSheetToken = '';
    File file = File(tokenFilePath);
    if (await file.exists()) {
      ggSheetToken = await file.readAsString();
    }
    if (kDebugMode) {
      print('ggSheetToken = $ggSheetToken');
    }
    final url = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/13q0i2NrnZ2DS231dXK0TCGWwhHa2NVOkH6AHii7SlCU/values/A:A',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $ggSheetToken'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        exists =
            data['values']
                .map<String>((e) => e[0].toString())
                .toList()
                .cast<String>();
      });
    } else {
      if (kDebugMode) {
        print('failed to load data: ${response.statusCode}');
      }
      if (retry == false && response.statusCode == 401) {
        loginDrive();
      }
    }
  }

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

  String stringBase64Decode(String? value) {
    if (value == null || value.isEmpty) return "";
    // Decode the Base64 string to a List<int> (bytes)
    List<int> decodedBytes = base64Decode(value);

    // Convert the bytes to a UTF-8 string (most common encoding)
    String decodedString = utf8.decode(decodedBytes);
    return decodedString;
  }

  @override
  void initState() {
    super.initState();

    sources ??= [
      stringBase64Decode("eGhzcG90LmNvbQ=="),
      stringBase64Decode('amF2aGR6LnBybw=='),
    ];
    sourceSelected = '0';

    initStateAsync();
    initDriveState();

    _tabController = TabController(length: 2, vsync: this);

    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) async {
                if (sourceSelected == '0') {
                  //Click confirm age button if exists
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
                }

                //Crawl data
                String linksJson;
                if (sourceSelected == '0') {
                  linksJson =
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
                } else {
                  linksJson =
                      await controller.runJavaScriptReturningResult('''
                    (function() {
                      const dataArrayString = document.querySelectorAll("a.movie-item.m-block");
                      const datas = Array.from(dataArrayString).map(item => ({
                        href: item.href,
                        image: item.querySelector("img").src,
                        duration: "",
                        title: item.getAttribute("title"),
                      }));
                      return JSON.stringify(datas);
                    })();
                    ''')
                          as String? ??
                      '[]';
                }
                List<dynamic> decodedLinks = jsonDecode(linksJson);
                List<CrawlItem> decodedItems =
                    decodedLinks.map((e) => CrawlItem.fromJson(e)).toList();
                if (exists != null && exists!.isNotEmpty) {
                  List<String> foundNames = [];
                  for (var item in exists!) {
                    var foundItem =
                        decodedItems
                            .where(
                              (e) =>
                                  e.title == item ||
                                  e.title.startsWith('[$item]'),
                            )
                            .firstOrNull;
                    if (foundItem == null) {
                      continue;
                    }
                    addInvisibleList(foundItem.href);
                    foundNames.add(item);
                  }
                  for (var item in foundNames) {
                    exists!.remove(item);
                  }
                }
                filterTitle ??= [
                  stringBase64Decode('bsOgbmcgZMOidQ=='),
                  stringBase64Decode('YuG7kSBjaOG7k25n'),
                ];
                if (kDebugMode) {
                  print(filterTitle);
                }
                for (var item in filterTitle!) {
                  if (decodedItems.any(
                        (e) => e.title.toLowerCase().contains(item),
                      ) ==
                      false) {
                    continue;
                  }
                  invisibleList.add(
                    decodedItems
                        .firstWhere((e) => e.title.toLowerCase().contains(item))
                        .href,
                  );
                }
                for (var item in invisibleList) {
                  decodedItems.removeWhere((e) => e.href == item);
                }
                if (isManual && invisibleList.isNotEmpty) {
                  for (var item in invisibleList) {
                    if (decodedItems.any((e) => e.href == item) == false) {
                      continue;
                    }
                    await removeLinkElement(item);
                  }
                }
                if (decodedItems.isNotEmpty) {
                  setState(() {
                    for (var item in decodedItems) {
                      if (crawlItems.any((e) => e.href == item.href)) continue;
                      crawlItems.add(item);
                    }
                    page++;
                  });
                }
                //Call next page
                if (sourceSelected == '0') {
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
                } else {
                  nextUrl =
                      await controller.runJavaScriptReturningResult('''
                    (function() {
                      const element = document.querySelectorAll("a.page-numbers");
                      if (element) {
                        return element[element.length - 1].href;
                      }
                      return '';
                    })();
                    ''')
                          as String? ??
                      '';
                }
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
    currentUrl = uri.toString();
    await controller.loadRequest(uri);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void addInvisibleList(String href) async {
    if (invisibleList.contains(href)) {
      return;
    }
    invisibleList.add(href);
    File file = File(invisibleFilePath);
    file.writeAsStringSync(jsonEncode(invisibleList));
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
                      DropdownButton(
                        value: sourceSelected,
                        items:
                            sources!.indexed
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: '${e.$1}',
                                    child: Text(e.$2),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (kDebugMode) {
                            print('selected: $value');
                          }
                          setState(() {
                            sourceSelected = value;
                          });
                        },
                      ),
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
                      Text(', Exists: ${exists?.length ?? 0} items'),
                      Text(', Loading: ${currentUrl ?? ''}'),
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
                                  addInvisibleList(item.href);
                                  removeLinkElement(item.href);
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
