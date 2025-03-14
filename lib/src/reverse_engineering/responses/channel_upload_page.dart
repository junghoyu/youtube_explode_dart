import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

import '../../channels/channel_video.dart';
import '../../exceptions/exceptions.dart';
import '../../extensions/helpers_extension.dart';
import '../../retry.dart';
import '../../videos/videos.dart';
import '../youtube_http_client.dart';

///
class ChannelUploadPage {
  ///
  final String channelId;
  final Document? _root;

  late final _InitialData initialData = _getInitialData();
  _InitialData? _initialData;

  ///
  _InitialData _getInitialData() {
    if (_initialData != null) {
      return _initialData!;
    }
    final scriptText = _root!
        .querySelectorAll('script')
        .map((e) => e.text)
        .toList(growable: false);

    return scriptText.extractGenericData(
        (obj) => _InitialData(obj),
        () => TransientFailureException(
            'Failed to retrieve initial data from the channel upload page, please report this to the project GitHub page.'));
  }

  ///
  ChannelUploadPage(this._root, this.channelId, [_InitialData? initialData])
      : _initialData = initialData;

  ///
  Future<ChannelUploadPage?> nextPage(YoutubeHttpClient httpClient) {
    if (initialData.token.isEmpty) {
      return Future.value(null);
    }

    final url = Uri.parse(
        'https://www.youtube.com/youtubei/v1/browse?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8');

    final body = {
      'context': const {
        'client': {
          'hl': 'en',
          'clientName': 'WEB',
          'clientVersion': '2.20200911.04.00'
        }
      },
      'continuation': initialData.token
    };
    return retry(() async {
      var raw = await httpClient.post(url, body: json.encode(body));
      return ChannelUploadPage(
          null, channelId, _InitialData(json.decode(raw.body)));
    });
  }

  ///
  static Future<ChannelUploadPage> get(
      YoutubeHttpClient httpClient, String channelId, String sorting) {
    var url =
        'https://www.youtube.com/channel/$channelId/videos?view=0&sort=$sorting&flow=grid';
    return retry(() async {
      var raw = await httpClient.getString(url);
      return ChannelUploadPage.parse(raw, channelId);
    });
  }

  ///
  ChannelUploadPage.parse(String raw, this.channelId)
      : _root = parser.parse(raw);
}

class _InitialData {
  // Json parsed map
  final Map<String, dynamic> root;

  _InitialData(this.root);

  late final Map<String, dynamic>? continuationContext =
      getContinuationContext();

  late final String token = continuationContext?.getT<String>('token') ?? '';

  late final List<ChannelVideo> uploads =
      getContentContext().map(_parseContent).whereNotNull().toList();

  List<Map<String, dynamic>> getContentContext() {
    List<Map<String, dynamic>>? context;
    if (root.containsKey('contents')) {
      context = root
          .get('contents')
          ?.get('twoColumnBrowseResultsRenderer')
          ?.getList('tabs')
          ?.map((e) => e['tabRenderer'])
          .cast<Map<String, dynamic>>()
          .firstWhereOrNull((e) => e['selected'] as bool)
          ?.get('content')
          ?.get('sectionListRenderer')
          ?.getList('contents')
          ?.firstOrNull
          ?.get('itemSectionRenderer')
          ?.getList('contents')
          ?.firstOrNull
          ?.get('gridRenderer')
          ?.getList('items')
          ?.cast<Map<String, dynamic>>();
    }
    if (context == null && root.containsKey('onResponseReceivedActions')) {
      context = root
          .getList('onResponseReceivedActions')
          ?.firstOrNull
          ?.get('appendContinuationItemsAction')
          ?.getList('continuationItems')
          ?.cast<Map<String, dynamic>>();
    }
    if (context == null) {
      throw FatalFailureException('Failed to get initial data context.');
    }
    return context;
  }

  Map<String, dynamic>? getContinuationContext() {
    if (root.containsKey('contents')) {
      return root
          .get('contents')
          ?.get('twoColumnBrowseResultsRenderer')
          ?.getList('tabs')
          ?.map((e) => e['tabRenderer'])
          .cast<Map<String, dynamic>>()
          .firstWhereOrNull((e) => e['selected'] as bool)
          ?.get('content')
          ?.get('sectionListRenderer')
          ?.getList('contents')
          ?.firstOrNull
          ?.get('itemSectionRenderer')
          ?.getList('contents')
          ?.firstOrNull
          ?.get('gridRenderer')
          ?.getList('items')
          ?.firstWhereOrNull((e) => e['continuationItemRenderer'] != null)
          ?.get('continuationItemRenderer')
          ?.get('continuationEndpoint')
          ?.get('continuationCommand');
    }
    if (root.containsKey('onResponseReceivedActions')) {
      return root
          .getList('onResponseReceivedActions')
          ?.firstOrNull
          ?.get('appendContinuationItemsAction')
          ?.getList('continuationItems')
          ?.firstWhereOrNull((e) => e['continuationItemRenderer'] != null)
          ?.get('continuationItemRenderer')
          ?.get('continuationEndpoint')
          ?.get('continuationCommand');
    }
    return null;
  }

  ChannelVideo? _parseContent(Map<String, dynamic>? content) {
    if (content == null || !content.containsKey('gridVideoRenderer')) {
      return null;
    }

    var video = content.get('gridVideoRenderer')!;
    return ChannelVideo(
      VideoId(video.getT<String>('videoId')!),
      video.get('title')?.getT<String>('simpleText') ??
          video.get('title')?.getList('runs')?.map((e) => e['text']).join() ??
          '',
      video
              .getList('thumbnailOverlays')
              ?.firstOrNull
              ?.get('thumbnailOverlayTimeStatusRenderer')
              ?.get('text')
              ?.getT<String>('simpleText')
              ?.toDuration() ??
          Duration.zero,
      video.get('thumbnail')?.getList('thumbnails')?.last.getT<String>('url') ??
          '',
      video.get('publishedTimeText')?.getT<String>('simpleText') ?? '',
      video.get('viewCountText')?.getT<String>('simpleText')?.parseInt() ?? 0,
    );
  }
}

//
