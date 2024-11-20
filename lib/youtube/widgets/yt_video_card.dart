import 'package:flutter/material.dart';

import 'package:jiffy/jiffy.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/result_wrapper/playlist_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeVideoCard extends StatelessWidget {
  final StreamInfoItem video;
  final PlaylistID? playlistID;
  final bool isImageImportantInCache;
  final void Function()? onTap;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final YoutiPiePlaylistResultBase? playlist;
  final ({int index, int totalLength, String playlistId})? playlistIndexAndCount;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;
  final bool dateInsteadOfChannel;
  final bool showThirdLine;

  const YoutubeVideoCard({
    super.key,
    required this.video,
    required this.playlistID,
    required this.isImageImportantInCache,
    this.onTap,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playlist,
    this.playlistIndexAndCount,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
    this.dateInsteadOfChannel = false,
    this.showThirdLine = true,
  });

  List<NamidaPopupItem> getMenuItems() {
    final videoId = video.id;
    return YTUtils.getVideoCardMenuItems(
      downloadIndex: playlistIndexAndCount?.index,
      totalLength: playlistIndexAndCount?.totalLength,
      playlistId: playlistIndexAndCount?.playlistId,
      streamInfoItem: video,
      videoId: videoId,
      channelID: video.channel.id,
      playlistID: playlistID,
      idsNamesLookup: {videoId: video.title},
      playlistName: playlist?.basicInfo.title ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoId = video.id;
    final viewsCount = video.viewsCount;
    String? viewsCountText = video.viewsText;
    if (viewsCount != null) {
      viewsCountText = viewsCount.displayViewsKeywordShort;
    }

    DateTime? publishedDate = video.publishedAt.date;
    final uploadDateAgo = publishedDate == null ? null : Jiffy.parseFromDateTime(publishedDate).fromNow();

    final percentageWatched = video.percentageWatched;

    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: YoutubeCard(
        thumbnailType: ThumbnailType.video,
        thumbnailWidthPercentage: thumbnailWidthPercentage,
        fontMultiplier: fontMultiplier,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        isImageImportantInCache: isImageImportantInCache,
        borderRadius: 12.0,
        videoId: videoId,
        thumbnailUrl: null,
        shimmerEnabled: false,
        title: video.title,
        subtitle: [
          if (viewsCountText != null && viewsCountText.isNotEmpty) viewsCountText,
          if (uploadDateAgo != null) uploadDateAgo,
        ].join(' - '),
        displaythirdLineText: showThirdLine,
        thirdLineText: dateInsteadOfChannel
            ? video.badges?.join(' - ') ?? ''
            : video.channel.title.isNotEmpty
                ? video.channel.title
                : video.channelName ?? '',
        displayChannelThumbnail: !dateInsteadOfChannel,
        channelThumbnailUrl: video.channel.thumbnails.pick()?.url ?? YoutubeInfoController.utils.getVideoChannelThumbnails(videoId, checkFromStorage: false)?.pick()?.url,
        onTap: onTap ??
            () async {
              _VideoCardUtils.onVideoTap(
                videoId: videoId,
                index: playlistIndexAndCount?.index,
                playlist: playlist,
                playlistID: playlistID,
              );
            },
        smallBoxText: video.durSeconds?.secondsLabel,
        bottomRightWidgets: YTUtils.getVideoCacheStatusIcons(videoId: videoId, context: context),
        menuChildrenDefault: getMenuItems,
        extractColor: false,
        onTopWidgets: percentageWatched == null
            ? null
            : (thumbWidth, thumbHeight, imageColors) => [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: SizedBox(
                      height: 1.25,
                      width: thumbWidth * percentageWatched,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(140, 255, 20, 20),
                        ),
                      ),
                    ),
                  ),
                ],
      ),
    );
  }
}

class YoutubeShortVideoCard extends StatelessWidget {
  final StreamInfoItemShort short;
  final PlaylistID? playlistID;
  final void Function()? onTap;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final YoutiPiePlaylistResult? playlist;
  final int? index;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;

  const YoutubeShortVideoCard({
    super.key,
    required this.short,
    this.playlistID,
    this.onTap,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playlist,
    this.index,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
  });

  List<NamidaPopupItem> getMenuItems() {
    final videoId = short.id;
    return YTUtils.getVideoCardMenuItems(
      downloadIndex: null,
      totalLength: null,
      streamInfoItem: null,
      videoId: videoId,
      channelID: null,
      playlistID: playlistID,
      idsNamesLookup: {videoId: short.title},
      playlistName: playlist?.basicInfo.title ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String videoId = short.id;
    final String viewsCountText = short.viewsText;

    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: YoutubeCard(
        thumbnailType: ThumbnailType.video,
        thumbnailWidthPercentage: thumbnailWidthPercentage,
        fontMultiplier: fontMultiplier,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        isImageImportantInCache: false,
        borderRadius: 12.0,
        videoId: short.id,
        thumbnailUrl: null,
        shimmerEnabled: false,
        title: short.title,
        subtitle: viewsCountText,
        displaythirdLineText: false,
        thirdLineText: '',
        displayChannelThumbnail: false,
        channelThumbnailUrl: null,
        onTap: onTap ??
            () {
              _VideoCardUtils.onVideoTap(
                videoId: videoId,
                index: index,
                playlist: playlist,
                playlistID: playlistID,
              );
            },
        bottomRightWidgets: YTUtils.getVideoCacheStatusIcons(videoId: short.id, context: context),
        menuChildrenDefault: getMenuItems,
      ),
    );
  }
}

