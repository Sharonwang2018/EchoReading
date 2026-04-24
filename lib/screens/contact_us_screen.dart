import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 联系我们页面
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const _email = 'gwenmzx@hotmail.com';

  void _copyEmail(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('邮箱已复制: \$_email'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('联系我们', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context).copyWith(top: 24, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Column(children: [
                  Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFFF8C42), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.support_agent_rounded, size: 48, color: Colors.white)),
                  const SizedBox(height: 16),
                  Text('Hi-Doo 绘读', style: GoogleFonts.quicksand(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1a1a1a))),
                  const SizedBox(height: 8),
                  Text('会读，更会说', style: GoogleFonts.quicksand(fontSize: 14, color: const Color(0xFF666666))),
                ])),
                const SizedBox(height: 40),
                _ContactCard(icon: Icons.bug_report_rounded, title: '技术支持', description: '遇到问题？告诉我们，帮助我们改进产品', buttonText: '反馈问题', onTap: () => _copyEmail(context)),
                const SizedBox(height: 16),
                _ContactCard(icon: Icons.business_rounded, title: '商务合作', description: '教育机构、出版社、企业合作洽谈', buttonText: '商务洽谈', onTap: () => _copyEmail(context)),
                const SizedBox(height: 16),
                _ContactCard(icon: Icons.lightbulb_rounded, title: '功能建议', description: '期待新功能？告诉我们你的想法', buttonText: '提出建议', onTap: () => _copyEmail(context)),
                const SizedBox(height: 16),
                _ContactCard(icon: Icons.verified_rounded, title: '内容合作', description: '优质绘本、儿童内容合作', buttonText: '内容合作', onTap: () => _copyEmail(context)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.email_rounded, color: Color(0xFFFF8C42), size: 24),
                      const SizedBox(width: 8),
                      Text('邮箱地址', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF333333))),
                    ]),
                    const SizedBox(height: 12),
                    InkWell(onTap: () => _copyEmail(context), child: Text(_email, style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF2196F3), decoration: TextDecoration.underline))),
                    const SizedBox(height: 8),
                    Text('点击复制邮箱地址', style: GoogleFonts.quicksand(fontSize: 12, color: const Color(0xFF999999))),
                  ]),
                ),
                const SizedBox(height: 32),
                Center(child: Text('Version 1.0.0', style: GoogleFonts.quicksand(fontSize: 12, color: const Color(0xFFCCCCCC)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon; final String title; final String description; final String buttonText; final VoidCallback onTap;
  const _ContactCard({required this.icon, required this.title, required this.description, required this.buttonText, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFF3EB), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFFFF8C42), size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1a1a1a))),
            const SizedBox(height: 2),
            Text(description, style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF666666))),
          ])),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C42), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: Text(buttonText, style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}
