import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'site_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SiteService.loadRemoteConfig();
  runApp(const DaiymReaderApp());
}

class DaiymReaderApp extends StatelessWidget {
  const DaiymReaderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '资讯阅读', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2367d1)), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  List<SiteCategory> categories = [];
  SiteCategory selected = SiteCategory('综合源码', 'https://www.daiym.cn/code/');
  List<ArticleItem> articles = [];
  bool loading = true;
  String? error;
  String search = '';
  final searchController = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final cats = await SiteService.getCategories();
      final chosen = cats.where((c) => c.url.contains('/code/')).firstOrNull ?? (cats.isNotEmpty ? cats.first : selected);
      final list = await SiteService.getArticles(chosen.url);
      if (!mounted) return;
      setState(() { categories = cats; selected = chosen; articles = list; loading = false; });
    } catch (e) { if (mounted) setState(() { loading = false; error = e.toString(); }); }
  }
  Future<void> _choose(SiteCategory c) async {
    setState(() { selected = c; loading = true; error = null; });
    try { final list = await SiteService.getArticles(c.url); if (mounted) setState(() { articles = list; loading = false; }); }
    catch (e) { if (mounted) setState(() { loading = false; error = e.toString(); }); }
  }
  @override Widget build(BuildContext context) {
    final shown = articles.where((a) => a.title.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('资讯阅读'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: TextField(controller: searchController, onChanged: (v) => setState(() => search = v), decoration: InputDecoration(hintText: '搜索文章标题', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () { searchController.clear(); setState(() => search = ''); }, icon: const Icon(Icons.clear)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
        SizedBox(height: 48, child: categories.isEmpty ? const SizedBox() : ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), itemCount: categories.length, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) { final c = categories[i]; return ChoiceChip(label: Text(c.name), selected: selected.url == c.url, onSelected: (_) => _choose(c)); })),
        Expanded(child: RefreshIndicator(onRefresh: () async { await _choose(selected); }, child: loading ? ListView(children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator())]) : error != null ? ListView(children: [const SizedBox(height: 100), Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('加载失败：$error\n\n请检查网络或网站是否允许访问。', textAlign: TextAlign.center))), Center(child: ElevatedButton(onPressed: _load, child: const Text('重试')))]) : shown.isEmpty ? ListView(children: const [SizedBox(height: 100), Center(child: Text('没有解析到文章。网站页面结构可能需要调整解析规则。'))]) : ListView.builder(itemCount: shown.length, itemBuilder: (_, i) => ArticleCard(item: shown[i])))),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: 0, onDestinationSelected: (i) { if (i == 1) _showSettings(); }, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'), NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置')]),
    );
  }
  void _showSettings() { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('站点设置'), content: Text('当前主站：${SiteService.siteUrl}\n\n此原型的远程配置地址需要在 lib/site_service.dart 中填写 remoteConfigUrl。分类可自动读取，若新站结构不同，需要调整 HTML 解析规则。'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))])); }
}

class ArticleCard extends StatelessWidget {
  final ArticleItem item; const ArticleCard({super.key, required this.item});
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(item: item))), child: Padding(padding: const EdgeInsets.all(10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (item.image.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item.image, width: 112, height: 94, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())) else _placeholder(),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 6), if (item.summary.isNotEmpty) Text(item.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)), const SizedBox(height: 6), Text(item.date.isEmpty ? Uri.parse(item.url).host : item.date, style: TextStyle(color: Colors.grey.shade600, fontSize: 11))]))
  ]))));
  Widget _placeholder() => Container(width: 112, height: 94, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.article_outlined, size: 32));
}

class DetailPage extends StatefulWidget { final ArticleItem item; const DetailPage({super.key, required this.item}); @override State<DetailPage> createState() => _DetailPageState(); }
class _DetailPageState extends State<DetailPage> {
  String? htmlBody; String? error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final doc = await SiteService.getArticleDocument(widget.item.url); final main = doc.querySelector('article') ?? doc.querySelector('main') ?? doc.querySelector('.entry-content') ?? doc.querySelector('.post-content') ?? doc.body; if (mounted) setState(() => htmlBody = main?.innerHtml ?? doc.body?.innerHtml ?? ''); } catch (e) { if (mounted) setState(() => error = e.toString()); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('文章详情')), body: htmlBody == null && error == null ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Text('加载失败：$error')) : SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(widget.item.date, style: TextStyle(color: Colors.grey.shade600)), const Divider(height: 24), Html(data: htmlBody!, onLinkTap: (url, _, __) { if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }, style: {'body': Style(fontSize: FontSize(16), lineHeight: LineHeight(1.6)), 'img': Style(margin: Margins.symmetric(vertical: 8))})])));
}
