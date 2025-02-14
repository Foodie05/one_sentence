import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
class Cert extends StatefulWidget {
  const Cert({super.key});

  @override
  State<Cert> createState() => _CertState();
}

class _CertState extends State<Cert> {
  String passwd='';
  String newPasswd='';
  bool isCertificating=false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('请验证身份',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black,
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '请输入密码',
              ),
              onChanged: (String txt){
                passwd=txt;
                setState(() {

                });
              },
            ),
            TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '请设置新的密码',
              ),
              onChanged: (String txt){
                newPasswd=txt;
                setState(() {

                });
              },
            ),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor:WidgetStateProperty.all(Colors.purple),
              ),
                onPressed: () async {
                  if(isCertificating==true){
                    return;
                  }
                  isCertificating=true;
                  setState(() {

                  });
                  final Map<String, String> certForm = {
                    'token': passwd,
                    'newToken': newPasswd,
                  };
                  final response = await http.post(
                    Uri.parse('https://cruty.cn:8084/check'),
                    body: certForm,
                  );
                  if (response.statusCode == 200){//成功
                    Fluttertoast.showToast(msg: '验证成功！');
                    Box profile=Hive.box('profile');
                    profile.put('passwd', newPasswd);
                    if(mounted){
                      Future.delayed(Duration(milliseconds: 500),(){
                        Navigator.pop(context);
                      });
                    }
                  }else{//失败
                    Fluttertoast.showToast(msg: '验证失败！${response.body.toString()}');
                  }
                  isCertificating=false;
                  setState(() {

                  });
                },
                child: isCertificating==false?Text('验证',style: TextStyle(color: Colors.white),):CircularProgressIndicator()
            )
          ],
        ),
      ),
    );
  }
}
