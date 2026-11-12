# index.html을 웹 링크(claude.ai) 게시용 파일로 바꿉니다.
# - Pretendard 폰트를 파일 안에 넣음 (웹 링크에서는 외부 폰트 CSS를 못 불러옴)
# - <!doctype>, <html>, <head>, <body> 태그를 뺌 (게시할 때 자동으로 붙음)
# 결과: dist\banner-editor.html
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src = [IO.File]::ReadAllText("$root\index.html", [Text.Encoding]::UTF8).Replace("`r`n", "`n")

$pretendard = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$root\fonts\PretendardVariable.woff2"))
$pretendardCss = "<style>@font-face{font-family:'Pretendard Variable';font-weight:45 920;font-style:normal;font-display:swap;src:url(data:font/woff2;base64,$pretendard) format('woff2-variations')}</style>"
$out = [regex]::Replace($src, '<link[^>]*cdn\.jsdelivr\.net/npm/pretendard[^>]*>', { $pretendardCss })
# 나머지 글꼴(SUIT·Gmarket Sans·S-Core Dream): url(fonts/파일) → 파일 안에 넣기
$out = [regex]::Replace($out, 'url\(fonts/([^)]+)\)', {
  param($m)
  $name = $m.Groups[1].Value
  $mime = if ($name -like '*.woff2') { 'font/woff2' } else { 'font/woff' }
  "url(data:$mime;base64,$([Convert]::ToBase64String([IO.File]::ReadAllBytes("$root\fonts\$name"))))"
})
if ($out -match 'url\(fonts/') { throw '글꼴 파일을 파일 안으로 넣지 못했어요' }
# claude.ai 링크에서는 Supabase에 연결하지 않음: config.js 불러오기를 빼서 등록 · 공유 칸은 '설정 전'으로 보임
$out = [regex]::Replace($out, '<!--[^>]*Supabase[^>]*-->\s*<script src="config\.js"></script>\s*', '')
foreach ($pat in '<!doctype html>\s*', '<html[^>]*>\s*', '<head>\s*', '<meta charset[^>]*>\s*', '<meta name="viewport"[^>]*>\s*', '</head>\s*', '<body>\s*', '</body>\s*', '</html>\s*') {
  $out = [regex]::Replace($out, $pat, '', 'IgnoreCase')
}
if ($out -match '<link[^>]*cdn\.jsdelivr\.net') { throw '폰트 링크를 파일 안으로 넣지 못했어요' }

New-Item -ItemType Directory -Force "$root\dist" | Out-Null
[IO.File]::WriteAllText("$root\dist\banner-editor.html", $out, (New-Object Text.UTF8Encoding $false))
"BUILD OK $([math]::Round($out.Length / 1KB)) KB"
