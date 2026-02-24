import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../providers/settings_provider.dart';

/// 환경설정 모달
/// - 탭 자동 최적화 토글
class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Dialog(
      backgroundColor: const Color(kColorBgSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: Color(kColorAccentLight),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '환경설정',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              settingsAsync.when(
                data: (settings) => Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '탭 자동 최적화',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '사용하지 않는 탭을 자동으로 일시 중단합니다',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              color: const Color(kColorTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.autoSuspendTabs,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .updateAutoSuspend(v),
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Color(kColorAccentPrimary)),
                ),
                error: (e, _) => Text('오류: $e',
                    style: const TextStyle(color: Color(kColorDanger))),
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(kColorBorder), height: 1),
              const SizedBox(height: 20),

              // 글로벌 단축키 안내
              Text(
                '글로벌 단축키',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(kColorBgTertiary),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(kColorBorder)),
                    ),
                    child: Text(
                      'F1',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: const Color(kColorTextPrimary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '창 표시 / 숨기기',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: const Color(kColorTextMuted),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '닫기',
                    style: GoogleFonts.notoSansKr(
                      color: const Color(kColorTextMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
