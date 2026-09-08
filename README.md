# 🌙 Auto Hibernate (Sleep & Hibernate Timer for Windows 11)

> **Smart, on-demand sleep/hibernate timer utility designed specifically for OLED laptops (like ASUS Zenbook) and Windows 11.**  
> Automatically hibernates the PC after a configurable idle period, strictly resets on real physical mouse/keyboard activity, and operates 100% silently with zero terminal flash.

---

## 📖 Overview (فارسی / Persian)

برنامه **Auto Hibernate** یک ابزار هوشمند، بسیار سبک و اختصاصی برای ویندوز ۱۱ است که به عنوان تایمر هایبرنیت/اسلیپ (Sleep Timer) بدون نیاز به تعریف کلیدهای میانبر سیستمی، به ساده‌ترین شکل از طریق استارت منو و منوی کنار ساعت (System Tray) کنترل می‌شود.

### چرا این برنامه ساخته شد؟
1. **جلوگیری از OLED Burn-in:** در لپ‌تاپ‌های دارای صفحه نمایش OLED (مانند ASUS Zenbook 14 OLED UX3405)، روشن ماندن طولانی صفحه می‌تواند باعث سوختگی پیکسل‌ها شود.
2. **مشکلات Modern Standby (S0 Low Power Idle):** در لپ‌تاپ‌های مدرن، حالت اسلیپ معمولی ویندوز اغلب لپ‌تاپ را به دلیل دانلودها، برنامه‌ها، استریم صدا یا پردازش‌های پس‌زمینه بیدار و داغ نگه می‌دارد. این برنامه با **Hibernate واقعی (`shutdown /h /f`)** دستگاه را کاملاً خاموش و امن می‌کند.
3. **ریست فقط با ورودی فیزیکی:** تایمر فقط با حرکت واقعی ماوس یا فشردن کلیدهای کیبورد ریست می‌شود. پخش ویدیو، صدای پس‌زمینه، یوتیوب، مرورگرها یا ابزارهایی مثل PowerToys Awake مانع هایبرنیت نمی‌شوند.
4. **ایزوله‌سازی سشن (Session-Only):** اگر خودتان لپ‌تاپ را دستی خاموش، هایبرنیت یا اسلیپ کنید، پس از روشن شدن مجدد، تایمر به هیچ عنوان دوباره راه نمی‌افتد و همیشه در حالت خاموش (Standby) منتظر فرمان شماست.
5. **کاملاً بی‌صدا (Zero Console Windows):** هیچ پنجره سیاه ترمینالی در ویندوز ۱۱ باز یا بسته نمی‌شود.

---

## 🖥️ روش استفاده (How to Use)

1. **جستجو در استارت منو:**
   - کافیست کلید `Windows` را بزنید و تایپ کنید: **`Auto Hibernate`**.
   - برنامه باز شده و کارت شیک وضعیت را به همراه شمارش معکوس زنده و کلیدهای کنترل نمایش می‌دهد.

2. **کارت گرافیکی وضعیت (Status Card):**
   - **Status Badge:** وضعیت زنده برنامه (`● ACTIVE` یا `○ DISABLED (STANDBY)`).
   - **Countdown:** شمارش معکوس دیجیتال بزرگ و دقیق.
   - **Timeout Dropdown:** منوی انتخاب زمان (۱۰، ۱۵، ۲۰، ۳۰، ۴۵، ۶۰، ۹۰ یا ۱۲۰ دقیقه).
   - **Start Timer / Turn Off:** دکمه شروع یا توقف فوری تایمر.
   - **Hibernate Now:** دکمه هایبرنیت فوری دستی.
   - **Hide to Tray:** بستن پنجره و انتقال به آیکون کنار ساعت بدون خروج از برنامه.

3. **آیکون کنار ساعت (System Tray):**
   - **حالت فعال:** آیکون ماه فیروزه‌ای درخشان با نمایش زمان باقیمانده در تولتیپ.
   - **حالت غیرفعال:** آیکون ماه طوسی (Standby).
   - با کلیک چپ یا دابل‌کلیک، پنجره وضعیت باز می‌شود.
   - با کلیک راست، منویی با گزینه‌های وضعیت زنده، تغییر سریع زمان (`Idle Timeout`)، فعال/غیرفعال‌سازی، Hibernate Now و خروج ظاهر می‌شود.

---

## ✨ Features (امکانات و ویژگی‌ها)

- ⏱ **شمارش معکوس زنده:** نمایش زمان باقیمانده به صورت دیجیتال در پنجره وضعیت و آیکون کنار ساعت.
- 🎛 **انتخاب سریع زمان:** تنظیم مدت زمان عدم فعالیت (از ۱۰ دقیقه تا ۲ ساعت).
- 📢 **اعلان‌های هوشمند (OSD Banner):** نمایش پیام شیک در گوشه صفحه هنگام شروع یا خاموش شدن تایمر.
- 🛑 **Hibernate Now:** امکان هایبرنیت فوری سیستم در هر لحظه.
- 🚀 **استارتاپ خودکار و سبک:** با بالا آمدن ویندوز در پس‌زمینه آماده کار قرار می‌گیرد بدون اشغال منابع سیستم.
- 🛡️ **بدون اشغال کلیدهای میانبر:** هیچ تداخلی با کلیدهای کیبورد یا نرم‌افزارهای لپ‌تاپ ایجاد نمی‌کند.

---

## 🛠️ Architecture & Technical Details

- **Hardware Idle Detection:** Interrogates Win32 `GetLastInputInfo` to measure physical keyboard and mouse activity independently of media state or power assertion flags.
- **Power Management Hooks:** Subscribes to `Microsoft.Win32.SystemEvents.PowerModeChanged` and UTC clock delta checks to detect manual suspend/resume cycles, automatically disarming the timer upon wake.
- **IPC Architecture:** Uses named Win32 EventWaitHandles (`AutoHibernate_Start_Event`, `AutoHibernate_Stop_Event`, `AutoHibernate_Status_Event`) and a single-instance Mutex for instant inter-process communication.
- **Silent WScript Host:** All background processes use `wscript.exe` with `SW_HIDE` (`0, False`) to guarantee no `WindowsTerminal.exe` tabs pop up.

---

## 🚀 Installation (نصب)

### One-line Install (PowerShell):
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
