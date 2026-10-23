import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'models.dart';

/// Generic HTML parser prototype for public pages you are authorized to read.
/// Website selectors may need adjustment if the site changes its markup.
class SiteService {
  static String siteUrl = 'https://www.daiym.cn/';
  static const String remoteConfigUrl = ''; // Optional: URL to your own JSON config.
  static final Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125 Mobile Safari/537.36',
  };

  static Uri absolute(String href, [String? base]) {
    final b = Uri.parse(base ?? siteUrl);
    return b.resolve(href.trim());
  }

  static Future<void> loadRemoteConfig() async {
    if (remoteConfigUrl.isEmpty) return;
    try {
      final r = await http.get(Uri.parse(remoteConfigUrl), headers: headers).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        final value = data['site_url']?.toString();
        if (value != null && value.startsWith('https://')) siteUrl = value.endsWith('/') ? value : '$value/';
      }
    } catch (_) {
      // Keep the built-in default if remote configuration is unavailable.
    }
  }

  static Future<Document> _document(String url) async {
    final r = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('网站返回 HTTP ${r.statusCode}');
    return parser.parse(utf8.decode(r.bodyBytes, allowMalformed: true));
  }

  static Future<List<SiteCategory>> getCategories() async {
    final doc = await _document(siteUrl);
    final seen = <String>{};
    final result = <SiteCategory>[];
    // Read category links from site navigation; retain only internal links.
    for (final a in doc.querySelectorAll('header a, nav a, .nav a, .navbar a, .menu a, .categories a, footer a')) {
      final href = a.attributes['href'];
      final name = a.text.trim();
      if (href == null || name.isEmpty) continue;
      final uri = absolute(href);
      if (uri.host != Uri.parse(siteUrl).host) continue;
      if (uri.path == '/' || uri.path.contains('about') || uri.path.contains('privacy') || uri.path.contains('sitemap')) continue;
      if (!seen.add(uri.toString())) continue;
      result.add(SiteCategory(name, uri.toString()));
    }
    // Known category path as a useful fallback for the supplied site.
    if (!result.any((c) => c.url.contains('/code/'))) {
      result.insert(0, SiteCategory('综合源码', absolute('/code/').toString()));
    }
    return result;
  }

  static Future<List<ArticleItem>> getArticles(String url) async {
    final doc = await _document(url);
    final seen = <String>{};
    final items = <ArticleItem>[];
    // Prefer common article/card containers; fall back to internal links with titles.
    final containers = doc.querySelectorAll('article, .post, .post-item, .article-item, .item, .card, .list-item, .resource-item');
    for (final node in containers) {
      final item = _fromContainer(node, url);
      if (item != null && seen.add(item.url)) items.add(item);
    }
    if (items.isEmpty) {
      for (final a in doc.querySelectorAll('a[href]')) {
        final title = a.attributes['title']?.trim().isNotEmpty == true ? a.attributes['title']!.trim() : a.text.trim();
        final href = a.attributes['href'];
        if (href == null || title.length < 5) continue;
        final uri = absolute(href, url);
        if (uri.host != Uri.parse(siteUrl).host || uri.path == '/' || uri.path.endsWith('/code/')) continue;
        final parent = a.parent;
        final img = a.querySelector('img') ?? parent?.querySelector('img');
        final image = img?.attributes['data-src'] ?? img?.attributes['data-original'] ?? img?.attributes['src'] ?? '';
        final text = parent?.parent?.text.trim() ?? '';
        if (seen.add(uri.toString())) items.add(ArticleItem(title: title, url: uri.toString(), summary: text.length > title.length ? text.replaceAll(title, '').trim() : '', image: image.isEmpty ? '' : absolute(image, url).toString()));
      }
    }
    return items;
  }

  static ArticleItem? _fromContainer(Element node, String base) {
    final a = node.querySelector('h1 a, h2 a, h3 a, h4 a, .title a, a[href]');
    if (a == null) return null;
    final href = a.attributes['href'];
    final title = a.attributes['title']?.trim().isNotEmpty == true ? a.attributes['title']!.trim() : a.text.trim();
    if (href == null || title.length < 4) return null;
    final uri = absolute(href, base);
    if (uri.host != Uri.parse(siteUrl).host) return null;
    final img = node.querySelector('img');
    final image = img?.attributes['data-src'] ?? img?.attributes['data-original'] ?? img?.attributes['src'] ?? '';
    final summary = node.querySelector('.summary, .excerpt, .description, p')?.text.trim() ?? '';
    final date = node.querySelector('time, .date, .time, .post-date')?.text.trim() ?? '';
    return ArticleItem(title: title, url: uri.toString(), summary: summary, image: image.isEmpty ? '' : absolute(image, base).toString(), date: date);
  }

  static Future<Document> getArticleDocument(String url) => _document(url);
}
