$ErrorActionPreference = 'Stop'
$S = $PSScriptRoot
$KEY = $env:AIVA_TEST_KEY   # ключ из узла «Вход: Telegram или тест»
$URL = 'http://localhost:5678/webhook/aiva-test'
$START = @{ Дата_открытия_счета = '05.10.2026' }   # открыт < месяца назад -> СТАРТ
$INV = @{ Дата_открытия_счета = '01.03.2026' }     # открыт давно -> ИНВЕСТОР

# id, группа, название, текст, клиент, доп.поля, ожидаемое (текстом), проверка (scriptblock над $r)
$cases = @(
  @{ id='TC01'; grp='Тарифы'; name='Комиссия KASE, тариф СТАРТ'; text='Сколько стоит купить акции на KASE?'; client=$START; expect='answered, 0,05%'; check={ $r.status -eq 'answered' -and $r.answer -match '0[.,]05\s*%' } }
  @{ id='TC02'; grp='Тарифы'; name='Комиссия KASE, тариф ИНВЕСТОР'; text='Сколько стоит купить акции на KASE?'; client=$INV; expect='answered, 0,085%'; check={ $r.status -eq 'answered' -and $r.answer -match '0[.,]085\s*%' } }
  @{ id='TC03'; grp='Тарифы'; name='Международный рынок, ИНВЕСТОР'; text='Какая комиссия за покупку акций Apple на американском рынке?'; client=$INV; expect='answered, 0,5% + $0,012 + $1,2'; check={ $r.status -eq 'answered' -and $r.answer -match '0[.,]5\s*%' -and $r.answer -match '1[.,]2' } }
  @{ id='TC04'; grp='Тарифы'; name='Облигации Freedom без комиссии'; text='Сколько стоит купить облигации Freedom?'; client=$INV; expect='answered, «без комиссии»'; check={ $r.status -eq 'answered' -and $r.answer -match 'без\s+комисс' } }
  @{ id='TC05'; grp='Стоп-сигналы'; name='Сумма $150 000 цифрами'; text='Хочу вложить 150 000 долларов'; client=$INV; expect='transferred'; check={ $r.status -eq 'transferred' } }
  @{ id='TC06'; grp='Стоп-сигналы'; name='Сумма словами (сто двадцать тысяч)'; text='Готов инвестировать сто двадцать тысяч долларов'; client=$INV; expect='transferred'; check={ $r.status -eq 'transferred' } }
  @{ id='TC07'; grp='Стоп-сигналы'; name='Паника клиента'; text='Всё падает, срочно продайте всё, я теряю деньги!!!'; client=$INV; expect='transferred'; check={ $r.status -eq 'transferred' } }
  @{ id='TC08'; grp='Стоп-сигналы'; name='Родственник (категория Семья)'; text='Привет! Как дела? Подскажи, что сейчас купить?'; client=@{ Категория='Семья'; Дата_открытия_счета='01.03.2026' }; expect='transferred, фраза «занят на биржевых торгах»'; check={ $r.status -eq 'transferred' -and $r.answer -match 'торгах' } }
  @{ id='TC09'; grp='Сценарии'; name='Перевод в Контакт-центр'; text='Добрый день'; client=@{ Статус='Перевод_в_КЦ'; Дата_открытия_счета='01.03.2026' }; expect='шаблон про Контакт-центр'; check={ $r.answer -match 'Контакт-центр' } }
  @{ id='TC10'; grp='Сценарии'; name='Открытие счёта ФЛ'; text='Как открыть брокерский счёт физическому лицу?'; client=$INV; expect='answered, онлайн через приложение'; check={ $r.status -eq 'answered' -and $r.answer -match 'приложени' } }
  @{ id='TC11'; grp='Сценарии'; name='Счёт для ИП'; text='Хочу открыть брокерский счёт как ИП'; client=$INV; expect='answered, ИП не обслуживаются + уточнить ФЛ/ЮЛ'; check={ $r.status -eq 'answered' -and $r.answer -match 'ИП' -and $r.answer -match 'не\s+открыва|не\s+обслужива|не\s+предоставля|невозможно|не\s+может' } }
  @{ id='TC12'; grp='Сценарии'; name='Ставка сберсчёта без Google Drive'; text='Какая сейчас ставка по сберегательному счёту?'; client=$INV; expect='answered, без выдуманных процентов'; check={ $r.status -eq 'answered' -and $r.answer -notmatch '\d+([.,]\d+)?\s*%' } }
  @{ id='TC13'; grp='Языки'; name='Вопрос на английском'; text='What is the commission for buying shares on KASE?'; client=$INV; expect='answered, ответ на английском + Sincerely, Aiva'; check={ $r.status -eq 'answered' -and $r.answer -match 'Sincerely,\s*Aiva' } }
  @{ id='TC14'; grp='Языки'; name='Вопрос на казахском'; text='KASE-де акция сатып алу комиссиясы қанша?'; client=$INV; expect='answered, подпись Құрметпен, Айва'; check={ $r.status -eq 'answered' -and $r.answer -match 'Құрметпен' } }
  @{ id='TC15'; grp='Обработка'; name='Не текст (стикер/голос)'; text=''; client=$INV; expect='non_text, просьба написать текстом'; check={ $r.status -eq 'non_text' } }
  @{ id='TC16'; grp='Обработка'; name='Нерабочее время (22:00)'; text='Сколько стоит купить акции на KASE?'; client=$INV; extra=@{ hour=22 }; expect='after_hours, без вызова AI'; check={ $r.status -eq 'after_hours' } }
  @{ id='TC17'; grp='Обработка'; name='Повтор вопроса в той же сессии (1/2)'; text='Сколько стоит купить акции на KASE?'; client=$INV; chat='TC17'; expect='answered'; check={ $r.status -eq 'answered' } }
  @{ id='TC18'; grp='Обработка'; name='Повтор вопроса в той же сессии (2/2)'; text='Сколько стоит купить акции на KASE?'; client=$INV; chat='TC17'; expect='answered (обычный повтор не должен уходить человеку)'; check={ $r.status -eq 'answered' } }
  @{ id='TC19'; grp='Обработка'; name='Ошибка в воркфлоу → обработчик ошибок'; text='тест'; client=$INV; extra=@{ forceError=$true }; expect='HTTP 500 + уведомление Мадине в Telegram + строка в журнале'; check={ $r.status -eq 'http_error' } }
)

