import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vibration/vibration.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:single_sentence/api_value.dart';
import 'package:single_sentence/cert.dart';
import 'package:http/http.dart' as http;
import 'package:single_sentence/pick_image.dart';
class RootPage extends StatefulWidget {
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver, TickerProviderStateMixin{
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _colorController;
  late Animation<Color?> _colorChange;
  ValueNotifier<Color> pickerColor = ValueNotifier<Color>(Color.fromARGB(255, 73, 148, 196));
  String message='';
  ///0-连接中 1-服务断连 2-对方未读 3-对方已读
  int isReadStatus=0;
  List<String> readStatusList=[
    '连接中','服务断连','对方未读','对方已读'
  ];
  Box profile=Hive.box('profile');
  String writeText='';
  bool isSending=false;//开始发送
  bool isChecking=false;//是否循环检查消息更新
  String sentTime='';
  bool isNavigatingToCert=false;
  bool isAppInForeground=true;
  DateTime receiveTime=DateTime.now();
  String receiveTimeStr='';
  int alpha=255;
  int red=73;
  int green=148;
  int blue=196;
  DateTime otherTime=DateTime(1970);
  String? selectImage;
  Widget? recvImage;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      setState(() {
        isAppInForeground = true;
      });
    } else if (state == AppLifecycleState.paused) {
      setState(() {
        isAppInForeground = false;
      });
    }
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void initState() {
    // TODO: implement initState
    _animationController=AnimationController(vsync: this, duration: Duration(seconds: 6));
    _animation=Tween<double>(begin: 0.6,end: 1.5).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _colorController=AnimationController(vsync: this,duration: Duration(seconds: 1));
    _colorChange=ColorTween(begin: Color.fromARGB(alpha, red, green, blue)).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeIn));
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if(isChecking==false){
      checkMessage();
    }
    _animationController.repeat(reverse: true);
  }
  Future<void> checkMessage() async {
    // 每五百毫秒检查一次消息，循环检查
    isChecking = true;
    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (isAppInForeground == false || isNavigatingToCert == true) {
        return;
      }
      if (profile.get('passwd') == null && isNavigatingToCert == false) {
        // 需要重新设置
        isNavigatingToCert = true;
        await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => Cert()));
        isNavigatingToCert = false;
      }
      // 进行平时消息检查
      final Map<String, String> certForm = {
        'token': profile.get('passwd'),
      };

      // 设定超时功能
      final timeout = Duration(seconds: 3);
      late Timer timeoutTimer;

      // 创建一个超时计时器
      timeoutTimer = Timer(timeout, () {
        isReadStatus = 1;  // 设置超时后的状态
        setState(() {});
      });

      try {
        final response = await http.post(
          Uri.parse(urlToCheck),
          body: certForm,
        ).timeout(timeout, onTimeout: () {
          // 如果超时，手动触发超时逻辑
          timeoutTimer.cancel();
          isReadStatus = 1;
          setState(() {});
          return http.Response('Local failed.',404);
        });

        timeoutTimer.cancel();  // 如果响应成功，取消超时计时器

        if (response.statusCode == 200) {
          Map answerForm = jsonDecode(response.body);
          String? alpha = answerForm['colorAlpha'];
          String? red = answerForm['colorRed'];
          String? green = answerForm['colorGreen'];
          String? blue = answerForm['colorBlue'];
          String? boolean = answerForm['isRead'];
          String? time = answerForm['sendTime'];
          String? msg = answerForm['message'];
          String ?recOtherTime = answerForm['otherVisitTime'];
          String? recImage=answerForm['imageUrl'];

          otherTime=DateTime.tryParse(recOtherTime??'')??DateTime(1970);

          if (alpha == null || red == null || green == null || blue == null || boolean == null || time == null || msg == null) {
            if (boolean != null) {
              isReadStatus = bool.parse(boolean) == true ? 3 : 2;
            }
            setState(() {});
          } else { // 有新的消息了
            if(recImage!=null&&recImage!=''){
              recvImage=CachedNetworkImage(
                  placeholder: (context, url) => SizedBox(
                    height: 50, // 高度
                    width: 50,  // 宽度
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _colorChange.value == null
                            ? pickerColor.value
                            : _colorChange.value!,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(Icons.error), // 加载失败时的替代视图
                  imageUrl: recImage
              );
            } else{
              recvImage=null;
            }
            isReadStatus = bool.parse(boolean) == true ? 3 : 2;
            sentTime = time;
            receiveTime = DateTime.parse(sentTime);
            String year = '${receiveTime.year}';
            String month = '${receiveTime.month}'.padLeft(2, '0');
            String day = '${receiveTime.day}'.padLeft(2, '0');
            String hour = '${receiveTime.hour}'.padLeft(2, '0');
            String min = '${receiveTime.minute}'.padLeft(2, '0');
            String sec = '${receiveTime.second}'.padLeft(2, '0');
            receiveTimeStr = '$year-$month-$day $hour:$min:$sec';
            message = msg;
            pickerColor.value = Color.fromARGB(int.parse(alpha), int.parse(red), int.parse(green), int.parse(blue));
            setState(() {});

            if (isAppInForeground == true) {
              Future.delayed(Duration(milliseconds: 500), () async {
                final Map<String, String> readForm = {
                  'token': profile.get('passwd'),
                  'message': message
                };
                final response = await http.post(
                  Uri.parse(urlToRead),
                  body: readForm,
                );
                if (response.statusCode != 200) {
                  Fluttertoast.showToast(msg: 'not succeed');
                }
              });
            }
          }
        } else { // 请求失败
          if(response.statusCode==404&&response.body=='Local failed.'){
            return;
          }
          profile.clear();
          await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => Cert()));
        }
      } catch (e) {
        // 如果发生异常，清理状态并处理异常
        timeoutTimer.cancel();
        isReadStatus = 1;
        setState(() {});
      }
    });
  }
  void onColorChanged(Color value){
    //_colorController=AnimationController(vsync: this,duration: Duration(seconds: 2));
    //_colorChange=ColorTween<Color>(begin: Color.fromARGB(alpha, red, green, blue),end: value).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeIn));
    if(value.alpha!=alpha||value.red!=red||value.green!=green||value.blue!=blue){
      _colorController.reset();
      _colorChange=ColorTween(begin: Color.fromARGB(alpha, red, green, blue),end: value ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeIn));
      alpha=value.alpha;
      red=value.red;
      green=value.green;
      blue=value.blue;
      _colorController.forward();
      print('on Color Changed');
    }
  }
  Future<String?> uploadImage(String imagePath) async {
    String preSignedUrl='';
    String objName=randomString(16)+imagePath.substring(imagePath.lastIndexOf('.'));
    try{
      final response = await http.post(
        Uri.parse(urlToRequestUpload),
        body: {
          'passwd':profile.get('passwd'),
          'object':objName,
        },
      );
      if(response.statusCode==200){
        preSignedUrl=response.body;
      }else{
        Fluttertoast.showToast(msg: '暂时无法发送图片');
        return null;
      }
    }catch(e){
      return null;
    }
    try {
      final response = await http.put(
        Uri.parse(preSignedUrl),
        body: File(imagePath).readAsBytesSync(),
        headers: {'Content-Type': 'image/jpeg'}, // 根据图片格式调整
      );
      if (response.statusCode == 200) {
        return objName;
      } else {
        print('==================\n${response.body}\n=================');
        return null;
      }
    } catch (e) {
      print('==================\n$e\n=================');
      return null;
    }
  }
  String randomString(int length) {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
        Iterable.generate(
          length,
              (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ));
  }
  Future<void> sendMessage() async{
    if((writeText!=''||selectImage!=null)&&isReadStatus==3&&isSending==false){
      isSending=true;
      setState(() {

      });
      String? imageUrl;
      //uploadImageFirst
      if(selectImage!=null){
        imageUrl=await uploadImage(selectImage!);
        if(imageUrl==null){
          Fluttertoast.showToast(msg: '发送图片时出现异常，请重试.');
          isSending=false;
          setState(() {

          });
          return;
        }
      }
      String alpha=pickerColor.value.alpha.toString();
      String red=pickerColor.value.red.toString();
      String green=pickerColor.value.green.toString();
      String blue=pickerColor.value.blue.toString();
      String msg=writeText;
      final Map<String, String> certForm = {
        'token': profile.get('passwd'),
        'colorAlpha':alpha,
        'colorRed':red,
        'colorGreen':green,
        'colorBlue':blue,
        'message':msg,
        'imageUrl':imageUrl??'',
      };
      final response = await http.post(
        Uri.parse(urlToSend),
        body: certForm,
      );
      if(response.statusCode==200){//成功发送
        profile=Hive.box('profile');
        profile.put('lastMessage', '$msg\n${DateTime.now().year.toString()}-'
            '${DateTime.now().month.toString().padLeft(2,'0')}-'
            '${DateTime.now().day.toString().padLeft(2,'0')} '
            '${DateTime.now().hour.toString().padLeft(2,'0')}:'
            '${DateTime.now().minute.toString().padLeft(2,'0')}:'
            '${DateTime.now().second.toString().padLeft(2,'0')}');
        Fluttertoast.showToast(msg: '发送成功！');
        isReadStatus=2;
        writeText='';
        setState(() {

        });
      }else{
        Fluttertoast.showToast(msg: '非常抱歉，发送失败：${response.body.toString()}');
      }
      isSending=false;
      selectImage=null;
      setState(() {

      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
          animation:_animationController,
          builder: (context,child){
            return ValueListenableBuilder<Color>(
                valueListenable: pickerColor,
                builder: (context,color,child){
                  onColorChanged(color);
                  return Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                        gradient: RadialGradient(
                            colors: [
                              _colorChange.value??Color.fromARGB(alpha, red, green, blue),
                              Colors.black
                            ],
                            center: Alignment.topLeft,
                            radius: 2.5*_animation.value
                        )
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 40,
                          right: MediaQuery.of(context).size.width*0.15/2,
                          child: Container(
                            padding: EdgeInsets.only(left: 10,right: 10,bottom: 5,top: 5),
                            decoration: BoxDecoration(
                              color: _colorChange.value==null?pickerColor.value.withAlpha(50):_colorChange.value!.withAlpha(50),
                              borderRadius: BorderRadius.circular(45),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(readStatusList[isReadStatus],style:TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold
                                ) ,),
                                SizedBox(width: 5,),
                                Container(
                                  width: 15,
                                  height:15,
                                  decoration: BoxDecoration(
                                    color: isReadStatus<=1?Colors.grey:isReadStatus==2?Colors.red:Colors.green,
                                    shape: BoxShape.circle,
                                  ),)
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: (){
                            if(profile.get('lastMessage')==null){
                              Fluttertoast.showToast(msg: '您还没有发送消息呢…');
                              return;
                            }
                            showDialog(context: context, builder: (BuildContext context){
                              return AlertDialog(
                                title: Text('您发送的消息'),
                                content: Text(profile.get('lastMessage')),
                                actions: [
                                  ElevatedButton(onPressed: (){Navigator.pop(context);}, child: Text('好'))
                                ],
                              );
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.only(
                              left: MediaQuery.of(context).size.width * 0.15 / 2,
                              right: MediaQuery.of(context).size.width * 0.15 / 2,
                            ),
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, // 纵向居中
                              children: [
                                Expanded( // 使 ListView 占满可用空间
                                  child: ListView(
                                    physics: BouncingScrollPhysics(), // 保持滚动效果
                                    children: [
                                      Center( // 使用 Center 来横向居中文本
                                        child: Text(
                                          //textAlign: TextAlign.center,
                                          message==''&&recvImage==null?'(等ta结束忙碌，一定会回复你～)':message,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 35,
                                            color: _colorChange.value??Color.fromARGB(alpha, red, green, blue),
                                          ),
                                        ),
                                      ),
                                      if(recvImage!=null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: recvImage,
                                        ),
                                      Text(
                                        textAlign: TextAlign.center,
                                        message==''?'':receiveTimeStr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _colorChange.value??Color.fromARGB(alpha, red, green, blue),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 100,
                          child: Container(
                            margin: EdgeInsets.only(left: MediaQuery.of(context).size.width*0.15/2,right: MediaQuery.of(context).size.width*0.15/2),
                            width: MediaQuery.of(context).size.width*0.85,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(65),
                              color: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children:[
                                DateTime.now().difference(otherTime).inSeconds>1?Text('对方上次造访: ${otherTime.toString().substring(0,19)}',style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold
                                ),):Text('对方在线',style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold
                                ),)
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              //SizedBox(width: 20,),
                              Container(
                                width: 60,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  color: _colorChange.value==null?Color.fromARGB(50, red, green, blue):_colorChange.value!.withAlpha(50),
                                ),
                                child: selectImage==null?PickImage(
                                  icon: Icon(Icons.add,color: isReadStatus==3?Colors.white60:Colors.white10,),
                                  getImage: (String imagePath){
                                    selectImage=imagePath;
                                    setState(() {

                                    });
                                  },
                                  isActivated: isReadStatus==3?true:false,
                                ):GestureDetector(
                                  child: Container(
                                  height: 50,
                                  width: 50,
                                  child: ClipRRect(
                                    child: Image(image: Image.file(File(selectImage!)).image,fit: BoxFit.cover,),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                ),
                                  onTap: (){
                                    Fluttertoast.showToast(msg: '已经选择照片啦～请双击以取消选择');
                                  },
                                  onDoubleTap: ()async{
                                    selectImage=null;
                                    if(await Vibration.hasVibrator()==true){
                                      Vibration.vibrate(duration: 50); // 持续时间 100ms
                                    }
                                    setState(() {

                                    });
                                    return;
                                  },
                                ),
                              ),
                              SizedBox(width: 10,),
                              Container(
                                //margin: EdgeInsets.only(left: MediaQuery.of(context).size.width*0.15/2,right: MediaQuery.of(context).size.width*0.15/2),
                                width: MediaQuery.of(context).size.width*0.85-30,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(45),
                                  color: _colorChange.value==null?Color.fromARGB(50, red, green, blue):_colorChange.value!.withAlpha(50),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 20,),
                                    Expanded(
                                      child: isReadStatus<=2?Text('请等待对方的回音～',style: TextStyle(
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold
                                      ),):TextField(
                                        style: TextStyle(color: Colors.white),
                                        cursorColor: Colors.white54,
                                        decoration: InputDecoration(
                                          hintStyle: TextStyle(
                                              color: Colors.white54,
                                              fontWeight: FontWeight.bold
                                          ),
                                          hintText: '写下你想说的话...',
                                          contentPadding: EdgeInsets.only(top: 18),
                                          border: InputBorder.none,
                                        ),
                                        maxLines: 10,
                                        onChanged: (txt){
                                          writeText=txt;
                                          setState(() {

                                          });
                                        },

                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: (){
                                        showColorPicker();
                                      },
                                      child: Container(
                                        width: 25,
                                        decoration: BoxDecoration(
                                          color: _colorChange.value??Color.fromARGB(alpha, red, green, blue),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        sendMessage();
                                      },
                                      child: isSending==true?CircularProgressIndicator():Icon(Icons.chevron_right_rounded,color: writeText==''&&selectImage==null?Colors.white10:Colors.white60,size: 30,),
                                    ),
                                    SizedBox(width: 10,),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }
            );
          }
      )
    );
  }
  void showColorPicker(){
    showDialog(context: context, builder: (BuildContext context){
      return ValueListenableBuilder(
          valueListenable: pickerColor,
          builder: (context,value,child){
            return AlertDialog(
              title: Text('选个颜色来代表你的心情吧！',style: TextStyle(fontSize: 18,color: Colors.white),),
              backgroundColor: Colors.black,
              content: MaterialPicker(
                pickerColor: _colorChange.value==null?_colorChange.value!:Color.fromARGB(alpha, red, green, blue),
                onColorChanged: (Color currentColor){
                  pickerColor.value=currentColor;
                  setState(() {

                  });
                },
              ),
              actions: <Widget>[
                GestureDetector(
                  child: const Text('好',style: TextStyle(fontSize: 18,color: Colors.white),),
                  onTap: () {

                    setState((){});
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
      );
    });
  }
}
