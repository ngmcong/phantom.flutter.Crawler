import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Tăng giới hạn cache lên 200MB và 200 ảnh
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 200;
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

class SourcePath {
  final String name;
  final String crawlJquery;
  final String nextPageJquery;
  String? confirmJquery;

  SourcePath({
    required this.name,
    required this.crawlJquery,
    required this.nextPageJquery,
    this.confirmJquery,
  });
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late final WebViewController controller;
  late final TabController _tabController;
  List<CrawlItem> crawlItems = [];
  List<String> invisibleList = [];
  bool isLoading = true;
  final TextEditingController txtUrl = TextEditingController();
  final String invisibleFilePath = '/Users/phantom/Downloads/invisible.txt';
  bool isManual = false; // Set to true if you want to use manual mode
  String? nextUrl;
  int page = 0;
  bool isShowInvisible = false;
  final String sourcesPath = '/Users/phantom/Downloads/websources.txt';
  List<String>? sources;
  String? sourceSelected;
  List<String>? exists;
  String? currentUrl;
  final String filterTitlePath = '/Users/phantom/Downloads/filtertitles.txt';
  List<String>? filterTitle;
  bool isShowImage = true;
  final String tokenFilePath = '/Users/phantom/Downloads/token.txt';
  final String downloadedPath = "/Volumes/SSD";

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

  // GoogleSignInAccount? _currentUser;
  // String _authStatus = 'Not signed in.';
  bool isCheckLogin = false;
  void initDriveState() async {
    // _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
    //   setState(() {
    //     _currentUser = account;
    //     _authStatus =
    //         account != null
    //             ? 'Signed in: ${account.displayName}'
    //             : 'Not signed in.';
    //   });
    // });
    _googleSignIn
        .signInSilently(); // Try to sign in silently if already authenticated
    getDriveData();
  }

