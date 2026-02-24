import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../providers/tabs_provider.dart';
import '../../providers/active_tab_provider.dart';

/// 새 탭 추가 모달
class AddTabModal extends ConsumerStatefulWidget {
  const AddTabModal({super.key});

  @override
  ConsumerState<AddTabModal> createState() => _AddTabModalState();
}

class _AddTabModalState extends ConsumerState<AddTabModal> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _openExternal = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  /// 프리셋 탭 이름/URL을 폼에 채운다.
  void _fillPreset(String name, String url, {bool openExternal = false}) {
    _nameCtrl.text = name;
    _urlCtrl.text = url;
    setState(() => _openExternal = openExternal);
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();

    await ref.read(tabsProvider.notifier).addTab(name, url, openExternal: _openExternal);

    // 외부 브라우저 탭은 activeTab 전환 없음 (현재 웹뷰 탭 유지)
    if (!_openExternal) {
      final tabs = await ref.read(tabsProvider.future);
      if (tabs.isNotEmpty) {
        ref.read(activeTabIdProvider.notifier).state = tabs.last.id;
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(kColorBgSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '새 탭 추가',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // ── 빠른 추가 프리셋 ───────────────────────────────────
                Text(
                  '빠른 추가',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    color: const Color(kColorTextMuted),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _PresetChip(
                      label: '클로바노트',
                      onTap: () => _fillPreset(
                        '클로바노트',
                        'https://clovanote.naver.com',
                        openExternal: true,
                      ),
                    ),
                    _PresetChip(
                      label: 'Perplexity',
                      onTap: () => _fillPreset(
                        'Perplexity',
                        'https://www.perplexity.ai',
                      ),
                    ),
                    _PresetChip(
                      label: 'ChatGPT',
                      onTap: () => _fillPreset(
                        'ChatGPT',
                        'https://chatgpt.com',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 탭 이름 ────────────────────────────────────────────
                _FieldLabel('탭 이름'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  maxLength: 20,
                  style: _inputStyle(),
                  decoration: _inputDecoration('예: 클로바노트'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '탭 이름을 입력하세요' : null,
                ),
                const SizedBox(height: 14),

                // ── URL ────────────────────────────────────────────────
                _FieldLabel('URL'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  style: _inputStyle(),
                  decoration: _inputDecoration('https://...'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'URL을 입력하세요';
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null || !uri.isAbsolute) return '올바른 URL을 입력하세요';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── 외부 브라우저로 열기 토글 ───────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(kColorBgPrimary),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(kColorBorder)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '외부 브라우저로 열기',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 13,
                                color: const Color(kColorTextPrimary),
                              ),
                            ),
                          ),
                          Switch(
                            value: _openExternal,
                            onChanged: (v) => setState(() => _openExternal = v),
                            activeTrackColor: const Color(kColorAccentPrimary),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      if (_openExternal) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 12,
                              color: Color(kColorTextMuted),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '마이크/카메라가 필요한 서비스는 외부 브라우저를 사용하세요',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 11,
                                  color: const Color(kColorTextMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '취소',
                        style: GoogleFonts.notoSansKr(
                            color: const Color(kColorTextMuted)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(kColorAccentPrimary),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        '추가',
                        style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _inputStyle() => GoogleFonts.notoSansKr(
        fontSize: 13,
        color: const Color(kColorTextPrimary),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(kColorTextMuted)),
        counterText: '',
        filled: true,
        fillColor: const Color(kColorBgPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(kColorBorder)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(kColorBorder)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(kColorAccentPrimary)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(kColorDanger)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(kColorDanger)),
        ),
      );
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          color: const Color(kColorTextMuted),
        ),
      ),
      onPressed: onTap,
      backgroundColor: const Color(kColorBgPrimary),
      side: const BorderSide(color: Color(kColorBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.notoSansKr(
        fontSize: 12,
        color: const Color(kColorTextMuted),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
