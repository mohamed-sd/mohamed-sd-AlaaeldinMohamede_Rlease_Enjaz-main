import 'package:Enjaz/app/routes.dart';
import 'package:Enjaz/data/cubits/fetch_notifications_cubit.dart';
import 'package:Enjaz/data/model/item/item_model.dart';
import 'package:Enjaz/data/model/notification_data.dart';

import 'package:Enjaz/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Enjaz/ui/screens/widgets/errors/no_internet.dart';
import 'package:Enjaz/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Enjaz/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Enjaz/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Enjaz/ui/theme/theme.dart';
import 'package:Enjaz/utils/api.dart';
import 'package:Enjaz/utils/custom_text.dart';
import 'package:Enjaz/utils/extensions/extensions.dart';
import 'package:Enjaz/utils/helper_utils.dart';
import 'package:Enjaz/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

late NotificationData selectedNotification;

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  NotificationsState createState() => NotificationsState();

  static Route route(RouteSettings routeSettings) {
    return MaterialPageRoute(
      builder: (_) => const Notifications(),
    );
  }
}

class NotificationsState extends State<Notifications> {
  late final ScrollController _pageScrollController = ScrollController();

  List<ItemModel> itemData = [];

  @override
  void initState() {
    super.initState();
    AdHelper.loadInterstitialAd();
    context.read<FetchNotificationsCubit>().fetchNotifications();
    _pageScrollController.addListener(_pageScroll);
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchNotificationsCubit>().hasMoreData()) {
        context.read<FetchNotificationsCubit>().fetchNotificationsMore();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AdHelper.showInterstitialAd();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "notifications".translate(context),
        showBackButton: true,
      ),
      body: BlocBuilder<FetchNotificationsCubit, FetchNotificationsState>(
          builder: (context, state) {
        if (state is FetchNotificationsInProgress) {
          return buildNotificationShimmer();
        }
        if (state is FetchNotificationsFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage.error == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context.read<FetchNotificationsCubit>().fetchNotifications();
                },
              );
            }
          }

          return const SomethingWentWrong();
        }

        if (state is FetchNotificationsSuccess) {
          if (state.notificationdata.isEmpty) {
            return NoDataFound(
              onTap: () {
                context.read<FetchNotificationsCubit>().fetchNotifications();
              },
            );
          }

          return buildNotificationListWidget(state);
        }

        return const SizedBox.square();
      }),
    );
  }

  Widget buildNotificationShimmer() {
    return ListView.separated(
        padding: const EdgeInsets.all(10),
        separatorBuilder: (context, index) => const SizedBox(
              height: 10,
            ),
        itemCount: 20,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return SizedBox(
            height: 55,
            child: Row(
              children: <Widget>[
                const CustomShimmer(
                  width: 50,
                  height: 50,
                  borderRadius: 11,
                ),
                const SizedBox(
                  width: 5,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CustomShimmer(
                      height: 7,
                      width: 200,
                    ),
                    const SizedBox(height: 5),
                    CustomShimmer(
                      height: 7,
                      width: 100,
                    ),
                    const SizedBox(height: 5),
                    CustomShimmer(
                      height: 7,
                      width: 150,
                    )
                  ],
                )
              ],
            ),
          );
        });
  }

  Column buildNotificationListWidget(FetchNotificationsSuccess state) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
              controller: _pageScrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(10),
              separatorBuilder: (context, index) => const SizedBox(
                    height: 12,
                  ),
              itemCount: state.notificationdata.length,
              itemBuilder: (context, index) {
                NotificationData notificationData =
                    state.notificationdata[index];
                return GestureDetector(
                  onTap: () {
                    selectedNotification = notificationData;

                    HelperUtils.goToNextPage(
                        Routes.notificationDetailPage, context, false);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: context.color.textLightColor.withValues(alpha: 0.28),
                          width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ClipRRect(
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(15),
                            ),
                            child: UiUtils.getImage(notificationData.image!,
                                height: 53, width: 53, fit: BoxFit.fill),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                Text(
                                  notificationData.title!.firstUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .merge(const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ),
                                Padding(
                                    padding: const EdgeInsets.only(top: 3.0),
                                    child: Text(
                                      notificationData.message!
                                          .firstUpperCase(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              color:
                                                  context.color.textLightColor),
                                    )),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: CustomText(
                                    notificationData.createdAt!
                                        .formatDate()
                                        .toString(),
                                    fontSize: context.font.smaller,
                                    color: context.color.textLightColor,
                                  ),
                                )
                              ])),
                        ]),
                  ),
                );
              }),
        ),
        if (state.isLoadingMore) UiUtils.progress()
      ],
    );
  }

}
