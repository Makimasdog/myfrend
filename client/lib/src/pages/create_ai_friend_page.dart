import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_friend_provider.dart';
import '../theme.dart';

class CreateAiFriendPage extends StatefulWidget {
  const CreateAiFriendPage({super.key});
  @override
  State<CreateAiFriendPage> createState() => _CreateAiFriendPageState();
}

class _GenderOption {
  final String value;
  final String label;
  final IconData icon;
  const _GenderOption(this.value, this.label, this.icon);
}

class _CreateAiFriendPageState extends State<CreateAiFriendPage> {
  final _nameCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  String _gender = 'other';
  String _ageRange = '';
  String _personality = '';
  String _hobby = '';
  String _style = '';
  String _role = '';
  int _step = 0;
  bool _creating = false;

  static const _genders = [
    _GenderOption('male', '男生', Icons.male),
    _GenderOption('female', '女生', Icons.female),
    _GenderOption('other', '其他', Icons.transgender),
  ];
  static const _ages = ['不限', '15-18', '18-22', '22-28', '28-35', '35-45', '45+'];
  static const _traits = ['阳光开朗，幽默风趣', '温柔体贴，善解人意', '成熟稳重，值得信赖', '活泼可爱，充满活力', '知性优雅，文艺清新', '酷炫帅气，自信张扬', '神秘高冷，外冷内热', '呆萌可爱，天然治愈'];
  static const _hobbies = ['游戏', '音乐', '运动', '电影', '阅读', '旅行', '美食', '摄影', '绘画', '编程', '宠物', '时尚', '动漫', '健身'];
  static const _styles = ['轻松随意，常常开玩笑', '温暖柔和，善于倾听', '沉稳理性，言简意赅', '活泼可爱，充满元气', '简洁冷淡，偶尔流露温柔', '文艺抒情，充满诗意'];
  static const _roles = ['知心朋友', '损友/互怼', '导师/前辈', '树洞/倾听者', '玩伴/搭子'];
  static const _stepLabels = ['名字', '性别', '年龄', '性格', '兴趣', '风格', '角色'];

  @override
  void dispose() { _nameCtrl.dispose(); _extraCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _creating = true);
    final p = context.read<AiFriendProvider>();
    final friend = await p.createFriend({
      'name': _nameCtrl.text.trim(), 'gender': _gender,
      'ageRange': _ageRange.isEmpty ? null : _ageRange,
      'personality': _personality.isEmpty ? null : _personality,
      'extraConfig': {
        if (_hobby.isNotEmpty) 'hobbies': _hobby,
        if (_style.isNotEmpty) 'speakingStyle': _style,
        if (_role.isNotEmpty) 'relationshipRole': _role,
        if (_extraCtrl.text.trim().isNotEmpty) 'note': _extraCtrl.text.trim(),
      },
    });
    if (mounted) {
      setState(() => _creating = false);
      if (friend != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${friend.name} 创建成功！')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('创建AI朋友')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: List.generate(_stepLabels.length, (i) => Expanded(child: Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(color: i <= _step ? cs.primary : cs.surfaceContainerHighest, shape: BoxShape.circle),
              child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i <= _step ? cs.onPrimary : cs.onSurfaceVariant)))),
            if (i < _stepLabels.length - 1) Expanded(child: Container(height: 2, color: i < _step ? cs.primary : cs.surfaceContainerHighest)),
          ])))),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_stepLabels[_step], style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.primary))),
        Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _buildStep(cs))),
        _buildButtons(),
      ]),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        if (_step > 0) ...[
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step--), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)), child: const Text('上一步'))),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _step == _stepLabels.length - 1 ? (_creating ? null : _submit) : () => setState(() => _step++),
            child: _creating ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(_step == _stepLabels.length - 1 ? '创建' : '下一步', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Widget _buildStep(ColorScheme cs) {
    switch (_step) {
      case 0:
        final tf = TextField(
          controller: _nameCtrl,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Name your friend...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
        return _centerStep(Icons.edit_note_rounded, 'Name', tf);
      case 1: return _genderStep(cs);
      case 2: final chips = _ages.map((a) => ChoiceChip(label: Text(a), selected: _ageRange == a, onSelected: (_) => setState(() => _ageRange = a), selectedColor: cs.primaryContainer, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10))).toList(); return _centerStep(Icons.calendar_today, '你希望TA的年龄在什么区间？', Wrap(spacing: 10, runSpacing: 10, children: chips));
      case 3: return _pickList(cs, '你希望TA是什么样的人？', _traits, _personality, (v) => setState(() => _personality = v));
      case 4: return _pickList(cs, 'TA有什么兴趣爱好？', _hobbies, _hobby, (v) => setState(() => _hobby = v));
      case 5: return _pickList(cs, 'TA的说话风格？', _styles, _style, (v) => setState(() => _style = v), extra: TextField(controller: _extraCtrl, maxLines: 2, decoration: InputDecoration(hintText: '补充自定义信息（可选）\n例如：喜欢猫、在学吉他...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))));
      case 6: return _pickList(cs, 'TA在你生活中的角色？', _roles, _role, (v) => setState(() => _role = v));
      default: return const SizedBox.shrink();
    }
  }

  Widget _genderStep(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('你朋友的性别是？', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          for (final g in _genders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: 220,
                child: FilledButton.tonal(
                  onPressed: () => setState(() => _gender = g.value),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gender == g.value ? cs.primaryContainer : cs.surfaceContainerHighest,
                    minimumSize: const Size(0, 56),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(g.icon, size: 22),
                    const SizedBox(width: 10),
                    Text(g.label, style: const TextStyle(fontSize: 16)),
                    const Spacer(),
                    if (_gender == g.value) Icon(Icons.check_circle, color: cs.primary, size: 22),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  static Widget _centerStep(IconData icon, String title, Widget child) {
    return Builder(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64, color: cs.primary.withAlpha(120)), const SizedBox(height: 20), Text(title, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)), const SizedBox(height: 24), child])));
    });
  }

  static Widget _pickList(ColorScheme cs, String title, List<String> items, String selected, ValueChanged<String> onPick, {Widget? extra}) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      for (final t in items)
        Card(
          color: selected == t ? cs.primaryContainer : cs.surface,
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(title: Text(t, style: TextStyle(fontWeight: selected == t ? FontWeight.w700 : FontWeight.w400)), trailing: selected == t ? Icon(Icons.check_circle, color: cs.primary) : null, onTap: () => onPick(t), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
        ),
      if (extra != null) ...[const SizedBox(height: 16), extra!],
    ]);
  }
}
