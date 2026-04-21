import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/colleague.dart';

class ColleagueManagementPage extends StatefulWidget {
  @override
  _ColleagueManagementPageState createState() =>
      _ColleagueManagementPageState();
}

class _ColleagueManagementPageState extends State<ColleagueManagementPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specialtyController = TextEditingController();
  Colleague? _editingColleague;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _specialtyController.clear();
    _editingColleague = null;
  }

  void _addOrUpdateColleague() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请输入同事姓名')));
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);

    if (_editingColleague != null) {
      // 更新同事信息
      final updatedColleague = Colleague(
        id: _editingColleague!.id,
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        specialty: _specialtyController.text,
      );
      appState.updateColleague(updatedColleague);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('同事信息已更新')));
    } else {
      // 添加新同事
      final newColleague = Colleague(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        specialty: _specialtyController.text,
      );
      appState.addColleague(newColleague);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('同事信息已添加')));
    }

    _clearForm();
  }

  void _editColleague(Colleague colleague) {
    setState(() {
      _editingColleague = colleague;
      _nameController.text = colleague.name;
      _phoneController.text = colleague.phone ?? '';
      _emailController.text = colleague.email ?? '';
      _specialtyController.text = colleague.specialty ?? '';
    });
  }

  void _deleteColleague(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除这个同事吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.deleteColleague(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('同事信息已删除')));
            },
            child: Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('同事管理'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // 表单部分
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingColleague != null ? '编辑同事' : '添加同事',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '姓名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: '电话',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _specialtyController,
                      decoration: InputDecoration(
                        labelText: '专长',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _addOrUpdateColleague,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                          ),
                          child: Text(_editingColleague != null ? '更新' : '添加'),
                        ),
                        SizedBox(width: 10),
                        if (_editingColleague != null)
                          ElevatedButton(
                            onPressed: _clearForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            child: Text('取消'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            // 同事列表部分
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '同事列表',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 15),
                      appState.colleagues.isEmpty
                          ? Center(
                              child: Text(
                                '暂无同事信息',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : Expanded(
                              child: ListView.builder(
                                itemCount: appState.colleagues.length,
                                itemBuilder: (context, index) {
                                  final colleague = appState.colleagues[index];
                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: 5),
                                    child: ListTile(
                                      title: Text(colleague.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (colleague.phone != null)
                                            Text('电话: ${colleague.phone}'),
                                          if (colleague.email != null)
                                            Text('邮箱: ${colleague.email}'),
                                          if (colleague.specialty != null)
                                            Text('专长: ${colleague.specialty}'),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () =>
                                                _editColleague(colleague),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _deleteColleague(colleague.id!),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
