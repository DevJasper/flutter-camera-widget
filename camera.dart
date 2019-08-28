import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class Camera extends StatefulWidget {
  List<CameraDescription> cameras;
  CameraState state;

  Camera(List<CameraDescription> cameras) {
    this.cameras = cameras;
  }

  @override
  CameraState createState() {
    this.state = new CameraState();
    return this.state;
  }

  CameraState getState() {
    return this.state;
  }
}

class CameraState extends State<Camera> with WidgetsBindingObserver {
  CameraController controller;
  String imagePath;
  String videoPath;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;
  bool startedRecording = false;
  bool stoppedRecording = false;
  bool stoppedPlaying = false;
  bool recapture = false;
  final int maxRecordDuration = 10;
  int videoDurationCounter = 0;

  @override
  void initState() {
    super.initState();
    onNewCameraSelected(widget.cameras[0]);

    if (widget.cameras.isEmpty) {
      print('No camera found');
    } else {
      if (controller == null && !controller.value.isRecordingVideo)
        onNewCameraSelected(widget.cameras[0]);
    }

    WidgetsBinding.instance.addObserver(this);
    // videoController.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        onNewCameraSelected(controller.description);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return cameraPreviewWidget();
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget cameraPreviewWidget() {
    // videoController.pause();

    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return
          //  AspectRatio(
          //aspectRatio: controller.value.aspectRatio,
          //child:
          Stack(children: <Widget>[
        CameraPreview(controller),
        Container(
          // height: double.infinity,
          // width: double.infinity,
          child: Align(
            alignment: Alignment.centerRight,
            child: videoController == null && imagePath == null
                ? null
                : SizedBox(
                    child: (videoController == null)
                        ? Image.file(File(imagePath))
                        : !recapture
                            ? Container(
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio:
                                        videoController.value.size != null
                                            ? videoController.value.aspectRatio
                                            : 1.0,
                                    child: VideoPlayer(videoController),
                                  ),
                                ),
                                // decoration: BoxDecoration(
                                //     border: Border.all(color: Colors.pink)),
                              )
                            : Container(),
                    // height: double.infinity,
                    // width: double.infinity
                  ),
          ),
        ),
        Center(
          // left:  30.0,
          // top: 30.0,
          child: stoppedRecording
              ? RaisedButton(
                  onPressed: () {
                    final int duration =
                        videoController.value.duration.inMilliseconds;
                    final int position =
                        videoController.value.position.inMilliseconds;

                    if (position == duration) {
                      videoController.seekTo(new Duration(seconds: 0));
                    }

                    if (videoController.value.isPlaying) {
                      videoController.pause();
                      return;
                    }

                    videoController.play();
                  },
                  child: videoController.value.isPlaying
                      ? Icon(Icons.pause_circle_filled, color: Colors.black)
                      : Icon(Icons.play_circle_filled, color: Colors.black),
                )
              : Text(
                  videoDurationCounter <= 0
                      ? "Start recording"
                      : "${videoDurationCounter}",
                  style: new TextStyle(
                    color: Colors.white,
                    fontSize: 19.0,
                  ),
                ),
        ),
        stoppedRecording
            ? Positioned(
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RaisedButton(
                        child: Text("Retake",
                            style: new TextStyle(
                              color: Colors.white,
                            )),
                        onPressed: () {
                          if (controller != null &&
                              controller.value.isInitialized &&
                              !controller.value.isRecordingVideo) {
                            onVideoRecordButtonPressed();
                          }
                        }),
                    RaisedButton(
                        child: Text("Proceed",
                            style: new TextStyle(
                              color: Colors.white,
                            )),
                        onPressed: () {}),
                  ],
                ))
            : Container(),
      ]);
      //);
    }
  }

  /// Display the thumbnail of the captured image or video.
  Widget thumbnailWidget() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: videoController == null && imagePath == null
            ? null
            : SizedBox(
                child: (videoController == null)
                    ? Image.file(File(imagePath))
                    : Container(
                        child: Center(
                          child: AspectRatio(
                              aspectRatio: videoController.value.size != null
                                  ? videoController.value.aspectRatio
                                  : 1.0,
                              child: VideoPlayer(videoController)),
                        ),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.pink)),
                      ),
                width: 64.0,
                height: 64.0,
              ),
      ),
    );
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: controller != null &&
                  controller.value.isInitialized &&
                  !controller.value.isRecordingVideo
              ? onTakePictureButtonPressed
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          color: Colors.blue,
          onPressed: controller != null &&
                  controller.value.isInitialized &&
                  !controller.value.isRecordingVideo
              ? onVideoRecordButtonPressed
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.stop),
          color: Colors.red,
          onPressed: controller != null &&
                  controller.value.isInitialized &&
                  controller.value.isRecordingVideo
              ? onStopButtonPressed
              : null,
        )
      ],
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (widget.cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in widget.cameras) {
        toggles.add(
          SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: controller != null && controller.value.isRecordingVideo
                  ? null
                  : onNewCameraSelected,
            ),
          ),
        );
      }
    }

    return Row(children: toggles);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(cameraDescription, ResolutionPreset.high);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        //showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          videoController?.dispose();
          videoController = null;
        });
        //if (filePath != null) showInSnackBar('Picture saved to $filePath');
      }
    });
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String filePath) {
      if (mounted)
        setState(() {
          startedRecording = true;
        });

      if (filePath != null) print('Saving video to $filePath');
      if (stoppedRecording) {
        setState(() {
          stoppedRecording = false;
        });
      }
    });

    new Timer.periodic(
        new Duration(seconds: 1),
        (Timer timer) => setState(() {
              if (videoDurationCounter >= maxRecordDuration) {
                timer.cancel();
              } else {
                videoDurationCounter++;
              }
            }));
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((_) {
      if (mounted)
        setState(() {
          startedRecording = false;
          stoppedRecording = true;
          videoDurationCounter = 0;
        });
      print("Recording stopped");
      //showInSnackBar('Video recorded to: $videoPath');
    });
  }

  Future<String> startVideoRecording() async {
    if (!controller.value.isInitialized) {
      //showInSnackBar('Error: select a camera first.');
      return null;
    }

    print("Started camera");

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Records';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    if (controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      print("Already recording");
      return null;
    }

    try {
      videoPath = filePath;
      await controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }

    await _startVideoPlayer();
  }

  Future<void> _startVideoPlayer() async {
    final VideoPlayerController vcontroller =
        VideoPlayerController.file(File(videoPath));

    videoPlayerListener = () {
      if (videoController != null && videoController.value.size != null) {
        // Refreshing the state to update video player with the correct ratio.
        final int duration = videoController.value.duration.inMilliseconds;
        final int position = videoController.value.position.inMilliseconds;

        setState(() {
          stoppedPlaying = false;
        });

        if (position == duration) {
          setState(() {
            stoppedPlaying = true;
          });
        }

        if (mounted) setState(() {});
        //videoController.removeListener(videoPlayerListener);
      }
    };
    vcontroller.addListener(videoPlayerListener);
    await vcontroller.setLooping(false);
    await vcontroller.initialize();
    await vcontroller.setVolume(0.0);
    await videoController?.dispose();
    if (mounted) {
      setState(() {
        imagePath = null;
        videoController = vcontroller;
      });
    }
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      //showInSnackBar('Error: select a camera first.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    //showInSnackBar('Error: ${e.code}\n${e.description}');
  }
