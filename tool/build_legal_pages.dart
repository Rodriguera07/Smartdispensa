// Gera as páginas web públicas dos documentos legais a partir dos mesmos
// arquivos usados no app (assets/legal/*.md + config.json).
//
//   dart run tool/build_legal_pages.dart
//
// Saída em docs/ (pronta para Firebase Hosting ou GitHub Pages):
//   docs/index.html, docs/privacidade.html, docs/termos.html,
//   docs/cancelamento.html, docs/excluir-conta.html
//
// URLs para o Google Play Console (depois do deploy no Firebase Hosting):
//   https://SEU-PROJETO.web.app/privacidade.html   → Política de privacidade
//   https://SEU-PROJETO.web.app/excluir-conta.html → Exclusão de conta

import 'dart:convert';
import 'dart:io';

import 'package:smart_dispensa/core/legal/legal_markdown.dart';

void main() {
  final config = (jsonDecode(File('assets/legal/config.json').readAsStringSync())
          as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, '$v'));

  final pending = config.entries
      .where((e) => e.value.startsWith('PREENCHER'))
      .map((e) => e.key)
      .toList();
  if (pending.isNotEmpty) {
    stderr.writeln('⚠️  Campos ainda não preenchidos em assets/legal/config.json: '
        '${pending.join(', ')}');
  }

  final out = Directory('docs')..createSync(recursive: true);
  final appName = config['APP_NAME']!;

  for (final doc in LegalDoc.values) {
    final md = File(doc.assetPath).readAsStringSync();
    final body = parseLegalMarkdown(md, config).map(_blockHtml).join('\n');
    File('${out.path}/${doc.slug}.html')
        .writeAsStringSync(_page('${doc.title} — $appName', body, appName));
    stdout.writeln('✓ docs/${doc.slug}.html');
  }

  final links = LegalDoc.values
      .map((d) => '<li><a href="${d.slug}.html">${_esc(d.title)}</a></li>')
      .join('\n');
  File('${out.path}/index.html').writeAsStringSync(_page(
    appName,
    '<h1>$appName</h1>\n<p>Documentos e suporte do aplicativo.</p>\n'
        '<ul class="index">$links</ul>\n'
        '<p>Contato: <strong>${_esc(config['EMAIL']!)}</strong></p>',
    appName,
  ));
  stdout.writeln('✓ docs/index.html');
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _spans(List<LegalSpan> spans) => spans.map((s) {
      var t = _esc(s.text);
      if (s.bold) t = '<strong>$t</strong>';
      if (s.italic) t = '<em>$t</em>';
      return t;
    }).join();

String _blockHtml(LegalBlock b) => switch (b) {
      LegalHeading(:final level, :final text) => '<h$level>${_esc(text)}</h$level>',
      LegalParagraph(:final spans) => '<p>${_spans(spans)}</p>',
      LegalListItem(:final spans, :final number) => number == null
          ? '<div class="li"><span class="dot">•</span><span>${_spans(spans)}</span></div>'
          : '<div class="li"><span class="num">$number.</span><span>${_spans(spans)}</span></div>',
      LegalTable(:final header, :final rows) => '<div class="table"><table><thead><tr>'
          '${header.map((c) => '<th>${_spans(c)}</th>').join()}</tr></thead><tbody>'
          '${rows.map((r) => '<tr>${r.map((c) => '<td>${_spans(c)}</td>').join()}</tr>').join()}'
          '</tbody></table></div>',
    };

String _page(String title, String body, String appName) => '''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&family=Plus+Jakarta+Sans:wght@700;800&display=swap" rel="stylesheet">
<style>
  :root { --bg:#F4F7F9; --card:#FFFFFF; --text:#0B192C; --muted:#4D5E70; --line:#DCE4EA; --accent:#00876A; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#0B192C; --card:#10233A; --text:#F2F6FA; --muted:#A9B8C9; --line:#22384F; --accent:#00D09C; }
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:17px/1.65 Inter, system-ui, sans-serif; }
  header { padding:20px 16px; border-bottom:1px solid var(--line); }
  header a { color:var(--text); text-decoration:none; font:800 20px "Plus Jakarta Sans", sans-serif; }
  header span { color:var(--accent); }
  main { max-width:760px; margin:0 auto; padding:24px 16px 64px; }
  h1, h2, h3 { font-family:"Plus Jakarta Sans", sans-serif; line-height:1.25; }
  h1 { font-size:30px; margin:8px 0 4px; }
  h2 { font-size:21px; margin:32px 0 8px; }
  h3 { font-size:18px; }
  p { margin:10px 0; }
  em { color:var(--muted); }
  strong { font-weight:600; }
  .li { display:flex; gap:10px; margin:6px 0; }
  .dot, .num { color:var(--accent); font-weight:600; min-width:18px; }
  .table { overflow-x:auto; margin:12px 0; }
  table { border-collapse:collapse; width:100%; background:var(--card); border-radius:12px; overflow:hidden; }
  th, td { text-align:left; padding:10px 12px; border-bottom:1px solid var(--line); vertical-align:top; font-size:15px; }
  th { font-weight:600; }
  ul.index { padding-left:20px; }
  ul.index a { color:var(--accent); font-weight:600; }
  footer { max-width:760px; margin:0 auto; padding:0 16px 40px; color:var(--muted); font-size:14px; }
  footer a { color:var(--accent); }
</style>
</head>
<body>
<header><a href="index.html">Smart <span>Dispensa</span></a></header>
<main>
$body
</main>
<footer>
  <a href="privacidade.html">Privacidade</a> ·
  <a href="termos.html">Termos</a> ·
  <a href="cancelamento.html">Cancelar assinatura</a> ·
  <a href="excluir-conta.html">Excluir conta</a>
  <br>© ${DateTime.now().year} ${_esc(appName)}
</footer>
</body>
</html>
''';
