# 🧩 سكريبت لإصلاح كل ملفات Dart في المشروع واستبدال الـ backticks بعلامة $
# إعداد المسار الرئيسي للمشروع
$projectPath = "C:\repo\active_class"

Write-Host "🔍 Scanning all Dart files under: $projectPath" -ForegroundColor Cyan

# البحث عن كل ملفات .dart داخل مجلد المشروع والمجلدات الفرعية
$dartFiles = Get-ChildItem -Path $projectPath -Recurse -Filter *.dart

# عداد للملفات اللي تم تعديلها
$fixedCount = 0

foreach ($file in $dartFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if ($content -match "``") {
        $content = $content -replace "``", "`$"
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
        Write-Host "✅ Fixed: $($file.FullName)" -ForegroundColor Green
        $fixedCount++
    }
}

if ($fixedCount -gt 0) {
    Write-Host "`n🎯 Done! Fixed $fixedCount file(s) containing backticks." -ForegroundColor Yellow
} else {
    Write-Host "`n✨ No files needed fixing. Everything looks clean!" -ForegroundColor Gray
}
