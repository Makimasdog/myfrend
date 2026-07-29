import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _obscure = true;
  bool _agreed = false;

  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请同意用户协议'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    bool ok;
    if (_isLogin) {
      ok = await auth.login(
          _usernameCtrl.text.trim(), _passwordCtrl.text.trim());
    } else {
      ok = await auth.register(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        _nicknameCtrl.text.trim().isEmpty
            ? _usernameCtrl.text.trim()
            : _nicknameCtrl.text.trim(),
      );
    }

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(auth.error ?? '操作失败'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _animCtrl.reset();
      _animCtrl.forward();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withAlpha(20),
              cs.surface,
              cs.secondary.withAlpha(15),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 80 : 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(_slideAnim),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),

                          // Logo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  AppTheme.primaryLight
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.primary.withAlpha(60),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8)),
                              ],
                            ),
                            child: const Icon(Icons.chat_bubble_rounded,
                                color: Colors.white, size: 42),
                          ),
                          const SizedBox(height: 20),

                          Text('myfrends',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin ? '欢迎回来，继续和朋友们聊天吧' : '创建账号，找到属于你的AI朋友',
                            style: TextStyle(
                                fontSize: 14, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 36),

                          // 用户名
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              hintText: '用户名',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '请输入用户名'
                                : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),

                          // 密码
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              hintText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return '请输入密码';
                              if (!_isLogin && v.length < 6) return '密码至少6位';
                              return null;
                            },
                            textInputAction: _isLogin
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onFieldSubmitted:
                                _isLogin ? (_) => _submit() : null,
                          ),

                          // 注册模式 — 昵称
                          if (!_isLogin) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nicknameCtrl,
                              decoration: const InputDecoration(
                                hintText: '昵称（可选）',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 16),

                            // 用户协议
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _agreed,
                                    onChanged: (v) =>
                                        setState(() => _agreed = v ?? false),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: '我已阅读并同意',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant),
                                      children: [
                                        TextSpan(
                                            text: '《用户协议》',
                                            style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w600)),
                                        TextSpan(text: ' 和 '),
                                        TextSpan(
                                            text: '《隐私政策》',
                                            style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // 登录/注册按钮
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                              ),
                              child: auth.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white))
                                  : Text(_isLogin ? '登 录' : '注 册',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 切换
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin ? '还没有账号？' : '已有账号？',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              TextButton(
                                onPressed: _toggleMode,
                                child: Text(
                                  _isLogin ? '立即注册' : '立即登录',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