  void loginDrive() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
    if (googleAuth?.accessToken?.isNotEmpty == true) {
      File file = File(tokenFilePath);
      file.writeAsStringSync(googleAuth!.accessToken!);
      getDriveData(retry: true);
    }
  }

  Future<void> appendExists() async {
    Directory directory = Directory(downloadedPath);
    if (await directory.exists()) {
      final List<FileSystemEntity> entities = await directory.list().toList();
      exists ??= [];
      for (final entity in entities) {
        if (entity is File) {
          String fileName = entity.uri.pathSegments.last;
          String entityName =
              fileName.split('.').first; // Extract name without extension
          if (exists!.contains(entityName) || entityName.isEmpty) continue;
          setState(() {
            exists!.add(entityName);
          });
        }
      }
    }
  }

  void getDriveData({bool retry = false}) async {
    var ggSheetToken = await readFileContent(tokenFilePath);
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
      await appendExists();
    } else {
      if (kDebugMode) {
        print('failed to load data: ${response.statusCode}');
      }
      if (retry == false && response.statusCode == 401) {
        loginDrive();
      } else {
        await appendExists();
      }
    }
  }

  Future<String> readFileContent(String filePath) async {
    File file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('File $filePath not found');
  }

  final List<SourcePath> _sourcePaths = [
    SourcePath(
      name: 'eporner.com',
      crawlJquery: '''
        (function() {
          const images = document.querySelectorAll("div.mb.hdy");
          const imageData = Array.from(images).map(item => ({
            href: item.querySelector("div.mbcontent").querySelector("a").href,
            image: item.querySelector("div.mbcontent").querySelector("a").querySelector("img").src,
            duration: item.querySelector("div.mbunder").querySelector("p.mbstats").querySelector("span.mbtim").textContent,
            title: item.querySelector("div.mbunder").querySelector("p.mbtit").textContent,
          }));
          return JSON.stringify(imageData);
        })();
      ''',
      nextPageJquery: '''
        (function() {
          const element = document.querySelector("div.numlist2").querySelector("a.nmnext");
          if (element) {
            return element.href;
          }
          return '';
        })();
      ''',
    ),
    SourcePath(
      name: 'krx18.com',
      crawlJquery: '''
      (function() {
        const dataArrayString = document.querySelectorAll("article.item.movies");
        const datas = Array.from(dataArrayString).map(item => ({
          href: item.querySelector("div.poster").querySelector("a").href,
          image: item.querySelector("div.poster").querySelector("img").src,
          duration: "",
          title: item.querySelector("div.data").querySelector("h3").querySelector("a").textContent,
        }));
        return JSON.stringify(datas);
      })();
      ''',
      nextPageJquery: '''
      (function() {
        const nextIndex = parseInt(document.querySelectorAll("div.navigation")[0].querySelectorAll("span.page.current")[0].innerText) + 1;
        const element = document.querySelectorAll("div.navigation")[0].querySelectorAll("a[title='"+nextIndex+"']");
        if (element) {
          return element[0].href;
        }
        return '';
      })();
      ''',
    ),
    SourcePath(
      name: 'javhd.pro',
      crawlJquery: '''
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
      ''',
      nextPageJquery: '''
      (function() {
        const element = document.querySelectorAll("a.page-numbers");
        if (element) {
          return element[element.length - 1].href;
        }
        return '';
      })();
      ''',
    ),
    SourcePath(
      name: 'avtoday.io',
      crawlJquery: '''
      (function() {
        const dataArrayString = document.querySelectorAll("div.thumbnail");
        const datas = Array.from(dataArrayString).map(item => {
          const videoEl = item.querySelector("div.video-card").querySelector("a").querySelector("video");
          let imageUrl = "";
          if (videoEl) {
            const style = videoEl.style.background;
            imageUrl = "https://avtoday.io/" + style.slice(style.indexOf('url("') + 5, style.lastIndexOf('")'));
          }
          return {
            href: item.querySelector("div.video-card").querySelector("a").href,
            image: imageUrl,
            duration: "",
            title: item.querySelector("div.video-title").querySelector("a").textContent,
          };
        });
        return JSON.stringify(datas);
      })();
      ''',
      nextPageJquery: '''
      (function() {
        const elements = document.querySelectorAll("ul.pagination li.page-item a.page-link");
        if (elements.length > 0) {
          // Lấy phần tử cuối cùng trong danh sách (thường là nút Next hoặc trang cuối)
          const lastItem = elements[elements.length - 1];
          if (lastItem.classList.contains('active')) {
            return '';
          }
          // Trả về href tuyệt đối
          return lastItem.href;
        }
        return '';
      })();
      ''',
      confirmJquery: '''
      (function() {
        const button = document.querySelector('button.swal2-confirm.swal2-styled');
        if (button) {
          button.click();
        } else {
          console.log('Button with the specified class not found.');
          // Optionally, you could send a message back to Flutter using a JavascriptChannel
        }
      })();
      ''',
    ),
    SourcePath(
      name: 'xhamster.com',
      crawlJquery: '''
      (function() {
        function wait(ms) {
          const start = Date.now();
          while (Date.now() - start < ms) {}
        }

        function waitForData(selector, maxTry) {
          for (let i = 0; i < maxTry; i++) {
            const items = document.querySelectorAll(selector);
            if (items.length > 0) {
              // Lấy item đầu tiên để kiểm tra
              const firstItem = items[0];
              // Tìm thẻ <a>, sau đó tìm <img> bên trong <a>
              const linkInItem = firstItem.querySelector("a");
              const imgInLink = linkInItem ? linkInItem.querySelector("img") : null;

              // Điều kiện: Có ảnh và src phải là link thật (http...)
              if (imgInLink && imgInLink.src && imgInLink.src.startsWith('http')) {
                return true;
              }
            }
            // Sync wait 200ms
            const start = Date.now();
            while (Date.now() - start < 200) {}
          }
          return false;
        }

        // Đợi cho đến khi các item video xuất hiện và có ảnh thật
        waitForData("div.thumb-list__item.video-thumb", 50);

        const items = document.querySelectorAll(
          "div.thumb-list__item.video-thumb.video-thumb--type-video"
        );

        const data = [];

        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          const link = item.querySelector("a");
          let img = link ? link.querySelector("img") : null;
          // let retry = 0;
          // while (!img && retry < 5) {
          //   wait(200); 
          //   img = link ? link.querySelector("img") : null;
          //   retry++;
          // }
          const titleEl = item.querySelector("a.video-thumb-info__name");

          data.push({
            href: link ? link.href : "",
            image: img ? img.src : "",
            duration: "",
            title: titleEl
              ? titleEl.textContent.trim()
              : (link ? link.getAttribute("aria-label") : "")
          });
        }
        return JSON.stringify(data);
      })();
      ''',
      nextPageJquery: '''
      (function() {
        const element = document.querySelector("div.main-wrap").querySelector("a.prev-next-list-link.prev-next-list-link--next");
        if (element) {
          return element.getAttribute("href");
        }
        return '';
      })();
      ''',
    ),
  ];

  void initStateAsync() async {
    try {
      sources ??= (await readFileContent(sourcesPath)).split('\n');
    } catch (e) {
      if (kDebugMode) {
        print('Error reading sources file: $e');
      }
      sources = _sourcePaths.map((e) => e.name).toList();
    }
    sourceSelected = '0';

    var content = await readFileContent(invisibleFilePath);
    dynamic decodedJson = jsonDecode(content);
    if (decodedJson is List) {
      invisibleList.addAll(decodedJson.cast<String>());
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

  Future<void> onNavigationDelegatePageFinished(String url) async {
    if (kDebugMode) {
      print('onNavigationDelegatePageFinished: $sourceSelected');
    }
    var selectedSource = _sourcePaths[int.parse(sourceSelected!)];
    if (selectedSource.confirmJquery != null) {
      await controller.runJavaScript(selectedSource.confirmJquery!);
    }
    // var body =
    //     await controller.runJavaScriptReturningResult('document.body.innerHTML')
    //         as String? ??
    //     '[]';
    // if (kDebugMode) {
    //   print('body: $body');
    // }
    // if (sourceSelected == '0') {
    //   //Click confirm age button if exists
    //   await controller.runJavaScript('''
    //                 (function() {
    //                   const button = document.querySelector('button.root-64d24.size-big-64d24.color-brand-64d24.fullWidth-64d24');
    //                   if (button) {
    //                     button.click();
    //                   } else {
    //                     console.log('Button with the specified class not found.');
    //                     // Optionally, you could send a message back to Flutter using a JavascriptChannel
    //                   }
    //                 })();
    //                 ''');
    //   //hide trending
    //   await controller.runJavaScript('''
    //               (function() {
    //                 const h2Elements = document.getElementsByTagName('h2');
    //                 for (let h2 of h2Elements) {
    //                   if (h2.innerText.trim() === "Trending 3d Hentai Moments") {
    //                     let parent = h2.parentNode;
    //                     while (parent) {
    //                       if (parent.getAttribute("data-block") === "moments") {
    //                         parent.remove();
    //                       }
    //                       parent = parent.parentNode;
    //                     }
    //                     return; // Return the innerText if found
    //                   }
    //                 }
    //                 return; // Return null if no matching element is found
    //               })();
    //               ''');
    //   //hide premium = goR-Rvpremium-n-overlay
    //   await controller.runJavaScript('''
    //                 (function() {
    //                   const element = document.querySelector('div.goR-Rvpremium-n-overlay');
    //                   if (element) {
    //                     element.remove();
    //                   }
    //                 })();
    //                 ''');
    //   //hide ad = goR-Rvright-rectangle goR-Rvright-rectangle--video goR-Rv goR-Rvno-ts-init
    //   await controller.runJavaScript('''
    //                 (function() {
    //                   const element = document.querySelector('div.goR-Rvright-rectangle.goR-Rvright-rectangle--video.goR-Rv.goR-Rvno-ts-init');
    //                   if (element) {
    //                     element.remove();
    //                   }
    //                 })();
    //                 ''');
    // } else if (sourceSelected == '9') {
    //   //hide got-it-cc3f8
    //   await controller.runJavaScript('''
    //     (function() {
    //       const button = document.querySelector('a.got-it-cc3f8');
    //       if (button) {
    //         button.click();
    //       } else {
    //         console.log('Button with the specified class not found.');
    //         // Optionally, you could send a message back to Flutter using a JavascriptChannel
    //       }
    //     })();
    //     ''');
    //   //confirm parental-control-confirm-button
    //   await controller.runJavaScript('''
    //     (function() {
    //       const button = document.querySelector('button[data-role="parental-control-confirm-button"]');
    //       if (button) {
    //         button.click();
    //       } else {
    //         console.log('Button with the specified class not found.');
    //         // Optionally, you could send a message back to Flutter using a JavascriptChannel
    //       }
    //     })();
    //     ''');
    // }
    if (kDebugMode) {
      print('Crawl data: $sourceSelected');
    }
    //Crawl data
    String linksJson = '';
    linksJson =
        await controller.runJavaScriptReturningResult(
              selectedSource.crawlJquery,
            )
            as String? ??
        '[]';
    // if (sourceSelected == '0') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const images = document.querySelector("div.main-wrap").querySelector("div.thumb-list.thumb-list--sidebar.thumb-list--middle-line.thumb-list--bigger-with-cube").querySelectorAll("div.thumb-list__item.video-thumb.video-thumb--type-video");
    //                   const imageData = Array.from(images).map(item => ({
    //                     href: item.querySelector("a.video-thumb__image-container.role-pop.thumb-image-container").getAttribute("href"),
    //                     image: item.querySelector("a.video-thumb__image-container.role-pop.thumb-image-container").querySelector("img").getAttribute("src"),
    //                     duration: item.querySelector("a.video-thumb__image-container.role-pop.thumb-image-container").querySelector("div[data-role=video-duration]").innerText,
    //                     title: item.querySelector("div.video-thumb-info").querySelector("a.root-48288").innerText,
    //                   }));
    //                   return JSON.stringify(imageData);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '1') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("a.movie-item.m-block");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.href,
    //                     image: item.querySelector("img").src,
    //                     duration: "",
    //                     title: item.getAttribute("title"),
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '2') {
    //   //Click confirm age button if exists
    //   await controller.runJavaScript('''
    //                 (function() {
    //                   const button = document.querySelector('button[data-event=age_verification]');
    //                   if (button) {
    //                     button.click();
    //                   } else {
    //                     console.log('Button with the specified class not found.');
    //                     // Optionally, you could send a message back to Flutter using a JavascriptChannel
    //                   }
    //                 })();
    //                 ''');
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("li.pcVideoListItem.js-pop.videoblock");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("div.wrap").querySelector("div.phimage").querySelector("a").href,
    //                     image: item.querySelector("div.wrap").querySelector("div.phimage").querySelector("a").querySelector("img").src,
    //                     duration: item.querySelector("div.wrap").querySelector("div.phimage").querySelector("a").querySelector("var").innerText,
    //                     title: item.querySelector("div.wrap").querySelector("div.thumbnail-info-wrapper").querySelector("span.title").querySelector("a").title,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '3') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("article.item.movies");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("div.poster").querySelector("a").href,
    //                     image: item.querySelector("div.poster").querySelector("img").src,
    //                     duration: "",
    //                     title: item.querySelector("div.data").querySelector("h3").querySelector("a").textContent,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '4') {
    //   //Click confirm age button if exists
    //   await controller.runJavaScript('''
    //                 (function() {
    //                   const button = document.querySelector('#okButton');
    //                   if (button) {
    //                     button.click();
    //                   } else {
    //                     console.log('Button with the specified class not found.');
    //                     // Optionally, you could send a message back to Flutter using a JavascriptChannel
    //                   }
    //                 })();
    //                 ''');
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("div.video-preview-screen.video-item.thumb-item");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("a").href,
    //                     image: "https:" + item.querySelector("a").querySelector("ul.screenshots-list").querySelector("li.screenshot-item.active").getAttribute("data-src"),
    //                     duration: item.querySelector("div.durations").querySelector("i").innerText,
    //                     title: item.querySelector("p.inf").querySelector("a").title,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '5') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("div.card");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("center").querySelector("a").href,
    //                     image: item.querySelector("center").querySelector("a").querySelectorAll("picture")[0].querySelectorAll("source")[0].getAttribute("data-srcset"),
    //                     duration: "",
    //                     title: item.querySelector("div.card-block").querySelector("a").querySelector("h1").innerText,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '6') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("div.card.sub.group");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("a.item-link").href,
    //                     image: item.querySelector("a.item-link").querySelector("img").src,
    //                     duration: item.querySelector("a.item-link").querySelector("span.badge.float-right").innerText,
    //                     title: item.querySelector("div.item-footer").querySelector("a.item-title").title,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '7') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("div.mb.hdy");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("div.mbcontent").querySelector("a").href,
    //                     image: item.querySelector("div.mbcontent").querySelector("img").src,
    //                     duration: item.querySelector("div.mbunder").querySelector("p.mbstats").querySelector("span.mbtim").innerHTML,
    //                     title: item.querySelector("div.mbunder").querySelector("p.mbtit").querySelector("a").innerHTML,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '8') {
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("div.frame-block.thumb-block");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("div.thumb-under").querySelector("a").href,
    //                     image: item.querySelector("div.thumb-inside").querySelector("img").src,
    //                     duration: item.querySelector("div.thumb-under").querySelector("p.metadata").querySelector("span.duration").innerHTML,
    //                     title: item.querySelector("div.thumb-under").querySelector("p.title").querySelector("a").textContent,
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // } else if (sourceSelected == '9') {
    //   // var body =
    //   //     await controller.runJavaScriptReturningResult(
    //   //           'document.body.innerHTML',
    //   //         )
    //   //         as String? ??
    //   //     '[]';
    //   // if (kDebugMode) {
    //   //   print('body: $body');
    //   // }
    //   linksJson =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const dataArrayString = document.querySelectorAll("div.thumb-list__item");
    //                   const datas = Array.from(dataArrayString).map(item => ({
    //                     href: item.querySelector("div.video-thumb-info")?.querySelector("a")?.href ?? "NotFound",
    //                     image: item.querySelector("a.video-thumb__image-container")?.querySelector("img")?.src ?? "NotFound",
    //                     duration: "",
    //                     title: item.querySelector("div.video-thumb-info")?.querySelector("a")?.textContent ?? "NotFound",
    //                   }));
    //                   return JSON.stringify(datas);
    //                 })();
    //                 ''')
    //           as String? ??
    //       '[]';
    // }
    if (kDebugMode) {
      print('linksJson: $linksJson');
    }
    List<dynamic> decodedLinks = jsonDecode(linksJson);
    List<CrawlItem> decodedItems =
        decodedLinks.map((e) => CrawlItem.fromJson(e)).toList();
    if (selectedSource.name == 'javhd.pro') {
      RegExp pattern = RegExp(r'(\w*-\d{3,})');
      for (var item in decodedItems) {
        if (pattern.hasMatch(item.title)) continue;
        var imgTitle = item.image.split('/').last;
        Match? match1 = pattern.firstMatch(imgTitle);
        if (match1 != null) {
          item.tag = match1.group(0);
        }
      }
    }
    if (exists != null && exists!.isNotEmpty) {
      List<String> foundNames = [];
      for (var item in exists!) {
        var foundItem =
            decodedItems
                .where(
                  (e) =>
                      e.title == item ||
                      e.title.startsWith('[$item]') ||
                      e.tag == item,
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
    try {
      filterTitle ??= (await readFileContent(filterTitlePath)).split('\n');
      for (var item in filterTitle!) {
        var foundItems = decodedItems.where(
          (e) => e.title.toLowerCase().contains(item),
        );
        if (foundItems.isEmpty) {
          continue;
        }
        for (var item in foundItems) {
          addInvisibleList(item.href);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reading filter title file: $e');
      }
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
      });
    }

    //Call next page
    if (kDebugMode) {
      print('Call next page');
    }
    nextUrl =
        await controller.runJavaScriptReturningResult(
              selectedSource.nextPageJquery,
            )
            as String? ??
        '';
    // if (sourceSelected == '0') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelector("div.main-wrap").querySelector("a.prev-next-list-link.prev-next-list-link--next");
    //                   if (element) {
    //                     return element.getAttribute("href");
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '1') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelectorAll("a.page-numbers");
    //                   if (element) {
    //                     return element[element.length - 1].href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '2') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelectorAll("li.page_next");
    //                   if (element) {
    //                     return element[element.length - 1].querySelector("a").href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '3') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const nextIndex = parseInt(document.querySelectorAll("div.navigation")[0].querySelectorAll("span.page.current")[0].innerText) + 1;
    //                   const element = document.querySelectorAll("div.navigation")[0].querySelectorAll("a[title='"+nextIndex+"']");
    //                   if (element) {
    //                     return element[0].href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '4') {
    //   if (isManual == false && crawlItems.length <= 500) {
    //     await controller.runJavaScript('''
    //       (function() {
    //         const element = document.querySelectorAll("div.pagination-holder")[0].querySelector("ul").querySelector("li.next").querySelector("a");
    //         if (element) {
    //           return element.click();
    //         }
    //       })();
    //       ''');
    //     await onNavigationDelegatePageFinished(url);
    //   }
    // } else if (sourceSelected == '5') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const nextIndex = parseInt(document.querySelector("#page_right_side").querySelectorAll("span.current")[0].innerText) + 1;
    //                   const element = Array.from(document.querySelector("#page_right_side").querySelectorAll("a")).find(link => link.innerText == nextIndex);
    //                   if (element) {
    //                     return element.href;
    //                   }
    //                   return "";
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '6') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelector("div.pagination-pages").querySelector("a[aria-label='Next page']");
    //                   if (element) {
    //                     return element.href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '7') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelector("div.numlist2").querySelector("a.nmnext");
    //                   if (element) {
    //                     return element.href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '8') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelector("div.pagination ").querySelector("a.next-page");
    //                   if (element) {
    //                     return element.href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // } else if (sourceSelected == '9') {
    //   nextUrl =
    //       await controller.runJavaScriptReturningResult('''
    //                 (function() {
    //                   const element = document.querySelector("a.prev-next-list-link.prev-next-list-link--next");
    //                   if (element) {
    //                     return element.href;
    //                   }
    //                   return '';
    //                 })();
    //                 ''')
    //           as String? ??
    //       '';
    // }
    if (nextUrl != null &&
        nextUrl!.isNotEmpty &&
        isManual == false &&
        crawlItems.length <= 500) {
      setState(() {
        page++;
      });
      await loadRequest(Uri.parse(nextUrl!));
    } else {
      if (kDebugMode) {
        print('No next page or manual mode enabled or reached item limit');
      }
    }
  }

  @override
  void initState() {
    super.initState();

    initStateAsync();
    initDriveState();

    _tabController = TabController(length: 2, vsync: this);

    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) async {
                if (kDebugMode) {
                  print('onPageFinished: $url');
                }
                await onNavigationDelegatePageFinished(url);
              },
              onProgress: (progress) async {
                if (kDebugMode) {
                  print("onProgress: $progress");
                }
                // if (currentUrl?.isNotEmpty == true) {
                //   await onNavigationDelegatePageFinished(currentUrl!);
                // }
              },
            ),
          );
  }

  Future<void> loadRequest(Uri uri) async {
    nextUrl = null;
    setState(() {
      currentUrl = uri.toString();
    });
    if (kDebugMode) {
      print('loadRequest: $currentUrl');
    }
    // if (sourceSelected == '5') {
    //   await controller.clearCache();
    // }
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

  Widget buildImage(String imageStr) {
    // 1. Kiểm tra nếu là ảnh Base64
    if (imageStr.startsWith('data:image')) {
      // Tách bỏ phần header "data:image/gif;base64," để lấy nội dung base64 thực sự
      final base64String = imageStr.split(',').last;
      if (kDebugMode) {
        print(
          'Decoding Base64 image: {base64String}, length: ${base64String.length}',
        );
      }
      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        cacheWidth: 300,
        gaplessPlayback: true,
      );
    }

    // 2. Nếu là URL bình thường
    return Image.network(
      imageStr,
      fit: BoxFit.cover,
      headers: {
        'User-Agent': 'Mozilla/5.0...',
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      },
      // Luôn nên có errorBuilder để tránh crash khi link ảnh chết
      errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image),
      gaplessPlayback: true,
    );
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
                            sources?.indexed
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: '${e.$1}',
                                    child: Text(e.$2),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
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
                      Checkbox(
                        value: isShowImage,
                        onChanged: (value) {
                          setState(() {
                            isShowImage = value ?? false;
                          });
                        },
                      ),
                      const Text('Show image'),
                      Checkbox(
                        value: isManual,
                        onChanged: (value) {
                          setState(() {
                            isManual = value ?? false;
                          });
                        },
                      ),
                      const Text('Manual'),
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
                          Visibility(
                            visible: isShowImage,
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: RepaintBoundary(
                                child: buildImage(item.image),
                              ),
                            ),
                          ),
                          SizedBox(width: 60, child: Text(item.duration)),
                          GestureDetector(
                            onTap: () async {
                              var href = item.href;
                              if (item.tag?.isNotEmpty == true) {
                                href = '$href?tag=${item.tag}';
                              }
                              final Uri url = Uri.parse(href);
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
  String? tag;

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
