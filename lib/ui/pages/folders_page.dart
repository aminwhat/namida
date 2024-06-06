import 'package:flutter/material.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/folder_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  Widget get iconWidget => ObxO(
        rx: Folders.inst.isHome,
        builder: (isHome) => SizedBox(
          height: double.infinity,
          child: Icon(
            isHome ? Broken.home_2 : Broken.folder_2,
            size: 22.0,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = LibraryTab.folders.scrollController;
    final highlighedColor = context.theme.colorScheme.onSurface.withAlpha(40);
    const scrollToIconSize = 24.0;
    const scrollToiconBottomPaddingSliver = SliverPadding(padding: EdgeInsets.only(bottom: scrollToIconSize * 2));
    return BackgroundWrapper(
      child: Stack(
        children: [
          Obx(
            () {
              final mainMapFoldersKeys = Indexer.inst.mainMapFolders.keys.toList();
              return settings.enableFoldersHierarchy.valueR

                  // == Folders in heirarchy
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                          child: Obx(
                            () => CustomListTile(
                              borderR: 16.0,
                              icon: Folders.inst.isHome.valueR ? Broken.home_2 : Broken.folder_2,
                              title: Folders.inst.currentFolder.valueR?.path.formatPath() ?? lang.HOME,
                              titleStyle: context.textTheme.displaySmall,
                              onTap: () => Folders.inst.stepOut(),
                              trailingRaw: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Obx(
                                    () {
                                      final pathOfDefault = Folders.inst.isHome.valueR ? '' : Folders.inst.currentFolder.valueR?.path;
                                      return NamidaIconButton(
                                        horizontalPadding: 8.0,
                                        tooltip: lang.SET_AS_DEFAULT,
                                        icon: settings.defaultFolderStartupLocation.valueR == pathOfDefault ? Broken.archive_tick : Broken.save_2,
                                        iconSize: 22.0,
                                        onPressed: () => settings.save(
                                          defaultFolderStartupLocation: Folders.inst.currentFolder.value?.path ?? '',
                                        ),
                                      );
                                    },
                                  ),
                                  NamidaIconButton(
                                    horizontalPadding: 8.0,
                                    icon: Broken.sort,
                                    onPressed: () {
                                      NamidaOnTaps.inst.onSubPageTracksSortIconTap(MediaType.folder);
                                    },
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: NamidaScrollbar(
                            controller: scrollController,
                            child: Obx(
                              () {
                                final folderTracks = Folders.inst.currentFolder.valueR?.tracks() ?? [];
                                return CustomScrollView(
                                  controller: scrollController,
                                  slivers: [
                                    if (Folders.inst.isHome.valueR)
                                      SliverList.builder(
                                        itemCount: kStoragePaths.length,
                                        itemBuilder: (context, i) {
                                          final p = kStoragePaths.elementAt(i);
                                          return FolderTile(
                                            folder: Folder(p),
                                            dummyTracks: Folder(p).tracksRecusive().toList(),
                                          );
                                        },
                                      ),
                                    if (!Folders.inst.isHome.valueR) ...[
                                      SliverList.builder(
                                        itemCount: Folders.inst.currentFolderslist.length,
                                        itemBuilder: (context, i) {
                                          return FolderTile(
                                            folder: Folders.inst.currentFolderslist[i],
                                          );
                                        },
                                      ),
                                      SliverFixedExtentList.builder(
                                        itemCount: folderTracks.length,
                                        itemExtent: Dimensions.inst.trackTileItemExtent,
                                        itemBuilder: (context, i) {
                                          return TrackTile(
                                            index: i,
                                            trackOrTwd: folderTracks[i],
                                            queueSource: QueueSource.folder,
                                            bgColor: i == Folders.inst.indexToScrollTo.value ? highlighedColor : null,
                                          );
                                        },
                                      ),
                                    ],
                                    kBottomPaddingWidgetSliver,
                                    scrollToiconBottomPaddingSliver,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    )

                  // == All Folders
                  : Column(
                      children: [
                        ListTile(
                          leading: iconWidget,
                          title: ObxO(
                            rx: Folders.inst.currentFolder,
                            builder: (currentFolder) => Text(
                              currentFolder?.path.formatPath() ?? lang.HOME,
                              style: context.textTheme.displaySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () => Folders.inst.stepOut(),
                        ),
                        Expanded(
                          child: NamidaScrollbar(
                            controller: scrollController,
                            child: Obx(
                              () {
                                final folderTracks = Folders.inst.currentFolder.valueR?.tracks() ?? [];
                                return CustomScrollView(
                                  controller: scrollController,
                                  slivers: [
                                    if (!Folders.inst.isInside.valueR)
                                      SliverList.builder(
                                        itemCount: Indexer.inst.mainMapFolders.length,
                                        itemBuilder: (context, i) {
                                          final folder = mainMapFoldersKeys[i];
                                          if (folder.tracks().isEmpty) return const SizedBox();
                                          return FolderTile(
                                            folder: folder,
                                            subtitle: folder.hasSimilarFolderNames ? folder.parent.path.formatPath() : null,
                                          );
                                        },
                                      ),
                                    SliverFixedExtentList.builder(
                                      itemCount: folderTracks.length,
                                      itemExtent: Dimensions.inst.trackTileItemExtent,
                                      itemBuilder: (context, i) {
                                        final tr = folderTracks[i];
                                        return TrackTile(
                                          index: i,
                                          trackOrTwd: tr,
                                          queueSource: QueueSource.folder,
                                          bgColor: i == Folders.inst.indexToScrollTo.value ? highlighedColor : null,
                                        );
                                      },
                                    ),
                                    kBottomPaddingWidgetSliver,
                                    scrollToiconBottomPaddingSliver,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
            },
          ),
          Obx(
            () => Folders.inst.indexToScrollTo.value != null
                ? Positioned(
                    bottom: Dimensions.inst.globalBottomPaddingEffective + 8.0,
                    right: kFABHeight + 12.0 + 8.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: NamidaIconButton(
                        padding: const EdgeInsets.all(7.0),
                        onPressed: () {
                          scrollController.animateToEff(Dimensions.inst.trackTileItemExtent * (Folders.inst.indexToScrollTo.value! + Folders.inst.currentFolderslist.length - 2),
                              duration: const Duration(milliseconds: 400), curve: Curves.bounceInOut);
                        },
                        icon: Broken.arrow_circle_down,
                      ),
                    ),
                  )
                : const SizedBox(),
          )
        ],
      ),
    );
  }
}
