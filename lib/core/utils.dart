/// Google Favicon API를 이용해 사이트 파비콘 URL을 반환한다.
/// Image.network가 내부적으로 캐싱하므로 별도 캐시 불필요.
String getFaviconUrl(String siteUrl, {int size = 32}) {
  try {
    final domain = Uri.parse(siteUrl).host;
    if (domain.isEmpty) return '';
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=$size';
  } catch (_) {
    return '';
  }
}
