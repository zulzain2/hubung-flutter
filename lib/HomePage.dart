import 'globals.dart' as globals;
import 'package:http/http.dart' as http;
import 'dart:collection';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info/device_info.dart';


class HomePage extends StatefulWidget {
  static InAppWebViewController? webViewController;

  @override
  _HomePageState createState() =>
      new _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final GlobalKey webViewKey = GlobalKey();

  static Future sendPostRequest(String urlString, String params) async {
      // var url = urlString;
      Map<String, String> headers = {
        "Content-type": "application/x-www-form-urlencoded"
      };
      Uri url = Uri.https(globals.domain2, urlString);

      var response = await http.post(url, headers: headers, body: params);

      int statusCode = response.statusCode;

      print('sendPostRequest() URL - $url');
      print('sendPostRequest() PARAM - $params');
      print('sendPostRequest() STATUS - $statusCode');
      print('sendPostRequest() RESPONSE - $response');

      return response;
    }

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  late ContextMenu contextMenu;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    contextMenu = ContextMenu(
        menuItems: [
          ContextMenuItem(
              androidId: 1,
              iosId: "1",
              title: "Special",
              action: () async {
                print("Menu item Special clicked!");
                print(await webViewController?.getSelectedText());
                await webViewController?.clearFocus();
              })
        ],
        options: ContextMenuOptions(hideDefaultSystemContextMenuItems: false),
        onCreateContextMenu: (hitTestResult) async {
          print("onCreateContextMenu");
          print(hitTestResult.extra);
          print(await webViewController?.getSelectedText());
        },
        onHideContextMenu: () {
          print("onHideContextMenu");
        },
        onContextMenuActionItemClicked: (contextMenuItemClicked) async {
          var id = (Platform.isAndroid)
              ? contextMenuItemClicked.androidId
              : contextMenuItemClicked.iosId;
          print("onContextMenuActionItemClicked: " +
              id.toString() +
              " " +
              contextMenuItemClicked.title);
        });

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {}
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      Map data = message.data;

      print("Foreground: ${notification.hashCode}");
      print('Foreground: ${notification?.title}');
      print('Foreground: ${notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      Map data = message.data;

      print("Background: ${notification.hashCode}");
      print('Background: ${notification?.title}');
      print('Background: ${notification?.body}');

      HomePage.webViewController?.loadUrl(
          urlRequest:
              URLRequest(url: Uri.parse(globals.domain + "/" + data['route'])));
    });


  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: AppBar(
            backgroundColor: Color(0xFF565d63),
            brightness: Brightness.dark, // status bar brightness
          )),
        body: SafeArea(
            child: Column(children: <Widget>[
          Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    // contextMenu: contextMenu,
                    initialUrlRequest:
                    URLRequest(url: Uri.parse(globals.home)),
                    // initialFile: "assets/index.html",
                    initialUserScripts: UnmodifiableListView<UserScript>([]),
                    initialOptions: options,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      HomePage.webViewController = controller;
                      
                      HomePage.webViewController?.addJavaScriptHandler(
                          handlerName: 'fcmHandler',
                          callback: (args) async {
                            var deviceId = "";
                            var deviceModel = "";
                            var deviceBrand = "";

                            List data = args;

                            DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

                            try {
                              if (Platform.isAndroid) {
                                try {
                                  AndroidDeviceInfo androidInfo =
                                      await deviceInfo.androidInfo;
                                  deviceId = androidInfo.androidId;
                                  deviceModel = androidInfo.model;
                                  deviceBrand = androidInfo.brand;
                                } catch (e) {
                                  print(
                                      'updateLoginStatus() - No Android Detect');
                                }
                              } else if (Platform.isIOS) {
                                try {
                                  IosDeviceInfo iosInfo =
                                      await deviceInfo.iosInfo;
                                  deviceId = iosInfo.identifierForVendor;
                                  deviceModel = iosInfo.model;
                                  deviceBrand = "Apple";
                                } catch (e) {
                                  print('updateLoginStatus() - No IOS Detect');
                                }
                              }
                            } catch (e) {
                              throw e;
                            }

                            FirebaseMessaging.instance
                                .getToken()
                                .then((String? token) {
                              assert(token != null);
                              print(
                                  'setSharePreference() - FCM Token : $token');

                              String urlString = "/api/fcm/setToken";
                              String params = "user_id=" +
                                  data[0].toString() +
                                  "&fcm_token=" +
                                  token! +
                                  "&device_id=" +
                                  deviceId +
                                  "&device_model=" +
                                  deviceModel +
                                  "&device_brand=" +
                                  deviceBrand;

                              sendPostRequest(urlString, params);
                            });

                            // return data to the JavaScript side!
                            return 'success';
                          });
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    androidOnPermissionRequest: (controller, origin, resources) async {
                      return PermissionRequestResponse(
                          resources: resources,
                          action: PermissionRequestResponseAction.GRANT);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url;
                      print(uri?.scheme);
                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri?.scheme)) {
                        if (await canLaunch(uri.toString())) {
                         
                            await launch(
                              uri.toString(),
                            );
                            return NavigationActionPolicy.CANCEL;
                          
                        }
                      }

                      if (uri.toString() != globals.domain2 ||
                          uri.toString() != "meet.tvetxr.ga") {
                        await launch(
                          uri.toString(),
                        );
                        return NavigationActionPolicy.CANCEL;
                      }
                      else
                      {
                        return NavigationActionPolicy.ALLOW;
                      }
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    // onProgressChanged: (controller, progress) {
                    //   if (progress == 100) {
                    //     pullToRefreshController.endRefreshing();
                    //   }
                    //   setState(() {
                    //     this.progress = progress / 100;
                    //     urlController.text = this.url;
                    //   });
                    // },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage);
                    },
                  ),
                  // progress < 1.0
                  //     ? LinearProgressIndicator(value: progress)
                  //     : Container(),
                ],
              ),
          ),
        ])));
  }
}
