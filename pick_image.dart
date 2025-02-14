import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hl_image_picker/hl_image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class PickImage extends StatefulWidget {
  final Icon icon;
  final void Function(Image image) getImage;
  final bool isActivated;
  const PickImage({
    super.key,
    required this.icon,
    required this.getImage,
    this.isActivated=true
  });

  @override
  State<PickImage> createState() => _PickImageState();
}

class _PickImageState extends State<PickImage> {
  Future<bool> requestPermissions() async {
    // 请求存储和相机权限
    var status = await Permission.camera.request();

    if (status.isGranted && await Permission.storage.request().isGranted) {
      // 权限被授予，可以选择图片
      return true;
    } else {
      // 权限未被授予
      return false;
    }
  }
  Future<void> _pickImage() async {
    bool requestResult=await requestPermissions();
    if(requestResult==false){
      Fluttertoast.showToast(msg: '您必须授予存储和相机权限，否则无法选择图片');
      return;
    }
    List<HLPickerItem> imageData=await HLImagePicker().openPicker(
        pickerOptions: HLPickerOptions(maxSelectedAssets: 1),
      localized: LocalizedImagePicker(
        doneText: '好',
        cancelText: '取消',

      )
    );
    if(imageData.isEmpty) return;
    Image image=Image.file(File(imageData[0].path));
    widget.getImage(image);
    return;
  }
  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: (){
          if(widget.isActivated==false){
            return;
          }
          _pickImage();
        },
        icon: widget.icon,
    );
  }
}
