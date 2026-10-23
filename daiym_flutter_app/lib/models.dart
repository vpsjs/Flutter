class SiteCategory {
  final String name;
  final String url;
  const SiteCategory(this.name, this.url);
}

class ArticleItem {
  final String title;
  final String url;
  final String summary;
  final String image;
  final String date;
  const ArticleItem({required this.title, required this.url, this.summary = '', this.image = '', this.date = ''});
}
