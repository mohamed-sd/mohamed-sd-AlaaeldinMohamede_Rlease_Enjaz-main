// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:io';

//import 'package:app_links/app_links.dart';
import 'package:Enjaz/app/routes.dart';
import 'package:Enjaz/data/cubits/item/search_item_cubit.dart';
import 'package:Enjaz/data/cubits/subscription/fetch_user_package_limit_cubit.dart';
import 'package:Enjaz/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Enjaz/data/model/item/item_model.dart';
import 'package:Enjaz/data/model/system_settings_model.dart';
import 'package:Enjaz/ui/screens/chat/chat_list_screen.dart';
import 'package:Enjaz/ui/screens/home/home_screen.dart';
import 'package:Enjaz/ui/screens/home/search_screen.dart';
import 'package:Enjaz/ui/screens/item/my_items_screen.dart';
import 'package:Enjaz/ui/screens/user_profile/profile_screen.dart';

import 'package:Enjaz/ui/screens/widgets/blurred_dialog_box.dart';
import 'package:Enjaz/ui/screens/widgets/maintenance_mode.dart';
import 'package:Enjaz/ui/theme/theme.dart';
import 'package:Enjaz/utils/app_icon.dart';
import 'package:Enjaz/utils/constant.dart';
import 'package:Enjaz/utils/custom_text.dart';
import 'package:Enjaz/utils/error_filter.dart';
import 'package:Enjaz/utils/extensions/extensions.dart';
import 'package:Enjaz/utils/helper_utils.dart';
import 'package:Enjaz/utils/hive_utils.dart';
import 'package:Enjaz/utils/svg/svg_edit.dart';
import 'package:Enjaz/utils/ui_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

List<ItemModel> myItemList = [];
Map<String, dynamic> searchBody = {};
String selectedCategoryId = "0";
String selectedCategoryName = "";
dynamic selectedCategory;

//this will set when i will visit in any category
dynamic currentVisitingCategoryId = "";
dynamic currentVisitingCategory = "";

List<int> navigationStack = [0];

ScrollController homeScreenController = ScrollController();
//ScrollController chatScreenController = ScrollController();
ScrollController profileScreenController = ScrollController();

List<ScrollController> controllerList = [
  homeScreenController,
  //chatScreenController,
  profileScreenController
];

//
class MainActivity extends StatefulWidget {
  final String from;
  final String? itemSlug;
  final String? sellerId;
  static final GlobalKey<MainActivityState> globalKey =
      GlobalKey<MainActivityState>();

  MainActivity({Key? key, required this.from, this.itemSlug, this.sellerId})
      : super(key: globalKey);

  @override
  State<MainActivity> createState() => MainActivityState();

  static Route route(RouteSettings routeSettings) {
    Map arguments = routeSettings.arguments as Map;
    return MaterialPageRoute(
        builder: (_) => MainActivity(
              from: arguments['from'] as String,
              itemSlug: arguments['slug'] as String?,
              sellerId: arguments['sellerId'] as String?,
            ));
  }
}

