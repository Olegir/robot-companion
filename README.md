# 🤖 Robot Companion

A tiny, cute desktop robot for macOS. It walks along the bottom of your screen, jumps onto windows, builds blocks, waters a flower, drinks coffee, follows your cursor with its eyes, and runs simple commands.

*[Українська версія нижче](#-робот-компаньйон)*

> **Not affiliated with or endorsed by Anthropic.** "Claude" is a trademark of Anthropic, PBC. This is an independent hobby project. The robot can open the Claude app if you have it installed, the same way it can open Safari or Telegram.

## Features

- **Lives on your desktop:** walks, jumps onto windows and rides along when you move them, falls down when a window closes
- **Activities:** builds blocks, rummages in folders, waters a growing flower, drinks coffee, plays with a ball, reads, dances
- **Reacts to you:** eyes follow the cursor, blushes on hover, shows hearts when you pet it with the mouse
- **Commands:** click the robot and type, for example `open the last tab in safari`, `timer 10 min`, `open downloads folder`, `search for pancake recipe`
- **Break reminders** every 30, 50 or 90 minutes
- **Seasonal costumes:** autumn, winter, New Year, spring, summer, Halloween, Ukrainian Independence Day
- **Two languages:** English and Ukrainian (switch in the menu; commands work in both)
- **Optional autostart** with your Mac (it asks first)

## Requirements

- macOS 12 or later (Apple Silicon or Intel)
- Apple Command Line Tools (the build script offers to install them)

## Build and run

1. Download or clone this repository.
2. Open **Terminal** and run:
   ```bash
   bash path/to/robot-companion/build.command
   ```
3. The script builds `Robot Companion.app` next to the source and launches it.

You build the app yourself from the source code, so nothing pre-compiled is downloaded.

## How to use

| Action | Result |
|---|---|
| Click the robot | Command field opens (empty Enter opens Claude) |
| Drag the robot | Move it anywhere; it falls onto the nearest window |
| Move the mouse back and forth over it | Petting ♥ |
| Hover for a second | Shows the time or the timer countdown |
| Right-click | Menu: activities, costume, language, break reminders, autostart, quit |

Right-click → **What can you do?** shows all commands.

## Permissions

macOS may ask for these the first time you use certain commands. All are optional.

- **Automation** (control Safari / Chrome / System Events): needed for tab commands.
- **Accessibility**: needed only for "reopen closed tab" (the robot presses ⇧⌘T for you).
- **Screen Recording**: needed only for the screenshot command.

macOS treats every rebuild as a new app, so it may ask again after you rebuild.

## Privacy

- The app makes **no network requests** of its own and has **no analytics or telemetry**.
- It only opens websites or apps when you ask it to.
- Your settings (language, name, costume, colour) are stored **only on your Mac** in the app's preferences.
- To find windows to walk on, it reads only window **positions and sizes**, never window contents or titles.

## Uninstall

1. Right-click the robot → turn off **Start with Mac** → **Quit**.
2. Delete `Robot Companion.app`.
3. Optionally remove the settings: `defaults delete local.robotcompanion`

## License

MIT — see [LICENSE](LICENSE). The software is provided "as is", without warranty of any kind.

---

# 🤖 Робот-компаньйон

Маленький милий робот для робочого столу macOS. Гуляє внизу екрана, стрибає на вікна, будує кубики, поливає квітку, п'є каву, стежить очима за курсором і виконує прості команди.

> **Проєкт не пов'язаний з Anthropic і не схвалений нею.** «Claude» — торгова марка Anthropic, PBC. Це незалежний хобі-проєкт. Робот може відкрити застосунок Claude, якщо він у вас встановлений, так само як відкриває Safari чи Telegram.

## Можливості

- **Живе на робочому столі:** гуляє, застрибує на вікна і їде разом із ними, падає, коли вікно закривають
- **Заняття:** будує кубики, нишпорить у папках, поливає квітку, п'є каву, грає з м'ячиком, читає, танцює
- **Реагує на вас:** очі стежать за курсором, червоніє при наведенні, показує сердечка, коли його гладять мишкою
- **Команди:** клацніть на робота і напишіть, наприклад, `відкрий останню вкладку в сафарі`, `таймер 10 хв`, `відкрий папку завантаження`, `знайди рецепт борщу`
- **Нагадування про перерву** кожні 30, 50 або 90 хвилин
- **Сезонні костюми:** осінь, зима, Новий рік, весна, літо, Хелловін, День Незалежності України
- **Дві мови:** українська та англійська (перемикач у меню, команди розуміє обома мовами)
- **Автозапуск** разом із Mac (за бажанням, програма спершу питає)

## Вимоги

- macOS 12 або новіша (Apple Silicon або Intel)
- Інструменти розробника Apple (Command Line Tools); скрипт запропонує їх встановити

## Збирання і запуск

1. Завантажте або клонуйте цей репозиторій.
2. Відкрийте **Термінал** і виконайте:
   ```bash
   bash шлях/до/robot-companion/build.command
   ```
3. Скрипт збере `Robot Companion.app` поруч із кодом і запустить його.

Програму ви збираєте самі з вихідного коду, тому нічого вже скомпільованого не завантажується.

## Як користуватися

| Дія | Результат |
|---|---|
| Клік по роботу | Відкривається поле для команди (порожній Enter відкриває Claude) |
| Перетягнути робота | Переносить куди завгодно; він падає на найближче вікно |
| Поводити мишкою туди-сюди | Погладжування ♥ |
| Затримати курсор на секунду | Показує час або залишок таймера |
| Правий клік | Меню: заняття, костюм, мова, нагадування, автозапуск, вихід |

Правий клік → **Що ти вмієш?** показує всі команди.

## Дозволи

macOS може запитати їх, коли ви вперше скористаєтесь певними командами. Усі вони необов'язкові.

- **Автоматизація** (керування Safari / Chrome / System Events): потрібна для команд із вкладками.
- **Універсальний доступ**: лише для «поверни закриту вкладку» (робот натискає ⇧⌘T за вас).
- **Запис екрана**: лише для команди «зроби скрін».

Після кожного перезбирання macOS вважає програму новою і може запитати дозволи знову.

## Приватність

- Програма **не робить власних мережевих запитів** і **не збирає жодної аналітики**.
- Вона відкриває сайти чи програми лише на ваше прохання.
- Налаштування (мова, ім'я, костюм, колір) зберігаються **лише на вашому Mac**.
- Щоб знайти вікна, по яких можна гуляти, робот бачить тільки **розташування і розміри** вікон, але не їхній вміст чи заголовки.

## Видалення

1. Правий клік по роботу → вимкніть **Запускати разом із Mac** → **Вийти**.
2. Видаліть `Robot Companion.app`.
3. За бажанням видаліть налаштування: `defaults delete local.robotcompanion`

## Ліцензія

MIT — див. [LICENSE](LICENSE). Програма надається «як є», без жодних гарантій.
