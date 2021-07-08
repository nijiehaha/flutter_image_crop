import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

class CutPage extends StatefulWidget {
  @override
  _CutPageState createState() => _CutPageState();
}

class _CutPageState extends State<CutPage> {
  /// 临时比例缩放大小
  double _tmpScale = 1.0;

  /// 最终比例缩放大小
  double _scale = 1.0;

  Offset _offset = Offset(0, 0);
  
  Offset _originOffset = Offset(0, 0);

  Offset _lastFocalPoint = Offset(0.0, 0.0);

  final _surfaceKey = GlobalKey();
  final _cropKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();

    _load();
  }

  _load() async {
    final image = await _loadImage();
    setState(() {
      _originOffset = Offset(image.width / 2, image.height / 2);
    });
  }

  Future<ui.Image> _loadImage() async {
    final provider = AssetImage("images/lufei.jpeg");
    Completer<ui.Image> completer = Completer<ui.Image>();
    ImageStreamListener listener;
    ImageStream stream = provider.resolve(ImageConfiguration.empty);
    listener = ImageStreamListener((ImageInfo frame, bool sync) {
      final ui.Image image = frame.image;
      completer.complete(image);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cut the Picture'),
        actions: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () async {
              RenderRepaintBoundary boundary =
                  _cropKey.currentContext.findRenderObject();
              ui.Image image = await boundary.toImage(pixelRatio: 1.0);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return ShowCutImagePage(image, _scale, _offset);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
          key: _surfaceKey,
          behavior: HitTestBehavior.opaque,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: (d) => _handleScaleUpdate(context.size, d),
          onScaleEnd: _handleScaleEnd,
          child: Stack(
            children: [
              Center(
                child: Transform(
                  origin: _originOffset,
                  transform: Matrix4.identity()
                    ..scale(_scale, _scale)
                    ..translate(_offset.dx, _offset.dy),
                  child: RepaintBoundary(
                    key: _cropKey,
                    child: Image.asset("images/lufei.jpeg"),
                  ),
                ),
              ),
              CustomPaint(
                size: Size(double.infinity, double.infinity),
                painter: DrawRectLight(
                  clipRect: Rect.fromLTWH(0, 0, 200, 200),
                ),
              ),
            ],
          )),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _tmpScale = _scale;
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    print(_offset);
  }

  void _handleScaleUpdate(Size size, ScaleUpdateDetails details) {
    setState(() {
      _scale = details.scale * _tmpScale;
      _offset += (details.focalPoint - _lastFocalPoint); //偏移量
      _lastFocalPoint = details.focalPoint; //保存最有一个Point
    });
  }
}

class ShowCutImagePage extends StatefulWidget {
  final ui.Image image;
  final double scale;
  final Offset offset;
  ShowCutImagePage(this.image, this.scale, this.offset);
  @override
  _ShowCutImagePageState createState() => _ShowCutImagePageState();
}

class _ShowCutImagePageState extends State<ShowCutImagePage> {
  ImageClipper clipper;
  @override
  void initState() {
    super.initState();
    clip();
  }

  clip() async {
    final image = await scaleRendered(widget.image);
    // final end = await offsetRendered(image);
    setState(() {
      clipper = ImageClipper(
        image,
        widget.scale,
        widget.offset,
      );
    });
  }

  offsetRendered(ui.Image image) async {
    final paint = Paint();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final w = image.width.toDouble();
    final h = image.height.toDouble();

    canvas.drawImage(image, widget.offset, paint);

    final picture = recorder.endRecording();
    ui.Image result = await picture.toImage(
      (w + widget.offset.dx).toInt(),
      (h + widget.offset.dy).toInt(),
    );

    return result;
  }

  scaleRendered(ui.Image image) async {
    final paint = Paint();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final src = Rect.fromLTWH(
      0,
      0,
      w,
      h,
    );
    final dst = Rect.fromLTWH(
      0,
      0,
      w * widget.scale,
      h * widget.scale,
    );
    canvas.drawImageRect(image, src, dst, paint);

    final picture = recorder.endRecording();
    ui.Image result = await picture.toImage(
        (w * widget.scale).toInt(), (h * widget.scale).toInt());

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cut Picture')),
      body: Center(
        child: CustomPaint(
          painter: clipper,
          size: Size(200, 200),
        ),
      ),
    );
  }
}

/// 图片裁剪
class ImageClipper extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;
  ImageClipper(this.image, this.scale, this.offset);
  @override
  Future<void> paint(Canvas canvas, Size size) async {
    Paint paint = Paint();

    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final src = Rect.fromLTWH(
      w / 2 - 100 + (offset * -1).dx * scale,
      h / 2 - 100 + (offset * -1).dy * scale,
      200,
      200,
    );
    final dst = Rect.fromLTWH(
      0.0,
      0.0,
      200,
      200,
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

/// 裁剪框
class DrawRectLight extends CustomPainter {
  final Rect clipRect;
  DrawRectLight({this.clipRect});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width / 2 - clipRect.width / 2,
        size.height / 2 - clipRect.height / 2, clipRect.width, clipRect.height);
    var paint = Paint();
    RRect _rrect = RRect.fromRectAndRadius(rect, Radius.zero);

    paint
      ..style = PaintingStyle.fill
      ..color = Color.fromRGBO(0, 0, 0, 0.5);
    canvas.save();

    Path path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTRB(0, 0, size.width, size.height)),
      Path()
        ..addRRect(_rrect)
        ..close(),
    );

    // Rect container = Offset.zero & size;
    // canvas.saveLayer(container, paint);
    canvas.drawPath(path, paint);
    canvas.restore();

    // final testrect =
    //     Rect.fromCenter(center: Offset(0, 0), width: 100, height: 100);

    // paint.blendMode = BlendMode.dstOut;
    // canvas.drawRect(testrect, paint..color = Colors.black);

    // canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
