# Daiym Reader — Flutter 原型

此项目是一个可继续编译调试的 Flutter Android 原型，默认站点为 `https://www.daiym.cn/`，默认优先打开 `/code/` 分类。

## 功能
- 尝试自动从首页导航读取站点分类
- 解析分类页文章标题、摘要、封面、日期和链接
- 标题搜索、下拉刷新、分类切换
- 文章详情解析 HTML 正文，保留正文中的图片和可被 flutter_html 支持的 HTML 内容
- 可选远程 JSON 配置主站地址

## 编译
1. 在支持 Flutter 的云端构建环境或电脑上打开此目录。
2. 运行 `flutter pub get`。
3. 运行 `flutter build apk --release`。

## 远程更换主站
编辑 `lib/site_service.dart` 的 `remoteConfigUrl`，指向你自己控制的 HTTPS JSON 文件，例如：

```json
{"site_url":"https://www.daiym.cn/"}
```

只有配置文件地址预先写入 App 后，App 才能远程更换主站。不要把不可信配置当作可执行代码。

## 重要限制
- 这是初始原型，未在 Android 设备上编译或实机测试。
- HTML 解析器采用通用选择器；目标网站改版或卡片结构特殊时，需要根据页面 HTML 调整 CSS 选择器。
- 视频播放取决于文章中的媒体标签、视频源格式和网站访问策略；当前详情页通过 HTML 呈现，不能保证所有第三方播放器都能播放。
- 请仅读取你有权访问和使用的内容，并遵守网站条款、版权和隐私要求。

## 仅用安卓手机通过 GitHub Actions 云端编译
1. 在 GitHub 新建一个空仓库。
2. 用 GitHub 网页版上传本项目内的所有文件（包括隐藏目录 `.github/workflows/build-apk.yml`）。
3. 打开仓库的 **Actions** 页面，选择 **Build Android APK**，点击 **Run workflow**；也可以上传到 `main`/`master` 分支后自动触发。
4. 等待工作流成功后，进入该次运行页面底部的 **Artifacts**，下载 `daiym-reader-release-apk`，解压得到 `app-release.apk`。

说明：云端工作流会生成 Android 平台文件并尝试编译。此原型尚未经过实机验证，首次构建若失败，请打开 Actions 日志查看错误；网站解析规则也可能需要根据实际 HTML 调整。
