import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _selectedQuestion;
  final List<String> _securityQuestions = [
    '您从事的行业是什么？',
    '您的小学学校名称？',
    '您最喜爱的电影？',
    '您宠物的名字？',
    '您出生的城市？',
    '您母亲的姓氏？',
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedQuestion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请选择一个安全问题'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_securityAnswerController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请输入安全问题的答案'), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() => _isLoading = true);

      final appState = Provider.of<AppState>(context, listen: false);
      final (success, message) = await appState.register(
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        password: _passwordController.text,
        securityQuestion: _selectedQuestion!,
        securityAnswer: _securityAnswerController.text.trim(),
      );

      if (mounted) setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('注册成功！请登录')]), backgroundColor: Color(0xFF43A047)),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 8), Text(message)]), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('注册账号'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F4FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: Color(0xFF1565C0).withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.person_add_rounded, size: 32, color: Color(0xFF1565C0)),
                    ),
                    SizedBox(height: 12),
                    Text('创建新账号', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                    SizedBox(height: 6),
                    Text('填写以下信息完成注册', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ]),
                ),
                SizedBox(height: 28),

                // Username
                Text('用户名 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333))),
                SizedBox(height: 6),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: '用于登录的用户名'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '请输入用户名';
                    if (value.trim().length < 3) return '用户名至少3个字符';
                    if (!RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$').hasMatch(value)) return '仅支持字母、数字、下划线和中文';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16),

                // Display Name
                Text('显示名称 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333))),
                SizedBox(height: 6),
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(prefixIcon: Icon(Icons.badge_outlined), hintText: '您的昵称或真实姓名'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '请输入显示名称';
                    if (value.trim().length > 20) return '名称不超过20个字符';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16),

                // Password
                Text('密码 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333))),
                SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    hintText: '至少6位密码',
                  ),
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                ),
                // Password strength indicator
                if (_passwordController.text.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Row(children: [
                      ...List.generate(3, (i) {
                        int len = _passwordController.text.length;
                        bool hasLetter = RegExp(r'[a-zA-Z]').hasMatch(_passwordController.text);
                        bool hasDigit = RegExp(r'[0-9]').hasMatch(_passwordController.text);
                        int strength = 0;
                        if (len >= 6) strength++;
                        if (hasLetter) strength++;
                        if (hasDigit) strength++;

                        bool active = i < strength;
                        return Container(
                          margin: EdgeInsets.only(right: 4),
                          width: (MediaQuery.of(context).size.width - 96) / 3 - 5,
                          height: 4,
                          decoration: BoxDecoration(color: active ? (strength <= 1 ? Colors.red : strength == 2 ? Colors.orange : Colors.green) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                        );
                      }),
                      Spacer(),
                      Text(_passwordStrengthLabel(), style: TextStyle(fontSize: 11, color: _passwordStrengthColor())),
                    ]),
                  ),

                SizedBox(height: 16),

                // Confirm Password
                Text('确认密码 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333))),
                SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                    hintText: '再次输入密码',
                  ),
                  obscureText: _obscureConfirm,
                  validator: (value) {
                    if (value != _passwordController.text) return '两次密码不一致';
                    return null;
                  },
                  onFieldSubmitted: (_) => _register(),
                ),
                SizedBox(height: 20),

                // Security Question
                Card(elevation: 0,color: Color(0xFFFFF8E1),margin: EdgeInsets.zero,shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),side: BorderSide(color: Color(0xFFFFC107).withOpacity(0.5))),child: Padding(padding: EdgeInsets.all(14),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [Row(children: [Icon(Icons.security_rounded, size: 18, color: Color(0xFFFF8F00)),SizedBox(width: 8),Text('安全设置（忘记密码时使用）',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 14,color: Color(0xFFE65100))),]),SizedBox(height: 10),DropdownButtonFormField<String>(decoration: InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12,vertical: 8)),hint: Text('选择安全问题'),value: _selectedQuestion,isExpanded:true,items:_securityQuestions.map((q)=>DropdownMenuItem(value:q,child:Text(q,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){setState(()=>_selectedQuestion=v);}),SizedBox(height:10),TextField(controller:_securityAnswerController,obscureText:false,decoration:InputDecoration(contentPadding:EdgeInsets.symmetric(horizontal:12,vertical:8),hintText:'安全问题的答案')),]))),

                SizedBox(height: 24),

                _isLoading ? Center(child: Padding(padding: EdgeInsets.all(20),child: CircularProgressIndicator())) :
                SizedBox(width: double.infinity,height: 50,child:ElevatedButton(onPressed:_register,style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF1565C0),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),),child:Text('\u6ce8\u518c',style:TextStyle(fontSize:16,fontWeight:FontWeight.w600,color:Colors.white)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _passwordStrengthLabel() {
    String p = _passwordController.text;
    if (p.length >= 6 && RegExp(r'[a-zA-Z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p)) return '\u5f3a';
    if (p.length >= 4) return '\u4e2d';
    return '\u5f31';
  }

  Color _passwordStrengthColor() {
    String p = _passwordController.text;
    if (p.length >= 6 && RegExp(r'[a-zA-Z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p)) return Colors.green;
    if (p.length >= 4) return Colors.orange;
    return Colors.red;
  }
}