class YoutubeShortVideoTallCard extends StatelessWidget {
  final int index;
  final StreamInfoItemShort short;
  final double thumbnailWidth;
  final double? thumbnailHeight;

  const YoutubeShortVideoTallCard({
    super.key,
    required this.index,
    required this.short,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
  });

  List<NamidaPopupItem> getMenuItems() {
    final videoId = short.id;
    return YTUtils.getVideoCardMenuItems(
      downloadIndex: null,
      totalLength: null,
      streamInfoItem: null,
      videoId: videoId,
      channelID: null,
      playlistID: null,
      idsNamesLookup: {videoId: short.title},
    );
  }

  Future<void> _onShortTap() => _VideoCardUtils.onVideoTap(videoId: short.id);

  @override
  Widget build(BuildContext context) {
    final videoId = short.id;
    final title = short.title;
    final viewsCountText = short.viewsText;
    final thumbnail = short.liveThumbs.pick()?.url;

    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        borderRadius: 8.0,
        onTap: _onShortTap,
        child: YoutubeThumbnail(
          key: Key(videoId),
          borderRadius: 8.0,
          videoId: videoId,
          customUrl: thumbnail,
          width: thumbnailWidth,
          height: thumbnailHeight,
          isImportantInCache: false,
          type: ThumbnailType.video,
          onTopWidgets: (color) {
            return [
              Positioned(
                bottom: 0,
                left: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: SizedBox(
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: context.textTheme.displayMedium?.copyWith(
                            fontSize: 12.0,
                            color: Colors.white70,
                            shadows: [
                              const BoxShadow(
                                spreadRadius: 1.0,
                                blurRadius: 12.0,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          viewsCountText,
                          style: context.textTheme.displaySmall?.copyWith(
                            fontSize: 11.0,
                            color: Colors.white60,
                            shadows: [
                              const BoxShadow(
                                spreadRadius: 1.0,
                                blurRadius: 12.0,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

class YoutubeVideoCardDummy extends StatelessWidget {
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;
  final bool shimmerEnabled;
  final bool displaythirdLineText;
  final bool dateInsteadOfChannel;

  const YoutubeVideoCardDummy({
    super.key,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
    required this.shimmerEnabled,
    this.displaythirdLineText = true,
    this.dateInsteadOfChannel = false,
  });

  @override
  Widget build(BuildContext context) {
    return YoutubeCard(
      thumbnailType: ThumbnailType.video,
      thumbnailWidthPercentage: thumbnailWidthPercentage,
      fontMultiplier: fontMultiplier,
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
      isImageImportantInCache: false,
      borderRadius: 12.0,
      videoId: null,
      thumbnailUrl: null,
      shimmerEnabled: shimmerEnabled,
      title: '',
      subtitle: '',
      displaythirdLineText: displaythirdLineText,
      thirdLineText: '',
      displayChannelThumbnail: !dateInsteadOfChannel,
      channelThumbnailUrl: null,
    );
  }
}

class _VideoCardUtils {
  static Future<void> onVideoTap({
    required String videoId,
    PlaylistID? playlistID,
    int? index,
    YoutiPiePlaylistResultBase? playlist,
  }) async {
    YTUtils.expandMiniplayer();
    return Player.inst.playOrPause(
      0,
      [YoutubeID(id: videoId, playlistID: playlistID)],
      QueueSource.others,
      onAssigningCurrentItem: (currentItem) async {
        // -- add the remaining playlist videos, only if the same item is still playing

        if (playlist != null && index != null) {
          await playlist.basicInfo.fetchAllPlaylistStreams(showProgressSheet: false, playlist: playlist);
          if (currentItem != Player.inst.currentItem.value) return; // nvm if item changed
          if (currentItem is YoutubeID && currentItem.id == videoId) {
            try {
              final firstHalf = playlist.items.getRange(0, index).map((e) => YoutubeID(id: e.id, playlistID: playlistID));
              final lastHalf = playlist.items.getRange(index + 1, playlist.items.length).map((e) => YoutubeID(id: e.id, playlistID: playlistID));

              Player.inst.addToQueue(lastHalf); // adding first bcz inserting would mess up indexes in lastHalf.
              await Player.inst.insertInQueue(firstHalf, 0);
            } catch (e) {
              printo(e, isError: true);
            }
          }
        }
      },
    );
  }
}
