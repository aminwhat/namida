import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class NamidaAudioVideoHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final _player = AudioPlayer();

  final Player namidaPlayer;

  RxList<Track> get currentQueue => namidaPlayer.currentQueue;
  Rx<Track> get nowPlayingTrack => namidaPlayer.nowPlayingTrack;
  RxInt get nowPlayingPosition => namidaPlayer.nowPlayingPosition;
  RxInt get currentIndex => namidaPlayer.currentIndex;
  RxDouble get currentVolume => namidaPlayer.currentVolume;
  RxBool get isPlaying => namidaPlayer.isPlaying;
  bool get isLastTrack => currentIndex.value == currentQueue.length - 1;

  NamidaAudioVideoHandler(this.namidaPlayer) {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    _player.playbackEventStream.listen((event) {
      QueueController.inst.updateLatestQueue(currentQueue.toList());
    });

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        final repeat = SettingsController.inst.playerRepeatMode.value;
        if (repeat == RepeatMode.none) {
          skipToNext(!isLastTrack);
        }
        if (repeat == RepeatMode.one) {
          skipToQueueItem(currentIndex.value);
        }
        if (repeat == RepeatMode.all) {
          skipToNext();
        }
      }
    });

    _player.volumeStream.listen((event) {
      currentVolume.value = event;
    });

    _player.positionStream.listen((event) {
      nowPlayingPosition.value = event.inMilliseconds;
    });

    _player.playingStream.listen((event) async {
      isPlaying.value = event;
      await updateVideoPlayingState();
    });

    _player.positionStream.listen((event) {
      nowPlayingPosition.value = event.inMilliseconds;
    });

    // Attempt to fix video position after switching to bg or turning off screen
    _player.positionDiscontinuityStream.listen((event) async {
      await updateVideoPlayingState();
    });
  }

  /// For ensuring stabilty while fade effect is on.
  /// Typically stops ongoing [playWithFadeEffect] to prevent multiple [setVolume] interferring.
  bool wantToPause = false;

  void increaseListenTime(Track track) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      nowPlayingTrack.listen((p0) {
        if (track != p0) {
          timer.cancel();
          return;
        }
      });
      if (isPlaying.value) {
        SettingsController.inst.save(totalListenedTimeInSec: SettingsController.inst.totalListenedTimeInSec.value + 1);
      }
    });
  }

  //
  // Video Methods
  Future<void> updateVideoPlayingState() async {
    await refreshVideoPosition();
    if (isPlaying.value) {
      VideoController.inst.play();
    } else {
      VideoController.inst.pause();
    }
    await refreshVideoPosition();
  }

  Future<void> refreshVideoPosition() async {
    await VideoController.inst.seek(Duration(milliseconds: nowPlayingPosition.value));
  }

  // End of Video Methods.
  //

  //
  // Namida Methods.
  Future<void> setAudioSource(int index, {bool preload = true, bool startPlaying = true}) async {
    final tr = currentQueue.elementAt(index);
    nowPlayingTrack.value = tr;
    currentIndex.value = index;
    CurrentColor.inst.updatePlayerColor(tr, index);
    _player.pause();
    _player.setFilePath(tr.path, preload: preload);

    /// Te whole idea of pausing and playing is due to the bug where [headset buttons/android next gesture] don't get detected.
    if (startPlaying) {
      _player.play();
      setVolume(SettingsController.inst.playerVolume.value);
    }
    updateCurrentMediaItem(tr);

    WaveformController.inst.generateWaveform(tr);
    PlaylistController.inst.addToHistory(nowPlayingTrack.value);
    increaseListenTime(tr);
    SettingsController.inst.save(lastPlayedTrackPath: tr.path);
    Lyrics.inst.updateLyrics(tr);

    /// for video
    VideoController.inst.updateLocalVidPath(tr);
    updateVideoPlayingState();
  }

  /// if [force] is enabled, [track] will not be used.
  void updateCurrentMediaItem([Track? track, bool force = false]) {
    if (force) {
      playbackState.add(_transformEvent(PlaybackEvent()));
      return;
    }
    track ??= nowPlayingTrack.value;
    mediaItem.add(track.toMediaItem);
  }

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await pause();
    } else {
      await play();
      await seek(Duration(milliseconds: nowPlayingPosition.value));
    }
  }

  Future<void> playWithFadeEffect() async {
    final duration = SettingsController.inst.playerPlayFadeDurInMilli.value;
    final interval = (0.05 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = 0.0;
    await setVolume(0.0);
    _player.play();
    Timer.periodic(Duration(milliseconds: interval), (timer) {
      vol += 1 / steps;
      printInfo(info: "Fade Volume Play: ${vol.toString()}");
      setVolume(vol);
      if (vol >= SettingsController.inst.playerVolume.value || wantToPause) {
        timer.cancel();
      }
    });
  }

  Future<void> pauseWithFadeEffect() async {
    final duration = SettingsController.inst.playerPauseFadeDurInMilli.value;
    final interval = (0.05 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = currentVolume.value;
    Timer.periodic(Duration(milliseconds: interval), (timer) {
      vol -= 1 / steps;
      printInfo(info: "Fade Volume Pause ${vol.toString()}");
      setVolume(vol);
      if (vol <= 0.0) {
        timer.cancel();
        _player.pause();
      }
    });
  }

  void reorderTrack(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    int i = currentIndex.value;
    if (oldIndex == currentIndex.value) {
      i = newIndex;
    }

    /// Track is dragged from after the currentTrack to before the currentTrack.
    if (oldIndex < currentIndex.value && newIndex >= currentIndex.value) {
      i = currentIndex.value - 1;
    }

    /// Track is dragged from before the currentTrack to after the currentTrack.
    if (oldIndex > currentIndex.value && newIndex - 1 <= currentIndex.value) {
      i = currentIndex.value + 1;
    }

    currentIndex.value = i;
    CurrentColor.inst.currentPlayingIndex.value = i;
    final item = currentQueue.elementAt(oldIndex);
    removeFromQueue(oldIndex);
    insertInQueue([item], newIndex);
  }

  void shuffleNextTracks() {
    final List<Track> newTracks = [];
    final first = currentIndex.value + 1;
    final last = currentQueue.length - 1;
    newTracks
      ..assignAll(currentQueue.getRange(first, last))
      ..shuffle();
    removeRangeFromQueue(first, last);
    insertInQueue(newTracks, first);
  }

  Future<void> addToQueue(List<Track> tracks, {bool insertNext = false}) async {
    if (insertNext) {
      insertInQueue(tracks, currentIndex.value + 1);
    } else {
      currentQueue.addAll(tracks);
    }
    afterQueueChange();
  }

  Future<void> insertInQueue(List<Track> tracks, int index) async {
    currentQueue.insertAll(index, tracks);
    afterQueueChange();
  }

  Future<void> removeFromQueue(int index) async {
    if (index == currentIndex.value) {
      if (currentQueue.isNotEmpty) {
        if (isLastTrack) {
          setAudioSource(index - 1);
        } else {
          setAudioSource(index);
        }
      }
    }
    currentQueue.removeAt(index);
    final ci = currentIndex.value;
    if (index < ci) {
      currentIndex.value = ci - 1;
      CurrentColor.inst.currentPlayingIndex.value = ci - 1;
    }
    afterQueueChange();
  }

  Future<void> removeRangeFromQueue(int start, int end) async {
    currentQueue.removeRange(start, end);
    afterQueueChange();
  }

  void afterQueueChange() {
    updateCurrentMediaItem();
    QueueController.inst.updateLatestQueue(currentQueue.toList());
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  // End of Namida Methods.
  //

  //
  // audio_service overriden methods.
  @override
  Future<void> play() async {
    wantToPause = false;

    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && nowPlayingPosition.value > 200) {
      await playWithFadeEffect();
    } else {
      _player.play();
      setVolume(SettingsController.inst.playerVolume.value);
    }
  }

  @override
  Future<void> pause() async {
    wantToPause = true;
    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && nowPlayingPosition.value > 200) {
      await pauseWithFadeEffect();
    } else {
      _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    int p = position.inMilliseconds;
    if (p < 0) {
      p = 0;
    }
    await _player.seek(p.milliseconds);
    await VideoController.inst.seek(p.milliseconds);
  }

  @override
  Future<void> stop() async => await _player.stop();

  @override
  Future<void> skipToNext([bool andPlay = true]) async {
    if (isLastTrack) {
      skipToQueueItem(0, andPlay);
    } else {
      skipToQueueItem(currentIndex.value + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (currentIndex.value == 0) {
      skipToQueueItem(currentQueue.length - 1);
    } else {
      skipToQueueItem(currentIndex.value - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index, [bool andPlay = true]) async {
    await setAudioSource(index, startPlaying: andPlay);
  }

  // End of  audio_service overriden methods.
  //

  //
  // Media Control Specific
  @override
  Future<void> fastForward() async {
    PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack.value);
    updateCurrentMediaItem(null, true);
  }

  @override
  Future<void> rewind() async {
    PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack.value);
    updateCurrentMediaItem(null, true);
  }

  /// [fastForward] is favourite track.
  /// [rewind] is unfavourite track.
  PlaybackState _transformEvent(PlaybackEvent event) {
    final List<int> iconsIndexes = [0, 1, 2];
    final List<MediaControl> fmc = [
      MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];
    if (SettingsController.inst.displayFavouriteButtonInNotification.value) {
      fmc.insert(0, Player.inst.nowPlayingTrack.value.isFavourite ? MediaControl.fastForward : MediaControl.rewind);
      iconsIndexes.assignAll(const [1, 2, 3]);
    }
    return PlaybackState(
      controls: fmc,
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: iconsIndexes,
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

extension MediaItemToAudioSource on MediaItem {
  AudioSource get toAudioSource => AudioSource.uri(Uri.parse(id));
}

extension MediaItemsListToAudioSources on List<MediaItem> {
  List<AudioSource> get toAudioSources => map((e) => e.toAudioSource).toList();
}

extension TrackToAudioSourceMediaItem on Track {
  UriAudioSource get toAudioSource {
    return AudioSource.uri(
      Uri.parse(path),
      tag: toMediaItem,
    );
  }

  MediaItem get toMediaItem => MediaItem(
        id: path,
        title: title,
        displayTitle: title,
        displaySubtitle: "${artistsList.take(3).join(', ')} - $album",
        displayDescription: "${Player.inst.currentIndex.value + 1}/${Player.inst.currentQueue.length}",
        artist: artistsList.take(3).join(', '),
        album: album,
        genre: genresList.take(3).join(', '),
        duration: Duration(milliseconds: duration),
        artUri: Uri.file(File(pathToImage).existsSync() ? pathToImage : kDefaultNamidaImagePath),
      );
}

extension TracksListToAudioSourcesMediaItems on List<Track> {
  List<AudioSource> get toAudioSources => map((e) => e.toAudioSource).toList();
  List<MediaItem> get toMediaItems => map((e) => e.toMediaItem).toList();
  ConcatenatingAudioSource get toConcatenatingAudioSource => ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: map((e) => e.toAudioSource).toList(),
      );
}