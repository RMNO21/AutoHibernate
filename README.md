# 🌙 Auto Hibernate (Sleep Timer for Windows 11)

> **Smart, on-demand sleep/hibernate timer utility designed specifically for OLED laptops (like ASUS Zenbook) and Windows 11.**  
> Automatically hibernates the PC after a configurable idle period, strictly resets on real physical mouse/keyboard activity, and operates 100% silently with zero terminal flash.

---

## 📖 Overview (فارسی / Persian)

برنامه **Auto Hibernate** یک ابزار هوشمند، سبک و اختصاصی برای ویندوز ۱۱ است که به عنوان تایمر هایبرنیت/اسلیپ (Sleep Timer) بر اساس نیاز کاربر فعال می‌شود.

### چرا این برنامه ساخته شد؟
1. **جلوگیری از OLED Burn-in:** در لپ‌تاپ‌های دارای صفحه نمایش OLED (مانند ASUS Zenbook 14 OLED UX3405)، روشن ماندن صفحه با تصاویر ثابت می‌تواند باعث سوختگی پیکسل‌ها شود.
2. **مشکلات Modern Standby (S0 Low Power Idle):** در لپ‌تاپ‌های جدید، حالت اسلیپ معمولی ویندوز اغلب دستگاه را خنک نمی‌کند یا به دلیل دانلودها، برنامه‌ها، استریم صدا یا بازی‌ها بیدار می‌ماند. این برنامه با **Hibernate واقعی (`shutdown /h /f`)** دستگاه را کاملاً خاموش و امن می‌کند.
3. **ریست فقط با ورودی فیزیکی:** تایمر فقط با حرکت واقعی ماوس یا فشردن کلیدهای کیبورد ریست می‌شود. پخش ویدیو، صدای پس‌زمینه، یوتیوب، مرورگرها یا ابزارهایی مثل PowerToys Awake مانع هایبرنیت نمی‌شوند.
4. **ایزوله‌سازی سشن (Session-Only):** اگر خودتان لپ‌تاپ را دستی خاموش، هایبرنیت یا اسلیپ کنید، پس از روشن شدن مجدد، تایمر به هیچ عنوان دوباره راه نمی‌افتد و همیشه در حالت خاموش (Standby) آماده به کار است.
5. **کاملاً بی‌صدا (Zero Console Windows):** هیچ پنجره سیاه ترمینالی در ویندوز ۱۱ باز یا بسته نمی‌شود.

---

## ⚡ Quick Shortcuts (کلیدهای میانبر)

| کلید میانبر (Shortcut) | عملکرد (Action) | توضیحات |
| :--- | :--- | :--- |
| **`Ctrl + Shift + H`** | **Start Timer** (شروع) | تایمر را با زمان تعیین‌شده (پیش‌فرض ۳۰ دقیقه) فعال می‌کند. یک بنر فیروزه‌ای زیبا روی صفحه ظاهر می‌شود. |
| **`Ctrl + Shift + X`** | **Stop Timer** (توقف) | تایمر را فوراً غیرفعال و خاموش می‌کند. یک بنر قرمز تایید ظاهر می‌شود. |
| **`Ctrl + Shift + S`** | **Show Status** (وضعیت) | پنجره مدرن وضعیت زنده (Status Card) را روی صفحه باز می‌کند. |

*کلیدهای جایگزین نیز پشتیبانی می‌شوند: `Win + Shift + H` برای شروع، `Win + Shift + X` یا `Ctrl + Shift + End` برای توقف.*

---

## ✨ Features (امکانات و ویژگی‌ها)

- ⏱ **شمارش معکوس زنده:** نمایش زمان باقیمانده به صورت دیجیتال (`29:45`) در کارت وضعیت و آیکون System Tray.
- 🎛 **انتخاب سریع زمان تایمر:** قابلیت انتخاب ۱۰، ۱۵، ۲۰، ۳۰، ۴۵، ۶۰، ۹۰ یا ۱۲۰ دقیقه هم از داخل منوی کارت وضعیت و هم با کلیک‌راست روی آیکون Tray.
- 📢 **بنر شناور مدرن (OSD HUD Banner):** به محض فشردن کلیدهای میانبر، یک اعلان زیبا و نیمه‌شفاف در پایین صفحه وضعیت را بدون برهم زدن فوکوس به کاربر نشان می‌دهد.
- 🌙 **آیکون کنار ساعت (System Tray):**
  - حالت غیرفعال: آیکون ماه طوسی (Standby).
  - حالت فعال: آیکون ماه فیروزه‌ای درخشان همراه با نمایش دقایق باقیمانده در تولتیپ.
  - با کلیک روی آیکون یا دابل‌کلیک، پنجره وضعیت باز می‌شود.
- 🔍 **ادغام کامل با جستجوی Start Menu:** با تایپ `Auto Hibernate` در استارت منوی ویندوز ۱۱ برنامه بلافاصله ظاهر شده و قابل اجراست.
- 🛑 **دکمه Hibernate Now:** امکان هایبرنیت فوری دستی در هر لحظه با یک کلیک.
- 🚀 **استارتاپ خودکار و سبک:** با راه‌اندازی ویندوز به صورت خودکار و بسیار سبک در پس‌زمینه لود می‌شود بدون اینکه منابع سیستم را مصرف کند.

---

## 🛠️ Architecture & How It Works

- **Native Win32 Message Loop:** Uses `System.Windows.Forms.NativeWindow` with `RegisterHotKey` for zero-latency hotkey interception without WinForms form lifecycle interference or Asus Zenbook `AltGr` conflicts.
- **Hardware Idle Detection:** Interrogates Win32 `GetLastInputInfo` to measure physical keyboard and mouse activity independently of media state or power assertion flags.
- **Power Management Hooks:** Subscribes to `Microsoft.Win32.SystemEvents.PowerModeChanged` and UTC clock delta checks to detect manual suspend/resume cycles, automatically disarming the timer upon wake.
- **IPC Architecture:** Uses named Win32 EventWaitHandles (`AutoHibernate_Start_Event`, `AutoHibernate_Stop_Event`, `AutoHibernate_Status_Event`) and a single-instance Mutex for instant inter-process communication.
- **Silent WScript Host:** All launchers wrap background processes using `wscript.exe` with `SW_HIDE` (`0, False`) to prevent `WindowsTerminal.exe` from opening tabs.

---

## 🚀 Installation (نصب)

### One-line Install (PowerShell):
In the project directory, run:
```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

### Uninstallation (حذف):
```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

---

## 📜 License
MIT License © 2026 RMNO21
