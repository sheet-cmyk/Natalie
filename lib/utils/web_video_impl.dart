import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

void registerWebVideo(String viewId, String url) {
  if (_registered.contains(viewId)) return;
  _registered.add(viewId);
  ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
    final v = web.document.createElement('video') as web.HTMLVideoElement;
    v.src = url;
    v.autoplay = true;
    v.muted = true;
    v.loop = true;
    v.setAttribute('playsinline', '');
    v.style.width = '100%';
    v.style.height = '100%';
    v.style.objectFit = 'cover';
    v.style.display = 'block';
    return v;
  });
}

Widget buildNativeWebVideo(String url) {
  final viewId = 'banner_video_${url.hashCode}';
  registerWebVideo(viewId, url);
  return HtmlElementView(viewType: viewId);
}
