$ErrorActionPreference = 'Stop'
$interviewPath = 'C:\My\Code\Aptechka\outputs\Домашняя аптечка — вопросы для интервью.docx'
$interviewQaPath = 'C:\My\Code\Aptechka\tmp\interview-docx-qa'
New-Item -ItemType Directory -Path $interviewQaPath -Force | Out-Null
$interviewWord = $null
$interviewDoc = $null
try {
    $interviewWord = New-Object -ComObject Word.Application
    $interviewWord.Visible = $false
    $interviewWord.DisplayAlerts = 0
    $interviewDoc = $interviewWord.Documents.Open($interviewPath, $false, $true)
    $interviewDoc.Repaginate()
    $interviewPages = $interviewDoc.ComputeStatistics(2)
    $interviewDoc.ExportAsFixedFormat("$interviewQaPath\interview.pdf", 17)
    Write-Output "Rendered pages: $interviewPages"
} finally {
    if ($null -ne $interviewDoc) { $interviewDoc.Close(0) }
    if ($null -ne $interviewWord) { $interviewWord.Quit() }
}
