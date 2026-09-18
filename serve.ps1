$ErrorActionPreference = "Stop"
$port = 8080
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-PortFree([int]$p) {
  try {
    $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
    $l.Start()
    $l.Stop()
    return $true
  } catch {
    return $false
  }
}

try {
  if (-not (Test-PortFree $port)) {
    Write-Host ""
    Write-Host "端口 $port 已被占用（可能已经开着服务了）。" -ForegroundColor Yellow
    Write-Host "请先打开浏览器试试: http://127.0.0.1:$port/" -ForegroundColor Yellow
    Write-Host "或者关掉之前那个黑窗口后再启动。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "按任意键退出..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
  }

  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add("http://127.0.0.1:$port/")
  $listener.Start()
  Write-Host ""
  Write-Host "========================================" -ForegroundColor Cyan
  Write-Host " 服务已启动，请不要关闭本窗口" -ForegroundColor Cyan
  Write-Host " 大厅: http://127.0.0.1:$port/" -ForegroundColor Green
  Write-Host " 游戏: http://127.0.0.1:$port/games/breach.html" -ForegroundColor Green
  Write-Host " 停止: 按 Ctrl+C" -ForegroundColor DarkGray
  Write-Host "========================================" -ForegroundColor Cyan
  Write-Host ""

  function Get-Mime([string]$ext) {
    switch ($ext.ToLower()) {
      ".html" { "text/html; charset=utf-8" }
      ".js"   { "application/javascript" }
      ".css"  { "text/css" }
      ".png"  { "image/png" }
      ".jpg"  { "image/jpeg" }
      ".jpeg" { "image/jpeg" }
      ".glb"  { "model/gltf-binary" }
      ".json" { "application/json" }
      ".svg"  { "image/svg+xml" }
      ".wasm" { "application/wasm" }
      default { "application/octet-stream" }
    }
  }

  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $rel = [Uri]::UnescapeDataString($ctx.Request.Url.LocalPath.TrimStart("/").Replace("/", "\"))
      if ([string]::IsNullOrEmpty($rel)) { $rel = "index.html" }
      $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $ctx.Response.StatusCode = 403
        $ctx.Response.Close()
        continue
      }
      if (Test-Path $full -PathType Container) {
        $full = Join-Path $full "index.html"
      }
      if (-not (Test-Path $full -PathType Leaf)) {
        $ctx.Response.StatusCode = 404
        $bytes404 = [Text.Encoding]::UTF8.GetBytes("404")
        $ctx.Response.ContentType = "text/plain; charset=utf-8"
        $ctx.Response.ContentLength64 = $bytes404.Length
        $ctx.Response.OutputStream.Write($bytes404, 0, $bytes404.Length)
        $ctx.Response.Close()
        continue
      }
      $bytes = [IO.File]::ReadAllBytes($full)
      $ctx.Response.StatusCode = 200
      $ctx.Response.ContentType = Get-Mime ([IO.Path]::GetExtension($full))
      $ctx.Response.SendChunked = $false
      $ctx.Response.ContentLength64 = $bytes.LongLength
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      $ctx.Response.OutputStream.Flush()
      $ctx.Response.Close()
    } catch {
      Write-Warning $_.Exception.Message
      try { $ctx.Response.Abort() } catch {}
    }
  }
} catch {
  Write-Host ""
  Write-Host "启动失败: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ""
  Write-Host "按任意键退出..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  exit 1
}
