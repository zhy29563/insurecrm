import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  int _step = 1; // 1: input username, 2: answer security question, 3: success
  String? _securityQuestion;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    if (_usernameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final question = await appState.getSecurityQuestion(_usernameController.text.trim());
    
    if (mounted) setState(() => _isLoading = false);

    if (question != null && mounted) {
      setState(() {
        _securityQuestion = question;
        _step = 2;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未找到该用户或该用户未设置安全问题'), backgroundColor: Color(0xFFE53935)),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final appState = Provider.of<AppState>(context, listen: false);
      final (success, message) = await appState.resetPassword(
        username: _usernameController.text.trim(),
        securityAnswer: _answerController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (mounted) setState(() => _isLoading = false);

      if (success && mounted) {
        setState(() => _step = 3);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('\u5fd8\u8bb0\u5bc6\u7801'), elevation: 0),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF0F4FF), Color(0xFFFFFFFF)])),
        child: SingleChildScrollView(padding: EdgeInsets.all(24),child: Column(children: [
          SizedBox(height: 20),

          // Progress indicator
          Container(width: double.infinity,padding:EdgeInsets.symmetric(vertical:16),child:Row(mainAxisAlignment: MainAxisAlignment.center,children:[
            _stepIndicator(1, '\u786e\u8ba4\u7528\u6237'),
            _stepLine(),
            _stepIndicator(2, '\u9a8c\u8bc1\u8eab\u4efd'),
            _stepLine(),
            _stepIndicator(3, '\u91cd\u7f6e\u6210\u529f'),
          ],)),

          SizedBox(height: 24),

          // Step content
          AnimatedSwitcher(duration: Duration(milliseconds: 300),transitionBuilder:(c,anim)=>SlideTransition(position: Tween<Offset>(begin: Offset(0.1,0),end: Offset.zero).animate(anim),child:c),child:_stepContent(),),

          if (_step < 3)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: _isLoading ? Center(child: CircularProgressIndicator()) :
              SizedBox(width:double.infinity,height:50,child:ElevatedButton(
                onPressed: _step == 1 ? _checkUsername : _resetPassword,
                style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF1565C0),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
                child:Text(_step == 1 ? '\u4e0b\u4e00\u6b65' : '\u91cd\u7f6e\u5bc6\u7801',style:TextStyle(fontSize:16,fontWeight:FontWeight.w600,color:Colors.white)),
              )),
            ),

          if (_step == 3)
            Padding(
              padding: EdgeInsets.only(top:24),
              child:SizedBox(width:double.infinity,height:50,child:OutlinedButton(onPressed:()=>Navigator.pop(context),style:OutlinedButton.styleFrom(side:BorderSide(color:Color(0xFF1565C0)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),child:Text('\u8fd4\u56de\u767b\u5f55',style:TextStyle(fontSize:16,color:Color(0xFF1565C0))))),
            ),
          
          SizedBox(height:20),
        ])),
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 1:
        return Form(key: _formKey,child:Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
          Center(child:Column(children:[Icon(Icons.person_search_rounded,size:56,color:Color(0xFF1565C0)),SizedBox(height:12),Text('\u8bf7\u8f93\u5169\u60a8\u7684\u7528\u6237\u540d',style:TextStyle(fontSize:18,fontWeight:FontWeight.w600,color:Color(0xFF333333))),SizedBox(height:6),Text('\u6211\u4eec\u5c06\u67e5\u627e\u60a8\u7684\u8d26\u53f7\u5e76\u8fdb\u884c\u8eab\u4efd\u9a8c\u8bc1',style:TextStyle(fontSize:13,color:Colors.grey.shade600)),]),),
          SizedBox(height:28),
          TextFormField(controller:_usernameController,decoration:InputDecoration(prefixIcon:Icon(Icons.person_outline),labelText:'\u7528\u6237\u540d',hintText:'\u8bf7\u8f93\u5165\u60a8\u7684\u7528\u6237\u540d'),validator:(v){if(v==null||v.trim().isEmpty)return'\u8bf7\u8f93\u5165\u7528\u6237\u540d';return null;},onFieldSubmitted:(_)=>_checkUsername(),),
        ]));

      case 2:
        return Form(key: GlobalKey<FormState>(),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children: [
          Center(child:Column(children:[Icon(Icons.security_rounded,size:56,color:Color(0xFFFF8F00)),SizedBox(height:12),Text('\u8eab\u4efd\u9a8c\u8bc1',style:TextStyle(fontSize:18,fontWeight:FontWeight.w600,color:Color(0xFF333333))),SizedBox(height:6),Text('\u56de\u7b54\u5b89\u5168\u95ee\u9898\u4ee5\u91cd\u7f6e\u5bc6\u7801',style:TextStyle(fontSize:13,color:Colors.grey.shade600)),]),),
          SizedBox(height:20),
          Card(elevation:0,color:Color(0xFFFFF8E1),margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:BorderSide(color:Color(0xFFFFC107).withOpacity(0.5))),child:Padding(padding:EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('\u5b89\u5168\u95ee\u9898',style:TextStyle(fontWeight:FontWeight.w600,fontSize:13,color:Color(0xFFE65100))),SizedBox(height:8),Container(padding:EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8)),width:double.infinity,child:Text(_securityQuestion??'',style:TextStyle(fontSize:15,fontWeight:FontWeight.w500))),SizedBox(height:12),TextField(controller:_answerController,decoration:InputDecoration(labelText:'\u60a8\u7684\u7b54\u6848',prefixIcon:Icon(Icons.question_answer_outlined)))]))),
          SizedBox(height:16),
          TextFormField(controller:_newPasswordController,decoration:InputDecoration(prefixIcon:Icon(Icons.lock_outline),labelText:'\u65b0\u5bc6\u7801',suffixIcon:IconButton(icon:Icon(_obscureNew?Icons.visibility_off:Icons.visibility,color:Colors.grey.shade400),onPressed:()=>setState(()=>_obscureNew=!_obscureNew)),),obscureText:_obscureNew,textInputAction:TextInputAction.next,validator:(v){if(v==null||v.length<6)return'\u81f3\u5c111\u4f4d';return null;},),
          SizedBox(height:12),
          TextFormField(controller:_confirmPasswordController,decoration:InputDecoration(prefixIcon:Icon(Icons.lock_outline),labelText:'\u786e\u8ba4\u65b0\u5bc6\u7801',suffixIcon:IconButton(icon:Icon(_obscureConfirm?Icons.visibility_off:Icons.visibility,color:Colors.grey.shade400),onPressed:()=>setState(()=>_obscureConfirm=!_obscureConfirm)),),obscureText:_obscureConfirm,onFieldSubmitted:(_)=>_resetPassword(),validator:(v){if(v!=_newPasswordController.text)return'\u4e24\u6b21\u5bc6\u7801\u4e0d\u4e00\u81f4';return null;},),
        ]));

      case 3:
        return Center(child:Padding(padding:EdgeInsets.symmetric(vertical:32),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:80,height:80,decoration:BoxDecoration(color:Color(0xFFE8F5E9),shape:BoxShape.circle),child:Icon(Icons.check_circle_rounded,size:48,color:Color(0xFF43A047))),
          SizedBox(height:20),
          Text('\u5bc6\u7801\u91cd\u7f6e\u6210\u529f\uff01',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:Color(0xFF43A047))),
          SizedBox(height:10),
          Text('\u60a8\u73b0\u5728\u53ef\u4ee5\u4f7f\u7528\u65b0\u5bc6\u7801\u767b\u5f55\u4e86',style:TextStyle(fontSize:14,color:Colors.grey.shade600)),
        ])));

      default:
        return SizedBox.shrink();
    }
  }

  Widget _stepIndicator(int step, String label) {
    final isActive = step <= _step;
    final isDone = step < _step;
    return Column(children:[
      Container(width:36,height:36,decoration:BoxDecoration(color:isDone?Color(0xFF43A047):isActive?Color(0xFF1565C0):Colors.grey.shade300,shape:BoxShape.circle),child:isDone?Icon(Icons.check,size:18,color:Colors.white):Center(child:Text('$step',style:TextStyle(color:isActive?Colors.white:Colors.grey.shade500,fontWeight:FontWeight.w600))),),
      SizedBox(height:6),Text(label,style:TextStyle(fontSize:11,color:isActive?Color(0xFF1565C0):Colors.grey.shade500)),
    ]);
  }

  Widget _stepLine() => Container(width:40,height:2,color:_step>1?Color(0xFF43A047):Colors.grey.shade300);
}
