import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nickCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String _gender = 'other';
  bool _saving = false;

  @override
  void dispose() {
    _nickCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AuthProvider>().updateProfile({
      'nickname': _nickCtrl.text.trim(),
      'gender': _gender,
      'bio': _bioCtrl.text.trim(),
    });
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('资料已更新'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('退出登录'), content: const Text('确定要退出吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
      ],
    ));
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  Future<void> _saveLlmConfig() async {
    final api = ApiService();
    final baseUrlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController();

    // Load current
    try {
      final cfg = await api.getLlmConfig();
      baseUrlCtrl.text = cfg['baseUrl'] as String? ?? '';
      modelCtrl.text = cfg['model'] as String? ?? '';
    } catch (_) {}

    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('LLM API 配置'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: baseUrlCtrl, decoration: const InputDecoration(labelText: 'API 地址', hintText: 'https://api.openai.com/v1', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'API Key', hintText: 'sk-...', border: OutlineInputBorder()), obscureText: true),
          const SizedBox(height: 12),
          TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: '模型', hintText: 'gpt-3.5-turbo', border: OutlineInputBorder())),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
      ],
    ));

    if (ok == true) {
      try {
        await api.updateLlmConfig({'apiBaseUrl': baseUrlCtrl.text, 'apiKey': keyCtrl.text, 'model': modelCtrl.text});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LLM 配置已保存'), behavior: SnackBarBehavior.floating));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final cs = Theme.of(context).colorScheme;
    if (user == null) return const Center(child: CircularProgressIndicator());

    if (_nickCtrl.text.isEmpty) {
      _nickCtrl.text = user.nickname ?? '';
      _bioCtrl.text = user.bio ?? '';
      _gender = user.gender ?? 'other';
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      // Avatar
      Center(
        child: Column(children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, cs.primaryContainer]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppTheme.shadowMd(cs),
            ),
            child: Center(child: Text((user.nickname ?? user.username)[0].toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          const SizedBox(height: 14),
          Text(user.nickname ?? user.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text('@${user.username}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
      ),
      const SizedBox(height: 28),

      // Edit profile
      _SectionTitle('编辑资料'),
      const SizedBox(height: 10),
      TextField(controller: _nickCtrl, decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'male', label: Text('♂'), icon: Icon(Icons.male)),
          ButtonSegment(value: 'female', label: Text('♀'), icon: Icon(Icons.female)),
          ButtonSegment(value: 'other', label: Text('其他'), icon: Icon(Icons.transgender)),
        ],
        selected: {_gender},
        onSelectionChanged: (s) => setState(() => _gender = s.first),
      ),
      const SizedBox(height: 12),
      TextField(controller: _bioCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '个人简介', hintText: '介绍一下自己...', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存资料')),

      const SizedBox(height: 24),
      _SectionTitle('设置'),
      const SizedBox(height: 10),

      _SettingTile(icon: Icons.api, title: 'LLM API 配置', subtitle: '自定义你的AI接口', onTap: _saveLlmConfig),
      _SettingTile(icon: Icons.security, title: '账号安全', subtitle: '修改密码', onTap: () {}),
      _SettingTile(icon: Icons.info_outline, title: '关于 myfrends', subtitle: 'v0.2.0', onTap: () {}),

      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: Icon(Icons.logout, color: cs.error),
          label: Text('退出登录', style: TextStyle(color: cs.error)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ),
      const SizedBox(height: 40),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.chevron_right, size: 20), onTap: onTap),
    );
  }
}