class MainActivityState extends State<MainActivity>
    with TickerProviderStateMixin {
  PageController pageController = PageController(initialPage: 0);
  int currentTab = 0;
  static final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final List _pageHistory = [];

  DateTime? currentBackPressTime;

//This is rive file artboards and setting you can check rive package's documentation at [pub.dev]
  bool svgLoaded = false;
  bool isAddMenuOpen = false;
  int rotateAnimationDurationMs = 2000;

  bool isChecked = false;
  SVGEdit svgEdit = SVGEdit();
  bool isBack = false;

  StreamSubscription<Uri>? _linkSubscription;
  Color mainColor = Color(0xFF001022);
  Color bottomNavigationIconColor = Color(0xffFCB917);
  Color bottomNavigationSelectedIconColor = Colors.white;
  @override
  void initState() {
    super.initState();

    rootBundle.loadString(AppIcons.plusIcon).then((value) {
      svgEdit.loadSVG(value);
      svgEdit.change("Path_11299-2",
          attribute: "fill",
          value: svgEdit.flutterColorToHexColor(bottomNavigationIconColor)
          //value: svgEdit.flutterColorToHexColor(context.color.territoryColor)
          );
      svgLoaded = true;
      setState(() {});
    });

    FetchSystemSettingsCubit settings =
        context.read<FetchSystemSettingsCubit>();
    if (!const bool.fromEnvironment("force-disable-demo-mode",
        defaultValue: false)) {
      Constant.isDemoModeOn =
          settings.getSetting(SystemSetting.demoMode) ?? false;
    }
    var numberWithSuffix = settings.getSetting(SystemSetting.numberWithSuffix);
    Constant.isNumberWithSuffix = numberWithSuffix == "1" ? true : false;

    ///This will check for update
    versionCheck(settings);

//This will init page controller
    initPageController();

    if (widget.itemSlug != null) {
      Navigator.of(context).pushNamed(Routes.adDetailsScreen,
          arguments: {"slug": widget.itemSlug!});
    }
    if (widget.sellerId != null) {
      Navigator.pushNamed(context, Routes.sellerProfileScreen,
          arguments: {"sellerId": int.parse(widget.sellerId!)});
    }
  }

  void addHistory(int index) {
    List<int> stack = navigationStack;
    if (stack.last != index) {
      stack.add(index);
      navigationStack = stack;
    }

    setState(() {});
  }

  void initPageController() {
    pageController
      ..addListener(() {
        _pageHistory.insert(0, pageController.page);
      });
  }

  void completeProfileCheck() {
    if (HiveUtils.getUserDetails().name == "" ||
        HiveUtils.getUserDetails().email == "") {
      Future.delayed(
        const Duration(milliseconds: 100),
        () {
          Navigator.pushReplacementNamed(context, Routes.completeProfile,
              arguments: {"from": "login"});
        },
      );
    }
  }

  void versionCheck(settings) async {
    var remoteVersion = settings.getSetting(Platform.isIOS
        ? SystemSetting.iosVersion
        : SystemSetting.androidVersion);
    var remote = remoteVersion;

    var forceUpdate = settings.getSetting(SystemSetting.forceUpdate);

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    var current = packageInfo.version;

    int currentVersion = HelperUtils.comparableVersion(packageInfo.version);
    if (remoteVersion == null) {
      return;
    }

    remoteVersion = HelperUtils.comparableVersion(
      remoteVersion,
    );

    if (remoteVersion > currentVersion) {
      Constant.isUpdateAvailable = true;
      Constant.newVersionNumber = settings.getSetting(
        Platform.isIOS
            ? SystemSetting.iosVersion
            : SystemSetting.androidVersion,
      );

      Future.delayed(
        Duration.zero,
        () {
          if (forceUpdate == "1") {
            ///This is force update
            UiUtils.showBlurredDialoge(context,
                dialoge: BlurredDialogBox(
                    onAccept: () async {
                      await launchUrl(
                          Uri.parse(
                            Constant.playstoreURLAndroid,
                          ),
                          mode: LaunchMode.externalApplication);
                    },
                    backAllowedButton: false,
                    svgImagePath: AppIcons.update,
                    isAcceptContainerPush: true,
                    svgImageColor: context.color.territoryColor,
                    showCancelButton: false,
                    title: "updateAvailable".translate(context),
                    acceptTextColor: context.color.buttonColor,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText("$current>$remote"),
                        CustomText(
                            "newVersionAvailableForce".translate(context),
                            textAlign: TextAlign.center),
                      ],
                    )));
          } else {
            UiUtils.showBlurredDialoge(
              context,
              dialoge: BlurredDialogBox(
                onAccept: () async {
                  await launchUrl(Uri.parse(Constant.playstoreURLAndroid),
                      mode: LaunchMode.externalApplication);
                },
                svgImagePath: AppIcons.update,
                svgImageColor: context.color.territoryColor,
                showCancelButton: true,
                title: "updateAvailable".translate(context),
                content: CustomText(
                  "newVersionAvailable".translate(context),
                ),
              ),
            );
          }
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ErrorFilter.setContext(context);
    svgEdit.change("Path_11299-2",
        attribute: "fill",
        value: svgEdit.flutterColorToHexColor(bottomNavigationIconColor)
        //value: svgEdit.flutterColorToHexColor(context.color.territoryColor)
        );
  }

  @override
  void dispose() {
    pageController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  late List<Widget> pages = [
    HomeScreen(from: widget.from),
    ChatListScreen(),
    ItemsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    /*
     return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle( context: context, statusBarColor: context.color.primaryColor),
    */
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context,
          statusBarColor: mainColor,
          brightnessIcon: Brightness.light,
          brightness: Brightness.light),
      child: PopScope(
        canPop: isBack,
        onPopInvokedWithResult: (didPop, result) {
          if (currentTab != 0) {
            pageController.animateToPage(0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut);
            setState(() {
              currentTab = 0;
              isBack = false;
            });
            return;
          } else {
            DateTime now = DateTime.now();
            if (currentBackPressTime == null ||
                now.difference(currentBackPressTime!) >
                    const Duration(seconds: 2)) {
              currentBackPressTime = now;

              HelperUtils.showSnackBarMessage(
                  context, "pressAgainToExit".translate(context));

              setState(() {
                isBack = false;
              });
              return;
            }
            setState(() {
              isBack = true;
            });
            return;
          }
        },
        child: Scaffold(
          backgroundColor: mainColor,
          /*backgroundColor: context.color.primaryColor,
              bottomNavigationBar:
              Constant.maintenanceMode == "1" ? null : bottomBar(), */
          body: Stack(
            children: <Widget>[
              PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: pageController,
                //onPageChanged: onItemSwipe,
                children: pages,
              ),
              if (Constant.maintenanceMode != "1")
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: bottomBar(),
                ),
              if (Constant.maintenanceMode == "1") MaintenanceMode()
            ],
          ),
        ),
      ),
    );
  }

  void onItemTapped(int index) {
    addHistory(index);

    FocusManager.instance.primaryFocus?.unfocus();

    if (index != 1) {
      context.read<SearchItemCubit>().clearSearch();

      if (SearchScreenState.searchController.hasListeners) {
        SearchScreenState.searchController.text = "";
      }
    }
    searchBody = {};
    if (index == 1 || index == 2) {
      UiUtils.checkUser(
          onNotGuest: () {
            currentTab = index;
            pageController.jumpToPage(currentTab);
            setState(
              () {},
            );
          },
          context: context);
    } else {
      currentTab = index;
      pageController.jumpToPage(currentTab);

      setState(() {});
    }
  }

  Widget bottomBar() {
    BorderRadiusGeometry borderRadius = BorderRadius.only(
      topLeft: Radius.circular(40),
      topRight: Radius.circular(40),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BottomAppBar(
        color: Colors.transparent, elevation: 0,
        //color: context.color.secondaryColor,
        shape: const CircularNotchedRectangle(),
        child: Container(
          // color: context.color.secondaryColor,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: mainColor,
            //color: context.color.secondaryColor,
            border: Border.all(
                color: context.color.textLightColor.withValues(alpha: 0.18)),
          ),
          child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                buildBottomNavigationbarItem(0, AppIcons.homeNav,
                    AppIcons.homeNavActive, "homeTab".translate(context)),
                buildBottomNavigationbarItem(1, AppIcons.chatNav,
                    AppIcons.chatNavActive, "chat".translate(context)),
                BlocListener<FetchUserPackageLimitCubit,
                        FetchUserPackageLimitState>(
                    listener: (context, state) {
                      if (state is FetchUserPackageLimitFailure) {
                        UiUtils.noPackageAvailableDialog(context);
                      }
                      if (state is FetchUserPackageLimitInSuccess) {
                        Navigator.pushNamed(
                            context, Routes.selectCategoryScreen,
                            arguments: <String, dynamic>{});
                      }
                    },
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(0.toDouble(), -30),
                      child: InkWell(
                        onTap: () async {
                          //TODO:TEMP
                          print("testclick");
                          UiUtils.checkUser(
                              onNotGuest: () {
                                context
                                    .read<FetchUserPackageLimitCubit>()
                                    .fetchUserPackageLimit(
                                        packageType: "item_listing");
                              },
                              context: context);
                        },
                        child: SizedBox(
                          width: 53,
                          height: 58,
                          child: svgLoaded == false
                              ? Container()
                              : SvgPicture.string(
                                  svgEdit.toSVGString() ?? "",
                                ),
                        ),
                      ),
                    )),
                buildBottomNavigationbarItem(2, AppIcons.myAdsNav,
                    AppIcons.myAdsNavActive, "myAdsTab".translate(context)),
                buildBottomNavigationbarItem(3, AppIcons.profileNav,
                    AppIcons.profileNavActive, "profileTab".translate(context))
              ]),
        ),
      ),
    );

    /*   return ClipRRect(
      borderRadius: borderRadius,
      child: BottomAppBar(
        color: Colors.transparent,
        //color: context.color.secondaryColor,
        shape: const CircularNotchedRectangle(),
        child: Container(
          // color: context.color.secondaryColor,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            //color: Colors.red,
            color: context.color.secondaryColor,
            border: Border.all(
                color: context.color.textLightColor.withValues(alpha: 0.18)),
          ),
          child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                buildBottomNavigationbarItem(0, AppIcons.homeNav,
                    AppIcons.homeNavActive, "homeTab".translate(context)),
                buildBottomNavigationbarItem(1, AppIcons.chatNav,
                    AppIcons.chatNavActive, "chat".translate(context)),
                BlocListener<FetchUserPackageLimitCubit,
                        FetchUserPackageLimitState>(
                    listener: (context, state) {
                      if (state is FetchUserPackageLimitFailure) {
                        UiUtils.noPackageAvailableDialog(context);
                      }
                      if (state is FetchUserPackageLimitInSuccess) {
                        Navigator.pushNamed(
                            context, Routes.selectCategoryScreen,
                            arguments: <String, dynamic>{});
                      }
                    },
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(0.toDouble(), -20),
                      child: InkWell(
                        onTap: () async {
                          //TODO:TEMP
                          UiUtils.checkUser(
                              onNotGuest: () {
                                context
                                    .read<FetchUserPackageLimitCubit>()
                                    .fetchUserPackageLimit(
                                        packageType: "item_listing");
                              },
                              context: context);
                        },
                        child: SizedBox(
                          width: 53,
                          height: 58,
                          child: svgLoaded == false
                              ? Container()
                              : SvgPicture.string(
                                  svgEdit.toSVGString() ?? "",
                                ),
                        ),
                      ),
                    )),
                buildBottomNavigationbarItem(2, AppIcons.myAdsNav,
                    AppIcons.myAdsNavActive, "myAdsTab".translate(context)),
                buildBottomNavigationbarItem(3, AppIcons.profileNav,
                    AppIcons.profileNavActive, "profileTab".translate(context))
              ]),
        ),
      ),
    );
  
   */
  }

  Widget buildBottomNavigationbarItem(
    int index,
    String svgImage,
    String activeSvg,
    String title,
  ) {
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: () => onItemTapped(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (currentTab == index) ...{
                UiUtils.getSvg(activeSvg,
                    color: bottomNavigationSelectedIconColor),
              } else ...{
                UiUtils.getSvg(svgImage, color: bottomNavigationIconColor),
                //UiUtils.getSvg(svgImage,color: context.color.textLightColor.withValues(alpha: 0.5)),
              },
              CustomText(title,
                  textAlign: TextAlign.center,
                  color: currentTab == index
                      ? bottomNavigationSelectedIconColor
                      : bottomNavigationIconColor
                  //color: currentTab == index ? context.color.textDefaultColor : context.color.textLightColor.withValues(alpha: 0.5)
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