$results = @()
foreach ($c in $cases) {
  $body = @{ key=$KEY; case=$(if($c.chat){$c.chat}else{$c.id}); text=$c.text; client=$c.client }
  if ($c.extra) { foreach($k in $c.extra.Keys){ $body[$k] = $c.extra[$k] } }
  $json = $body | ConvertTo-Json -Depth 5
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $r = Invoke-RestMethod -Method Post -Uri $URL -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 120
  } catch {
    $r = [pscustomobject]@{ status='http_error'; answer=''; error=$_.Exception.Message; duration_ms=$null }
  }
  $sec = [math]::Round($sw.Elapsed.TotalSeconds, 1)
  $pass = [bool](& $c.check)
  $results += [pscustomobject]@{ id=$c.id; group=$c.grp; name=$c.name; input=$c.text; expect=$c.expect; status=$r.status; answer=$r.answer; error=$r.error; seconds=$sec; pass=$pass }
  "{0} {1,-5} {2,-12} {3,5}s  {4}" -f $c.id, $(if($pass){'PASS'}else{'FAIL'}), $r.status, $sec, $c.name
  Start-Sleep -Seconds 3
}
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText("$S\test_results.json", ($results | ConvertTo-Json -Depth 5), $enc)
"passed: $(($results | ? pass).Count) / $($results.Count)"
