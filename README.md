# تطبيق تجارتي للهاتف (Tijarti Mobile) — Android APK CI/CD

تطبيق أندرويد متكامل مبني باستخدام **Flutter & Dart**، مخصص لسوق وتجارة إلكترونية عربية (RTL).

---

## 🚀 البناء التلقائي لملف APK عبر GitHub Actions Workflow

تم إعداد Workflow مخصص في المسار `.github/workflows/build-apk.yml` لبناء ملف الـ **APK** تلقائياً عبر GitHub Actions.

### ⚙️ متى يتم تشغيل الـ Workflow؟
1. **تلقائياً عند الدفع (Push):** عند إرسال أي تغييرات لفرع `main` أو فروع العمل `arena/**`.
2. **عند طلبات السحب (Pull Requests):** لاختبار وضمان سلامة البناء قبل الدمج في `main`.
3. **يدوياً من خلال GitHub (Manual Run):**
   - افتح تبويب **Actions** في مستودع GitHub.
   - اختر **Build Android APK** من القائمة اليسرى.
   - اضغط على **Run workflow**.
   - يمكنك تحديد خيارات البناء:
     - **نوع النسخة (Build Type):** `release` (افتراضي) أو `debug`.
     - **تقسيم بحسب المعمارية (Split per ABI):** تفعيل أو تعطيل.
4. **تلقائياً عند إنشاء Release Tag:** عند إطلاق وسم يبدأ بـ `v*` (مثل `v1.0.0`)، يتم إنشاء Release رسمي على GitHub وإرفاق ملفات الـ APK تلقائياً.

---

## 📥 كيفية تنزيل ملف الـ APK بعد انتهاء البناء

1. ادخل إلى تبويب **Actions** في المستودع.
2. اضغط على أحدث تشغيل للـ Workflow (Run).
3. انزل لأسفل الصفحة إلى قسم **Artifacts**.
4. اضغط على **`tijarti-apk-release`** (أو `tijarti-apk-debug`) لتنزيل ملف الـ APK بصيغة مضغوطة وفك الضغط لتثبيته مباشرة على جهاز الأندرويد.

---

## 🛠️ تفاصيل بيئة البناء في الـ Workflow

- **نظام التشغيل:** Ubuntu Latest (GitHub-hosted runner).
- **إصدار Java:** JDK 17 (Eclipse Temurin).
- **محرك وإطار العمل:** Flutter SDK (Stable Channel).
- **التوافق:** يكتشف الـ Workflow مسار المشروع تلقائياً سواء كان في المجلد الرئيسي أو داخل مجلد `mobile/` أو مستخرجاً من أرشيف zip.
- **إدارة الذاكرة:** يضبط حجم ذاكرة Gradle بما يتوافق مع بيئة GitHub Actions (3GB heap) لتفادي أخطاء الذاكرة (Out of Memory).

---

## 💻 التشغيل والتطوير محلياً (Local Development)

```bash
# الانتقال لمجلد التطبيق
cd mobile

# تنزيل حزم ومكتبات فلاتر
flutter pub get

# فحص جودة الكود
flutter analyze

# تشغيل الاختبارات
flutter test

# بناء APK للإنتاج محلياً
flutter build apk --release
```

لتحديد رابط API مختلف عند التشغيل:
```bash
flutter run --dart-define=API_BASE_URL=https://example.com/s_api/api/v1
```
