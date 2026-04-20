# 📋 PROGRESS — SIMIN-INTEL (Sistem Monitoring Intelijen)

> File ini dipakai untuk **melacak progress antar sesi Claude Code**.
> Update di awal & akhir tiap sesi supaya konteks tidak hilang saat token habis.

---

## 🔵 FASE J — Sesi 1 (J-1 + J-2): Unify Schema + Full-content Scraping

**Tanggal:** 2026-04-17 · **Status:** ✅ Selesai · **Build:** OK · **Lint:** clean

### Konsep baru yang berlaku mulai FASE J:

| Konsep Lama | Konsep Baru |
|-------------|-------------|
| LAPIN / Laporan Lapangan | **Laporan Informasi** |
| Field Report | Laporan Informasi (manual) |
| ChamberItem dari scraping | Laporan Informasi (S) — label "(S)" |
| Callsign `LAP-20260415-A1B2` | **`0001/LI/JAWA_TIMUR/IV/2026`** |
| URL: `/field-report` | URL: `/laporan-informasi` (redirect lama tetap jalan) |

### ✅ J-1a — Migrasi DB Unified Schema
**File:** `database/migrations/2026_04_15_200001_unify_laporan_informasi_schema.php`
- Tambah kolom `chamber_items`: `author`, `published_at`, `content_preview`, `tags`, `category_scores`, `reporter_name`, `scraped_at`
- Tambah kolom `scraper_sources`: `interval_minutes`, `keyword_include`, `keyword_exclude`, `url_whitelist`, `url_blacklist`, `rate_limit_seconds`, `priority_score`, `user_agent`, `domain_target`
- Semua pakai `hasColumn()` guard — aman dijalankan ulang

### ✅ J-1b — Model ChamberItem
**File:** `app/Models/ChamberItem.php` (rewrite)
- Tambah semua field baru ke `$fillable` + `$casts`
- **Callsign generator baru:** `ChamberItem::generateCallsign(?string $province)`
  - Format: `0001/LI/JAWA_TIMUR/IV/2026`
  - Sequence per bulan per provinsi
  - Auto-fallback ke `NASIONAL` jika provinsi kosong
- Accessor baru: `source_label_attribute` (return "Laporan Informasi" / "Laporan Informasi (S)"), `is_scraped_attribute`
- Scopes: `manual()`, `scraping()`, `pending()`, `showcase()`

### ✅ J-1c — FieldReportController
**File:** `app/Http/Controllers/FieldReportController.php` (rewrite)
- `index()`: render `LaporanInformasi` + kirim `scraperSources` sebagai props
- `store()`: pakai callsign baru, simpan field baru (author, source, url, published_at, tags, content_preview)
- Tambah CRUD scraper: `storeScraper()`, `updateScraper()`, `destroyScraper()`, `toggleScraper()`

### ✅ J-1d — Routes + Vue Page
**Files:** `routes/web.php`, `resources/js/Pages/LaporanInformasi.vue` (NEW), `resources/js/Layouts/AppLayout.vue`
- Route baru: `GET /laporan-informasi`, `POST /api/laporan-informasi`, `POST /api/laporan-informasi/parse-document`
- Route CRUD scraper: `POST/PATCH/DELETE/POST /api/scraper-sources/{id}/toggle`
- Redirect `/field-report` → `/laporan-informasi` (backward compat)
- `LaporanInformasi.vue`: **split layout** — kiri form manual lengkap, kanan panel konfigurasi scraping
  - Form manual: semua field unified (judul, domain, pelapor, author, sumber, url, tanggal kejadian, tanggal publikasi, tags, fakta, narasi, lokasi 38 provinsi terbaru, aktor, korban, Admiralty matrix 6x6 interaktif, Prunckun, lampiran)
  - Panel kanan: CRUD sumber scraping (nama, URL, interval, keyword include/exclude, domain target, prioritas, rate limit), toggle on/off, telemetri last run
- AppLayout navbar: "LAPORAN" klik → `/laporan-informasi`

### ✅ J-2a — ScraperSource Model
**File:** `app/Models/ScraperSource.php`
- Tambah semua field baru ke `$fillable` + `$casts`
- Method `passesKeywordFilter(string $title)`: cek include/exclude keywords
- Method `passesUrlFilter(string $url)`: cek whitelist/blacklist patterns

### ✅ J-2b — AI Service Full-content Extraction
**File:** `ai-service/scraper/scraper.py` (rewrite), `ai-service/requirements.txt`
- Tambah `trafilatura` + `lxml` ke requirements
- Install di container: `pip install trafilatura lxml` → v2.0.0 ✓
- Strategy ekstraksi 3-layer:
  1. **trafilatura** (primary) — otomatis ekstrak body article, hapus boilerplate
  2. **BS4 per-media selector** (fallback) — jika trafilatura konten < 100 char
  3. **Merge** — trafilatura menang di konten panjang, BS4 menang di metadata terstruktur
- Output tambah: `published_at` (ISO 8601), `content` (full), `content_preview` (300 char)
- Deteksi 12 media Indonesia (sebelumnya 6)
- `main.py` `/analyze` endpoint: return semua field baru

### ✅ J-2c — ScrapeAndAnalyzeJob
**File:** `app/Jobs/ScrapeAndAnalyzeJob.php` (rewrite)
- Tambah konstruktor parameter `$forcedDomain` (dari `ScraperSource.domain_target`)
- Map semua field baru ke payload: `author`, `published_at`, `content`, `content_preview`, `tags`, `category_scores`
- `ScrapeNewsCommand`: teruskan `domain_target` ke Job, implementasi keyword/URL filter, rate-limit antar dispatch

### Test Results
```
✅ PHP lint 5 file: clean
✅ Vue build: sukses (LaporanInformasi-*.js terkompilasi)
✅ Route: /laporan-informasi, /api/laporan-informasi, /api/scraper-sources/* registered
✅ Callsign: 0002/LI/JAWA_TIMUR/IV/2026 format benar
✅ trafilatura v2.0.0 installed di container
✅ Scraper test Antara News: content_len=2624 char (sebelumnya hanya judul)
✅ Redirect /field-report → /laporan-informasi: aktif
```

---

## 🔵 FASE J — Sesi 2 (J-3 + J-4): Chamber Edit-Everything + Showcase Modal

**Tanggal:** 2026-04-17 · **Status:** ✅ Selesai · **Build:** OK · **Lint:** clean

### ✅ J-3a — ChamberController::update() expanded
**File:** `app/Http/Controllers/ChamberController.php`
- Validasi + simpan semua field unified: title, source, author, url, incident_date, published_at, tags, reporter_name, source_credibility, content, content_preview, report_lead, facts, raw_domain, ai_domain_suggestion, locations, actors, victims_count, victims_list, admiralty_reliability, admiralty_validity, prunckun_capability, prunckun_intent, prunckun_opportunity
- Auto-recalculate `prunckun_score` + `threat_level` jika dim berubah
- Auto-update `title_hash` jika title berubah
- Auto-generate `content_preview` jika content berubah

### ✅ J-3b — Chamber.vue redesign (edit-everything panel)
**File:** `resources/js/Pages/Chamber.vue` (rewrite, ~1000 baris)
- Kolom CALLSIGN di tabel tampilkan badge "SCRAPING" / "MANUAL" via `source_label`
- Panel detail kanan diperlebar ke 520px dengan **7 section collapsible**:
  1. **IDENTITAS** — title (textarea), source, author (2 kolom), URL (+ tombol buka), tgl kejadian, tgl publikasi (2 kolom), pelapor, kredibilitas sumber (select 1-5)
  2. **KONTEN** — lead/ringkasan, fakta editable (add/remove per item), narasi textarea, tags (chip input enter-to-add/remove)
  3. **LAMPIRAN** — grid preview images + dokumen (collapsible, read-only)
  4. **KLASIFIKASI** — domain select (+ tampil rekomendasi AI + 1-click adopt), lokasi 38 provinsi (chip add/remove via dropdown), aktor (list editable + form add nama/peran/afiliasi), jumlah korban (number)
  5. **ADMIRALTY CODE** — matrix 6×6 interaktif (klik pilih sel), deskripsi reliabilitas + validitas
  6. **PRUNCKUN** — 3 slider C/I/O (1-5), live preview score + TL badge, legend TL1-TL5
  7. **CATATAN ANALIS** — always visible textarea
- `selectItem()` mengisi semua field edit dari item (deep copy arrays, tanggal ke YYYY-MM-DD)
- `saveItem()` / `_patchItem()` — PATCH dengan semua field termasuk arrays
- Re-analyze: setelah AI selesai, `selectItem()` dipanggil ulang untuk refresh semua form field

### ✅ J-4a+J-4b — ChamberController::showcase() + caseRecommendations()
**File:** `app/Http/Controllers/ChamberController.php`
- `showcase()`: wajib `case_id` ATAU `create_case=true + case_title + case_domain` — 422 jika keduanya absen
- `caseRecommendations()`: ranking multi-faktor (domain +30, lokasi +20/match, aktor +10/match, active +5)

### ✅ J-4c — Chamber.vue Showcase Modal
**File:** `resources/js/Pages/Chamber.vue`
- Tombol ETALASE → `openShowcaseModal()` (bukan langsung POST)
- `openShowcaseModal()`: auto-save dulu, fetch `/api/chamber/{id}/case-recommendations`, prefill `newCaseDraft` dari item
- **Modal** (max-w-2xl, max-h-90vh, Teleport ke body):
  - Header: callsign + judul item terpotong
  - Toggle tab: "Kaitkan ke Kasus Existing" vs "Buat Kasus Baru"
  - **Tab Existing**: daftar semua kasus diurutkan `relevance_score`, tiap card tampilkan:
    - Relevance badge (lingkaran berwarna, hijau ≥50 / kuning ≥25 / abu)
    - Title, domain badge (warna), status badge (AKTIF/TUTUP)
    - Lokasi (`locations[]`) hingga 4 provinsi
    - `article_count`, `avg_threat_level`
    - Centang pilihan (✓ hijau)
  - **Tab Buat Baru**: form judul*, domain*, deskripsi opsional (prefilled dari item)
  - Footer: validasi status teks, tombol BATAL + KONFIRMASI ETALASE (disabled sampai pilihan valid)
- `confirmShowcase()`: auto-save → POST showcase dengan `{case_id}` atau `{create_case, case_title, case_domain, case_description}` → update local state + stats
- ESC menutup modal dulu, baru detail panel, baru lightbox

### Test Results
```
✅ PHP artisan route:list /api/chamber: 8 routes registered (update/showcase/trash/archive/reanalyze/bulk-action/caseRecommendations/destroy)
✅ Vue build: sukses — Chamber-*.js 53.76 kB (gzip 14.05 kB), zero errors
✅ Semua field validated: integer source_credibility (select 1-5), locations array, actors array
✅ CaseFile.locations (bukan provinces) + article_count (bukan articles_count) + avg_threat_level: field names benar
```

### Sesi Selanjutnya: J-7 (theme sepia)

---

## 🔵 FASE J — Sesi 3 (J-6): Kasus ↔ Wilayah Risk Engine

**Tanggal:** 2026-04-17 · **Status:** ✅ Selesai · **Build:** OK · **Lint:** clean

### Konsep Baru (J-6)
- `risk_score` wilayah = **Σ(avg_threat_level)** semua kasus aktif/paused di provinsi tsb
- Tidak ada ×article_count — murni dari kasus
- Threshold baru: **kritis≥20, tinggi≥10, sedang≥5, rendah>0**
- Hubungan Kasus ↔ Wilayah: bukan pivot eksplisit — diderivasikan dari `CaseFile.primary_province` + `CaseFile.locations[]` (JSON array yang sudah ada)

### ✅ J-6a — Migration: cases_count ke tabel locations
**File:** `database/migrations/2026_04_17_100001_add_cases_count_to_locations_table.php`
- Tambah kolom `cases_count` (unsignedInteger, default 0)
- Ran: 31.25ms DONE

### ✅ J-6b — Location model (rewrite)
**File:** `app/Models/Location.php`
- Tambah `cases_count` ke fillable + casts
- NEW: `static recalculateForProvince(string $province)`:
  - Query kasus aktif/paused yang menyertakan provinsi via `primary_province` OR `whereJsonContains('locations', $province)`
  - `risk_score = Σ avg_threat_level`
  - `cases_count` = jumlah kasus aktif di provinsi
  - `article_count` tetap diupdate dari Article showcase (informatif)
  - `category_breakdown` = domain kasus (bukan artikel)
  - Threshold baru untuk `risk_level`
  - Trigger `AlertService::checkRiskSpike()` untuk notifikasi lonjakan
- NEW: `static recalculateAll()` — iterasi semua provinsi dari primary_province + locations[] semua kasus

### ✅ J-6c — CaseFile model: sync ke Location setelah recalculate
**File:** `app/Models/CaseFile.php`
- Tambah `use Illuminate\Support\Facades\Log`
- Setelah `$this->update($update)` di `recalculateMetrics()` → panggil `$this->syncProvinceRisk()`
- NEW: `syncProvinceRisk()` — iterasi semua provinsi dari `primary_province` + `locations[]`, call `Location::recalculateForProvince($prov)` untuk masing-masing

### ✅ J-6d — ChamberController::updateLocationsAggregate() simplified
**File:** `app/Http/Controllers/ChamberController.php`
- Method dikecilkan dari ~50 baris menjadi ~12 baris
- Semua logika kalkulasi dipindah ke `Location::recalculateForProvince()`
- Tinggal iterate article.locations → call `Location::recalculateForProvince($province)`

### ✅ J-6e — MapController updates
**File:** `app/Http/Controllers/MapController.php`
- `getFilteredData()`: Map coloring SELALU case-based dari tabel locations (tidak difilter waktu/kategori). Filter waktu/kategori hanya berlaku untuk stats artikel / Live Feed sidebar
- `index()`: tambah `total_cases` ke stats
- Koordinat: tambah alias `'Kepulauan Bangka Belitung'` (sebelumnya hanya `'Bangka Belitung'`)

### ✅ J-6f — Map.vue updates
**File:** `resources/js/Pages/Map.vue`
- `getColor()` threshold diubah: 75/50/25 → **20/10/5** sesuai Σ avg_threat_level scale
- Legend "Risk Score" → "Bobot Wilayah" + subtitle "Σ avg_threat_level kasus aktif"
- Legend labels: KRITIS≥20, TINGGI≥10, SEDANG≥5, RENDAH>0, BELUM ADA KASUS
- Popup: tambil "Bobot: X (Σ TL kasus)", "Kasus Aktif: N", "Artikel: N"
- Hover info: "Bobot: X | Kasus: N | TINGGI"
- Top Wilayah list: tampilkan ⭐N (kasus) 📰N (artikel) instead of just artikel count

### ✅ J-6g — Artisan Command: osint:recalc-risk
**File:** `app/Console/Commands/RecalcLocationRiskCommand.php`
- `php artisan osint:recalc-risk` — recalculate semua wilayah
- `php artisan osint:recalc-risk --province="Jawa Barat"` — recalculate satu provinsi
- Output tabel top 10 wilayah dengan risk_score

### Test Results
```
✅ php artisan migrate: cases_count column added — 31.25ms DONE
✅ Location::recalculateAll(): 24 provinces processed, no errors
✅ CaseFile::syncProvinceRisk(): method_exists = true
✅ php artisan osint:recalc-risk: runs clean, shows top 10 table
✅ Vue build: 0 errors — Map.js 29.23 kB (gzip 8.31 kB)
```

### Data Flow (J-6 Final)
```
ChamberItem (ETALASE)
  → showcase()
    → promoteToArticle()
    → case->articles()->syncWithoutDetaching()
    → case->recalculateMetrics()           ← updates avg_threat_level
      → case->syncProvinceRisk()           ← NEW
        → Location::recalculateForProvince() per provinsi
          → risk_score = Σ avg_threat_level kasus aktif
          → AlertService::checkRiskSpike()
    → updateLocationsAggregate(article)    ← simplified
      → Location::recalculateForProvince() per provinsi artikel
```

### Sesi Selanjutnya: J-7 (theme cerah + hemat mata sepia)

---

## 🗂️ Struktur Folder

```
E:\Dashboard Monitoring Sintra\
├── platform-main\      ← Laravel 12 + Inertia + Vue 3 (backend & UI)
├── ai-service\         ← FastAPI Python (Claude AI, scraper, Telegram)
└── PROGRESS.md         ← FILE INI
```

## 🚀 Cara menjalankan sistem

```bat
cd "E:\Dashboard Monitoring Sintra\platform-main"
docker compose up -d
```
Buka browser: http://localhost:8000

## 🛑 Cara mematikan

```bat
cd "E:\Dashboard Monitoring Sintra\platform-main"
docker compose down
```

---

## 🎯 ROADMAP — Rencana Fase Besar

| Fase | Topik | Status |
|------|-------|--------|
| **A** | Database restructure (Admiralty + Case + Prunckun C×I×O) | ✅ **SELESAI & migrated** |
| **B** | Input LAPIN: form + docx/pdf upload + gambar | ✅ **SELESAI** |
| **C** | Chamber: matrix Admiralty A1-F6 + 3 tombol aksi | ✅ **SELESAI** |
| **D** | Kasus: Six-Pointed Star (5W+1H) + Timeline | ✅ **SELESAI** |
| **E** | Peta: Kasus per provinsi terintegrasi | ✅ **SELESAI** |
| **F** | Analisis bertingkat (per-kasus, per-region, per-aktor) | ✅ **SELESAI** |
| **G** | Adaptasi 3 script scraping (EVO 2, EVO 7.1, Tweet Harvest v2) | ⏸ menunggu |

---

## ✅ FASE A — Database Restructure (15 April 2026)

### Keputusan Utama
- **Pilihan B: Reset Bersih** — semua data lama dihapus (TRUNCATE)
- Formula Prunckun diubah: **Capability × Intent × Opportunity** (range 1–125)
- Rename `motif` → `intent`
- Event → Kasus (class `CaseFile` karena `case` reserved word PHP)

### Threshold Threat Level (score 1-125)
| Score | Threat Level | Label |
|-------|--------------|-------|
| 76-125 | 5 | Tinggi (Critical) |
| 50-75  | 4 | Sedang-Atas |
| 26-49  | 3 | Sedang (Moderate) |
| 11-25  | 2 | Rendah-Atas |
| 1-10   | 1 | Rendah (Negligible) |

### File yang Dibuat
- `database/migrations/2026_04_14_000001_restructure_for_admiralty_and_cases.php`
- `database/migrations/2026_04_14_000002_create_cases_and_attachments_tables.php`
- `app/Models/CaseFile.php` (tabel `cases`)
- `app/Models/Attachment.php` (polymorphic)

### File yang Diubah
**Backend (Laravel):**
- `app/Models/Article.php` — tambah admiralty, data_status, case profile, relasi cases & attachments
- `app/Models/ChamberItem.php` — tambah admiralty, data_status, prunckun_intent
- `app/Http/Controllers/ChamberController.php` — 3 tombol aksi (trash/archive/showcase), formula C×I×O
- `app/Http/Controllers/FieldReportController.php` — formula C×I×O, callsign LAP-, admiralty default
- `app/Http/Controllers/AnalisisController.php`, `DomainController.php`, `EventController.php`, `EarlyWarningPageController.php`, `Api/ArticleController.php` — rename kolom
- `app/Jobs/ScrapeAndAnalyzeJob.php` — map `intent` dari AI
- `routes/web.php` — tambah route `/api/chamber/{id}/{showcase|archive|trash}`

**Frontend (Vue):**
- `Chamber.vue`, `FieldReport.vue`, `Analisis.vue`, `EarlyWarning.vue`, `Domain.vue`, `Map.vue` — ganti tampilan formula `M×C×O` → `C×I×O`, variabel `editMotif` → `editIntent`, label "Motif" → "Intent / Niat"

**AI Service (Python):**
- `ai-service/nlp/classifier.py` — `calculate_prunckun()` formula C×I×O (1-125), prompt Claude pakai istilah Intent
- `ai-service/README.md` — contoh response update

**File yang Dihapus:**
- `app/Models/Event.php` (digantikan `CaseFile.php`)

### ⚠️ LANGKAH TERAKHIR — Jalankan Migrasi
Docker Desktop harus ON dulu. Lalu:

```bat
cd "E:\Dashboard Monitoring Sintra\platform-main"
docker compose up -d
docker exec osint_app php artisan migrate --force
```

**Output yang diharapkan:**
```
Migrating: 2026_04_14_000001_restructure_for_admiralty_and_cases
Migrated:  2026_04_14_000001_restructure_for_admiralty_and_cases
Migrating: 2026_04_14_000002_create_cases_and_attachments_tables
Migrated:  2026_04_14_000002_create_cases_and_attachments_tables
```

**Verifikasi tabel baru:**
```bat
docker exec osint_app php artisan tinker --execute="echo \Schema::hasTable('cases') ? 'OK cases' : 'MISSING'; echo PHP_EOL;"
```

### ⚠️ Catatan Route yang Mungkin Error
Route `/peristiwa` dan `/api/events/*` masih ada di `routes/web.php` tapi tabel `events` sudah di-drop. Jangan akses halaman `/peristiwa` sampai **FASE D** (Kasus UI) selesai. Alternatif cepat: bisa di-comment nanti kalau mengganggu.

---

## 📁 Referensi Konsep

### Admiralty Code (NATO STANAG 2022)
- **Reliability (huruf):** A = Completely reliable ... F = Cannot be judged
- **Validity (angka):**    1 = Confirmed ... 6 = Cannot be judged
- Contoh code: `B2` = Usually reliable + Probably true

### Prunckun Threat Equation
- **C (Capability)** 1-5 — seberapa mampu aktor
- **I (Intent)**     1-5 — seberapa kuat niat / motivasi
- **O (Opportunity)** 1-5 — seberapa besar peluang
- Score = C × I × O (1–125)

### Six-Pointed Star (5W+1H) untuk Kasus
- Apa / Siapa / Di mana / Kapan / Kenapa / Bagaimana

### Data Status (siklus hidup data)
- `pending` — masih di Chamber, menunggu review
- `trash` — dibuang
- `archive` — simpan tapi tidak di etalase
- `showcase` — tampil di dashboard

### Callsign
- `KSS-YYYYMMDD-XXXX` = Kasus
- `LAP-YYYYMMDD-XXXX` = Laporan Lapangan
- `CHM-YYYYMMDD-XXXX` = Chamber (hasil scraping)

---

---

## ✅ FASE B — Input LAPIN (15 April 2026)

### Library yang Diinstal
- `phpoffice/phpword` ^1.1 — parse .docx / .doc
- `smalot/pdfparser`  ^2.12 — parse .pdf

### Service Baru
- `app/Services/DocumentParserService.php` — extract teks dari pdf/docx/txt → split jadi Lead + Facts (bullet array)

### Controller Baru
- `app/Http/Controllers/AttachmentController.php`
   - `POST /api/attachments/temp` — upload sementara (dipakai form LAPIN sebelum submit)
   - `POST /api/attachments` — upload langsung ke model (chamber_item/article/case)
   - `DELETE /api/attachments/{id}` — hapus

### Controller Update
- `FieldReportController`:
   - `POST /api/field-report/parse-document` — ekstrak teks dari docx/pdf, return lead + facts + fullText
   - `POST /api/field-report` — sekarang terima field `report_lead`, `facts[]`, `admiralty_*`, `victims_list`, dan array `temp_attachments` untuk claim

### Frontend
- `resources/js/Pages/FieldReport.vue` — **redesign total** jadi 9 section:
   1. Metadata (judul, domain, tanggal, pelapor)
   2. Upload Dokumen (auto-fill Lead + Facts)
   3. Report Lead (2-3 kalimat arahan)
   4. Facts (array bullet, add/remove)
   5. Narasi lengkap
   6. Lokasi + Aktor + Korban
   7. Admiralty Code (dual selector A-F × 1-6, dengan deskripsi hover)
   8. Prunckun Score (C × I × O = 1-125 dengan color-coded threat level)
   9. Foto / Gambar multiple upload + caption per gambar

### Lainnya
- `php artisan storage:link` → `public/storage` → `storage/app/public`
- `npm run build` — ✅ sukses
- 5 route baru terdaftar di `php artisan route:list`

### Catatan / Deferred
- **Image annotation editor** (coret/lingkari di gambar) belum diimplementasikan. Upload + caption sudah cukup untuk MVP. Editor annotasi bisa jadi sub-fase FASE B.2 pakai library seperti `tldraw` atau `fabric.js`.
- Endpoint `/api/attachments` langsung dipakai di FASE C (Chamber & Kasus bisa attach file langsung).

---

## ✅ FASE C — Chamber Redesign (15 April 2026)

### Tujuan
Halaman Chamber jadi "ruang verifikasi" analis: lihat artikel scraping, beri skor Admiralty + Prunckun, lalu pilih 1 dari 3 tombol aksi.

### Backend
- `app/Http/Controllers/ChamberController@index` — diperluas dengan filter & sort:
   - `data_status`, `domain`, `threat_level`, `admiralty_reliability`, `search`, `sort_by`, `sort_dir`
   - Eager-load `attachments` polymorphic
   - Return `stats` (total/pending/trash/archive/showcase) untuk badge button
- `app/Models/Attachment.php` — tambah `$appends = ['url']` supaya URL ikut serialize ke JSON (carousel & download butuh ini)

### Frontend — `resources/js/Pages/Chamber.vue` (full rewrite, ~460 lines)
**Layout 2 panel:**
- **Kiri:** Filter bar + tabel daftar
   - Status pills: Semua / Pending / Trash / Arsip / Etalase (badge count)
   - Filter dropdown: Domain, Threat Level, Reliability (A-F button row), Search judul/callsign
   - Tabel kolom: CALLSIGN / JUDUL / DOMAIN / ADM / C×I×O / TL / STATUS / 📎 (jumlah attachment)
- **Kanan (460px):** Detail panel
   - Callsign + tombol close (Esc juga close)
   - Judul, Report Lead, Facts (bullet list), Content
   - **Attachment grid** — gambar klik → lightbox; dokumen tampil sebagai card download
   - Domain select
   - **Matrix Admiralty 6×6** A-F × 1-6 dengan warna gradien hijau→merah (fungsi `getAdmiraltyColor(r,v)`), klik sel = set reliability+validity, hover = tooltip deskripsi
   - **Prunckun sliders** C / I / O (1-5) → preview score live + threat level color-coded
   - Lokasi, Aktor, Notes
   - **3 tombol aksi besar:** 🗑 Sampah (merah) / 🗄 Arsip (kuning) / ✅ Etalase (hijau)

**Interaksi:**
- Klik tombol aksi → `actionItem(action)` save dulu lalu POST `/api/chamber/{id}/{trash|archive|showcase}` → toast notifikasi
- Filter pakai Inertia `router.get` dengan `preserveScroll`, `preserveState`, `replace: true`
- Lightbox overlay untuk preview gambar full-size
- Toast top-right untuk feedback aksi

### Build & Test
```bat
docker exec osint_app npm run build
```
(belum dijalankan di sesi ini karena Docker Desktop off — jalankan setelah docker nyala)

### Catatan
- Endpoint `/api/chamber/{id}/{showcase|archive|trash}` sudah dibuat di FASE A.
- ChamberItem yang sudah pernah di-archive/showcase otomatis bikin record `Article` (lihat `promoteToArticle()`).
- Kalau threat_level Article ≥ 4, otomatis `TelegramService::notifyThreat()` (juga sudah ready).

---

## ✅ FASE D — Kasus / Six-Pointed Star (15 April 2026)

### Tujuan
Halaman **Kasus** = wadah investigasi multi-artikel. Analis bisa menarik artikel showcase ke 1 kasus, isi profil 5W+1H, lihat timeline kronologi, upload file pendukung, dan agregat skor Prunckun otomatis.

### Backend
- `app/Http/Controllers/CaseController.php` (BARU) — CRUD kasus + relasi:
   - `GET /kasus`                            → halaman utama (list + filter)
   - `POST /api/cases`                       → buat kasus (callsign KSS-YYYYMMDD-XXXX)
   - `GET /api/cases/{case}`                 → detail kasus + articles + attachments + timeline
   - `PATCH /api/cases/{case}`               → update profil 5W+1H, status, lokasi
   - `DELETE /api/cases/{case}`              → hapus kasus (artikel anggota TIDAK ikut terhapus)
   - `POST /api/cases/{case}/attach-article` → tarik 1 artikel showcase ke kasus
   - `POST /api/cases/{case}/detach-article` → lepas artikel dari kasus
   - `POST /api/cases/{case}/recalc`         → recalculate avg Prunckun + threat level

- `routes/web.php` — hapus route `/peristiwa` & `api/events/*` (broken, refer ke Model `Event` yg sudah didrop). Ganti dengan group `api/cases/*`.

### Yang Dihapus (cleanup)
- `app/Http/Controllers/EventController.php` (broken, refer ke `App\Models\Event` yang sudah didrop di FASE A)
- `resources/js/Pages/Peristiwa.vue` (digantikan `Cases.vue`)

### Frontend — `resources/js/Pages/Cases.vue` (BARU, ~480 lines)
**Layout 2 panel:**
- **Kiri:** filter bar (Domain + Search) + tabel kasus (CALLSIGN/JUDUL/DOMAIN/📰/PRUNCKUN/TL/STATUS/UPDATED). Status pills di header: Semua/Aktif/Tunda/Arsip + tombol **+ KASUS BARU**
- **Kanan (520px):** detail panel dengan **5 tab**:
   1. **⭐ 5W+1H** — Grid 2×3 textarea: Apa/Siapa/Dimana/Kapan/Kenapa/Bagaimana (Six-Pointed Star). Plus deskripsi, domain, provinsi, status. Tombol **💾 SIMPAN PROFIL**.
   2. **📰 Artikel** — daftar artikel anggota + picker untuk tambah dari etalase (filter showcase). Tombol attach/detach.
   3. **🕐 Timeline** — kronologi vertikal urut `incident_date`, dot warna sesuai TL artikel.
   4. **📎 File** — grid attachment kasus (gambar lightbox + dokumen download). Upload multiple.
   5. **📊 Profil** — kartu agregat (jumlah artikel, avg Prunckun, avg TL, status, started_at, last_activity_at). Tombol **🔄 Refresh** (recalc) dan **🗑 HAPUS KASUS**.

**Modal Buat Kasus Baru:** input judul + domain + deskripsi → `POST /api/cases`.

### Sidebar
- `resources/js/Layouts/AppLayout.vue` — link `PERISTIWA → /peristiwa` diganti `KASUS → /kasus`.

### Build & Test
```bat
docker exec osint_app npm run build
```
(belum dijalankan di sesi ini — Docker Desktop perlu nyala dulu)

### Catatan / Deferred
- Six-Pointed Star saat ini ditampilkan sebagai grid 2×3, bukan visual heksagon. Visual heksagon murni (SVG) bisa jadi enhancement nanti — fungsionalnya sama.
- `recalculateMetrics()` jalan otomatis tiap attach/detach artikel. Tombol **🔄 Refresh** di tab Profil untuk trigger manual.
- Hanya artikel `data_status='showcase'` yang bisa ditarik ke kasus (artikel di Chamber/trash/archive di-skip).

---

## ✅ FASE E — Peta Terintegrasi (15 April 2026)

### Tujuan
Halaman **Peta** sekarang punya 2 mode: Mode Artikel (lama, choropleth risk score) + Mode Kasus (baru, marker bulat per provinsi). Analis bisa toggle untuk lihat distribusi geografis kasus.

### Backend
- `app/Http/Controllers/MapController.php`:
   - **`getCasesGeo(Request)`** (BARU) — return data kasus per provinsi:
      - `byProvince[]` — agregat per provinsi: `{province, lat, lng, count, article_count, max_tl, avg_tl, cases[]}`
      - `cases[]` — flat list semua kasus (untuk side panel)
      - `totals` — `{cases, provinces, articles}`
      - Filter: `status`, `domain`, `time` (today/week/month/year/all)
   - **`provinceCoordinates()`** static helper — lookup lat/lng untuk 38 provinsi Indonesia (incl. 4 provinsi baru Papua: Papua Tengah, Papua Pegunungan, Papua Selatan, Papua Barat Daya).

- `routes/web.php` — tambah `GET /api/map/cases`

### Frontend — `resources/js/Pages/Map.vue`
**Mode Toggle (top of left sidebar):** `📰 ARTIKEL` ↔ `⭐ KASUS`

#### Mode Kasus
- **Stats Grid:** Jumlah Kasus / Provinsi / Total Artikel Tertaut
- **Filter:** Status (Semua/Aktif/Tunda/Arsip) + Domain dropdown
- **Top Provinsi (Kasus):** klik = `flyTo` provinsi & filter side panel
- **Map markers:** `L.circleMarker` per provinsi
   - Radius = `min(28, 8 + count * 3)` px
   - Warna = `getTLColor(max_tl)` (TL5 merah → TL1 abu)
   - Klik marker → popup berisi 5 kasus pertama + `→ Buka halaman Kasus`
- **Right Sidebar:** ganti dari "OSINT Stream" → **"Kasus per Provinsi"**
   - Klik card → buka `/kasus`
   - Saat ada `focusedProvince`, list di-filter ke provinsi itu
- **Legend:** TL1-TL5 dengan note "Ukuran lingkaran = jumlah kasus"
- **Auto-refresh** tiap 30 detik

#### Mode Artikel (tetap)
Choropleth + OSINT Stream + Sensor Grid + Radar Chart — tidak diubah.

### State management
- `mapMode` ref → switch panel + marker layer
- `caseMarkerLayer` (L.layerGroup) — di-clear & re-create tiap fetch
- Watcher `[caseStatus, caseDomain]` → re-fetch saat filter berubah
- Watcher `mapMode` → fetch cases saat masuk mode kasus, hide marker saat keluar

### Build
✅ `npm run build` sukses — `Map-0sG-pW5u.js` 28.62 kB (sebelumnya 18.79 kB)

### Catatan / Deferred
- Heatmap intensitas (Leaflet.heat plugin) belum dipakai — diganti dengan circle markers berukuran proporsional. Heatmap bisa jadi enhancement nanti.
- Choropleth tetap muncul di Mode Kasus sebagai background (kasih konteks volume artikel). Bisa di-mute jika dirasa terlalu noisy.
- Koordinat provinsi pakai centroid manual — cukup untuk visualisasi marker, tapi bukan akurasi GPS.

---

## ✅ FASE F — Analisis Bertingkat (15 April 2026)

### Tujuan
Halaman **Analisis** punya 3 level analisis dengan **cross-filter antar level**: klik aktor di kasus → lompat ke tab Aktor; klik lokasi di kasus → lompat ke tab Region; klik kasus di profil aktor → lompat ke tab Kasus. Plus tombol **🖨 Cetak** (print-friendly CSS).

### Backend — `app/Http/Controllers/AnalisisController.php` (FULL REWRITE)
- **`index()`** — landing data: list kasus, agregasi per provinsi, agregasi per domain, top 30 aktor, overview stats
- **`caseAnalysis(case)`** — per-kasus:
   - `case` info
   - `articles[]` daftar artikel anggota
   - `trend[]` array `{date, callsign, prunckun, threat_level, capability, intent, opportunity}` urut tanggal
   - `tlDist` distribusi TL 1-5
   - `topActors[]` aktor di kasus + count + role
   - `locations[]` lokasi unik + frekuensi
- **`regionAnalysis(?type, ?value)`** — per-region (provinsi atau domain):
   - `cases[]`, `articles[]`
   - `tlDist`, `topActors[]`
   - `timeline[]` distribusi per bulan (12 bulan terakhir)
   - `totals` (cases, articles, avg_tl, avg_score)
- **`actorAnalysis(name)`** — per-aktor:
   - `primary_role`, `role_breakdown`
   - `cases[]`, `articles[]`
   - `domain_breakdown`, `locations[]`, `timeline[]`
   - `totals` (articles, cases, max_tl, avg_score)
   - Search aktor pakai `actors::text ILIKE '%"name":"X"%'` (postgres JSON cast)
- Helpers: `aggregatePerProvince()`, `aggregatePerDomain()`, `topActors($limit)`

### Routes baru
```
GET /api/analysis/case/{case}
GET /api/analysis/region?type=province|domain&value=...
GET /api/analysis/actor?name=...
```

### Frontend — `resources/js/Pages/Analisis.vue` (FULL REWRITE, ~480 lines)
**Layout 2 panel:**
- **Kiri (320px):** tab switcher 3 mode (⭐ KASUS / 🗺 REGION / 👥 AKTOR) + overview cards (Kasus/Artikel/Etalase/TL≥4) + search filter + list entitas
   - Region tab punya sub-toggle: PROVINSI vs DOMAIN
- **Kanan (flex-1):** detail panel sesuai mode

#### Detail per-Kasus
- Header + 4 stats (Artikel/Avg Score/Aktor Unik/Lokasi) + tombol 🖨 Cetak
- **TrendChart** (SVG inline): line chart Prunckun score per tanggal kejadian, dot warna sesuai TL
- **TLBarChart** (horizontal bar): distribusi TL artikel di kasus
- **Aktor di kasus** (klik = jump to actor tab)
- **Lokasi** (klik = jump to region tab type=province)
- List artikel anggota

#### Detail per-Region
- Header + 4 stats (Kasus/Artikel/Avg TL/Avg Score)
- **TimelineChart** (SVG bar chart): distribusi per bulan (12 bln terakhir)
- TLBarChart distribusi TL kasus
- Top aktor (klik = jump to actor)
- List kasus (klik = jump to case)

#### Detail per-Aktor
- Header dengan icon role + nama + primary role
- 4 stats (Artikel/Kasus/Max TL/Avg Score)
- Role breakdown (badge per role)
- Domain breakdown (klik = jump to region domain)
- TimelineChart keterlibatan per bulan
- Lokasi (klik = jump to region province)
- List kasus + list artikel

### Cross-filter (jumps)
- `jumpToCase(c)` — switch tab=case + selectCase
- `jumpToActor(name)` — switch tab=actor + selectActor
- `jumpToRegion(type, value)` — switch tab=region + set regionType + selectRegion

### Print-friendly
- Tombol 🖨 Cetak panggil `window.print()`
- CSS `@media print`: background putih, hide sidebar, semua warna jadi readable

### Chart components (inline `h()` SVG)
- **TrendChart** (560×140): line + dots warna TL + grid 25/50/75/100/125
- **TLBarChart**: horizontal bar TL5→TL1 dengan warna khas
- **TimelineChart** (560×100): bar chart 12 bulan + label angka di atas bar

### Build
✅ `npm run build` sukses — `Analisis-CSdJnoyQ.js` 24.63 kB

### Catatan
- Search aktor pakai pattern matching JSON di postgres — cukup untuk dataset moderat. Untuk jutaan artikel, perlu kolom denormalisasi.
- "Cetak PDF" pakai `window.print()` browser, bukan generate PDF di server. Alternatif: `dompdf` / `wkhtmltopdf` jika perlu file PDF asli.

---

## ✅ FASE G — Ingestion Scraping (SELESAI)

**Tujuan:** Pipeline ingesti untuk 3 script scraping eksternal (EVO 2, EVO 7.1, Tweet Harvest v2) agar hasilnya otomatis masuk ke Chamber (status `pending`, menunggu review analis).

### Arsitektur
```
┌─────────────────┐      ┌─────────────────┐      ┌──────────────────┐
│ EVO 2 (lama)    │─────▶│  /api/ingest/   │─────▶│ ChamberIngestion │
│ EVO 7.1 (+ AI)  │─────▶│  {evo|evo7|     │─────▶│ Service          │
│ Tweet Harvest   │─────▶│   tweet}        │─────▶│ (normalisasi +   │
└─────────────────┘      │                 │      │  duplikat check) │
   (Python)              │ X-Ingest-Token  │      └────────┬─────────┘
                         └─────────────────┘               │
                                                           ▼
                                                    ┌─────────────┐
                                                    │ChamberItem  │
                                                    │ status:     │
                                                    │  pending    │
                                                    │ data_status:│
                                                    │  pending    │
                                                    └─────────────┘
```

### Backend — Laravel

#### `app/Services/ChamberIngestionService.php` (NEW)
- `ingestEvo2(array)` — adapter EVO 2: payload simple `{title, content, url, source, date}`
- `ingestEvo71(array)` — adapter EVO 7.1: payload + blok `ai` (category, prunckun, admiralty, locations, actors)
- `ingestTweetHarvest(array)` — adapter tweet: `{tweet_id, full_text, username, retweet_count, ...}`
- `createOrSkipDuplicate()` — deteksi duplikat via **title_hash** (MD5 normalisasi title lowercase + strip whitespace/punct) + fallback URL
- Auto-generate callsign format `CHM-YYYYMMDD-NNNN`
- Auto-map threat_level dari prunckun_score (1-10→TL1, 11-25→TL2, 26-49→TL3, 50-75→TL4, 76-125→TL5)
- Tweet: engagement (RT+Fav+Reply) → media_exposure (rendah/sedang/tinggi)

#### `app/Http/Controllers/IngestController.php` (NEW)
- 3 endpoint: `evo2()`, `evo71()`, `tweet()`
- Support **single object** ATAU **batch** (`{items: [...]}`) dalam 1 request
- Response standar: `{success, source, total, created, skipped, errors, results[]}`
- Error per-item tidak gagalkan batch — tiap item dilog terpisah

#### `app/Http/Middleware/VerifyIngestToken.php` (NEW)
- Cek header `X-Ingest-Token` vs env `INGEST_TOKEN`
- Fallback: query `?token=` atau body `token`
- Fail-closed: jika `INGEST_TOKEN` env kosong → 500
- Gunakan `hash_equals()` (timing-safe)

#### `bootstrap/app.php`
- Alias middleware `ingest.token`
- Exempt `/api/ingest/*` dari CSRF (scraper bukan browser)

#### `routes/web.php`
```php
Route::middleware('ingest.token')->prefix('api/ingest')->group(function () {
    Route::post('/evo',   [IngestController::class, 'evo2']);
    Route::post('/evo7',  [IngestController::class, 'evo71']);
    Route::post('/tweet', [IngestController::class, 'tweet']);
});
```
Di **luar** middleware `auth` (scraper pakai token, bukan session).

### Python Adapter — ai-service

#### `ai-service/integrations/laravel_push.py` (NEW)
- `push_evo2(item)`, `push_evo2_batch(items)`
- `push_evo71(item)`, `push_evo71_batch(items)`
- `push_tweet(item)`, `push_tweet_batch(items)`
- `build_evo71_payload(...)`, `build_tweet_payload(...)` — helper struktur payload
- Konfigurasi via env: `LARAVEL_BASE_URL`, `INGEST_TOKEN`, `INGEST_TIMEOUT`
- `IngestError` exception untuk error handling
- CLI test: `python -m integrations.laravel_push`

#### `ai-service/main.py` (UPDATE)
- Endpoint relay: `POST /ingest/{evo|evo7|tweet}` — terima payload, forward ke Laravel
- `POST /ingest/analyze-and-push?url=...` — **pipeline satu langkah**: scrape → classify → Prunckun → actors → build payload → push ke Chamber. Cocok dipanggil dari EVO 7.1 hanya dengan URL.

### Konfigurasi `.env`

**platform-main/.env:**
```
INGEST_TOKEN=ubah-ini-ke-string-random-panjang-minimal-32char
```

**ai-service/.env:**
```
LARAVEL_BASE_URL=http://app:8000      # service name di docker compose
INGEST_TOKEN=...                      # harus sama dengan Laravel
INGEST_TIMEOUT=60
```

### Verifikasi (live test di container)
✅ `php -l` semua file baru — no syntax errors
✅ `route:list --path=api/ingest` — 3 route terdaftar
✅ POST tanpa token → **401** (middleware jalan)
✅ POST EVO 7.1 dengan token valid → **201 created**, callsign `CHM-20260415-0001`, prunckun 3×4×2=24 → TL2
✅ POST duplikat (title sama) → `skipped:1, reason:duplicate`
✅ POST batch tweet (2 item) → `created:2`

### Integrasi ke 3 Script Scraper

Di script EVO 7.1 user cukup:
```python
from integrations.laravel_push import push_evo71_batch, build_evo71_payload

items = []
for url in url_list:
    scraped = my_scraper(url)
    ai = my_ai_analyze(scraped)
    items.append(build_evo71_payload(
        title=scraped.title, content=scraped.content, url=url,
        source=scraped.source, category=ai.category,
        prunckun=ai.prunckun, admiralty=ai.admiralty,
        locations=ai.locations, actors=ai.actors,
    ))

result = push_evo71_batch(items)
print(f"Created: {result['created']}, Skipped: {result['skipped']}")
```

### Catatan
- **Duplikat detection** menggunakan `title_hash` (MD5 normalisasi) — tahan terhadap spasi ekstra, huruf besar/kecil, tanda baca. URL dipakai sebagai fallback.
- **Batch mode** direkomendasikan untuk > 10 item (performa lebih baik, 1 request = 1 transaksi DB).
- Script scraper lama cukup di-modify 1 baris: tambah `push_*()` di akhir loop alih-alih save ke file.
- Threshold threat_level konsisten dengan fase sebelumnya.

---

## ✅ FASE H — Chamber → Showcase Flow (SELESAI)

**Tujuan:** Melengkapi pipeline utama — dari ChamberItem (draft) → Article (etalase). Pipeline awal sudah ada di `ChamberController::showcase()`, tapi ada gaps kritis: attachments tidak pindah, tidak ada alert trigger, tidak ada update Location aggregate, dan tidak ada cara trigger AI re-analysis untuk item dari EVO2/tweet yang minim data AI.

### Arsitektur Flow
```
┌──────────────┐   [Re-analyze]   ┌──────────────┐   [Showcase]   ┌───────────────┐
│ ChamberItem  │ ───────▶ AI ────▶│ ChamberItem  │ ──────────────▶│ Article       │
│ pending      │ (classify +      │ scored       │  (DB.trans):   │ data_status:  │
│ (dari EVO2,  │  prunckun +      │ (enriched)   │   promote      │  showcase     │
│  tweet dsb)  │  actors + loc)   │              │   + attach     │ + Attachments │
└──────────────┘                  └──────────────┘   + locations  │ + AlertCheck  │
                                                     + alerts     │ + Telegram    │
                                                                   └───────────────┘
```

### Backend — Laravel

#### `app/Http/Controllers/ChamberController.php` (UPDATE)
Semua method `showcase()` / `archive()` / `trash()` diperbaiki:

**1. `promoteToArticle()` enhancement:**
- Lookup order baru: `chamberItem.article_id` → `title_hash` → `url` → create. Tahan re-promote (idempotent).
- Copy `title_hash` ke Article (konsisten dengan dedup check fase G)
- `category_primary` ambil `ai_domain_suggestion` dulu, fallback `raw_domain`

**2. `migrateAttachments()` (NEW helper):**
- Polymorphic reassign: `Attachment::where('attachable_type', ChamberItem)` → update ke `Article`
- Idempotent: kalau tidak ada attachment, no-op

**3. `updateLocationsAggregate()` (NEW helper):**
- Dipanggil saat showcase (bukan archive/trash)
- Hitung ulang `article_count` per provinsi dari DB (akurat, tidak double-count)
- Breakdown kategori dengan `GROUP BY category_primary`
- `risk_score` = (Σ(count × weight)) / (count × 5) × 100
- Weight: Hankam=5, Ideologi=4, Politik=3, Sosial=2, Ekonomi=1, Budaya=1
- Set `risk_level`: kritis (≥75), tinggi (≥50), sedang (≥25), rendah
- Trigger `AlertService::checkRiskSpike($province, new, old)` jika lonjakan ≥20

**4. `showcase()` pakai `DB::transaction()`:**
- Atomic: promote + update chamber + migrate attachments + update locations
- Alerts (`checkThreatLevel`, `checkVolumeSpike`) + Telegram **di luar transaction** dengan try/catch — gagal notif ≠ rollback data

**5. `reanalyze(ChamberItem)` (NEW endpoint):**
- Panggil AI service: kalau ada URL valid → `/analyze?url=`, kalau tidak → `/classify?text=`
- Update ChamberItem dengan hasil AI: `ai_domain_suggestion`, `ai_confidence`, `locations`, `actors`, `prunckun_*`, `threat_level`
- Auto-recalc Prunckun score dari C×I×O
- Error handling: 502 kalau AI service down, 500 kalau network error

#### `routes/web.php` (UPDATE)
```php
Route::post('/api/chamber/{chamberItem}/reanalyze', [ChamberController::class, 'reanalyze']);
```

### Frontend — `resources/js/Pages/Chamber.vue`

**Layout tombol aksi** (panel kanan bawah) direstrukturisasi:
- Row 1 (2 kolom): 💾 SIMPAN | 🤖 RE-ANALYZE (purple)
- Row 2 (3 kolom): 🗑 SAMPAH | 🗄 ARSIP | ✨ ETALASE

**Fungsi `reanalyzeItem()`:**
- Confirm dialog sebelum panggil AI (karena bisa 30-60 detik)
- Toast indikasi proses + hasil
- Update local state dengan data segar dari response

### Verifikasi (live test container)
✅ Lint semua file — no syntax errors
✅ `route:list --path=chamber` — 7 route (baru + reanalyze)
✅ `showcase()` test via tinker:
   - ChamberItem #2 (DKI Jakarta, Politik, prunckun=24, TL=2) → promote
   - Article baru dengan `data_status=showcase, TL=2, category=Politik`
   - Location "DKI Jakarta": `article_count=1, risk_score=60, risk_level=tinggi`
✅ Re-showcase idempotent — tidak buat Article duplikat
✅ `npm run build` sukses — `Chamber-CZVc2ogf.js` 21.26 kB

### Kenapa ini penting
- **Sebelum fase H:** data dari 3 scraper (EVO2/EVO7.1/tweet) masuk Chamber tapi kalau analis klik Etalase, attachments tidak ikut + locations tidak di-update + alert tidak trigger. Dashboard peta/heatmap jadi stale.
- **Setelah fase H:** Satu klik "Etalase" = lengkap pipeline. Data muncul di peta, alert ter-trigger, Telegram ping kalau TL≥4, risk_score provinsi ter-update.
- **AI Re-analyze:** Item dari EVO2/tweet (minim AI data) bisa di-enrich on-demand sebelum diputuskan nasibnya. Analis tidak harus hard-code C/I/O manual.

### Catatan
- `AI_SERVICE_URL` fallback ke `http://ai_service:8001` (service name docker compose)
- Re-analyze timeout 90s untuk full pipeline, 60s untuk classify-only
- Location update pakai `firstOrCreate` + recalc dari scratch — aman kalau Article pernah di-delete/restore
- Attachments migration adalah **move** (bukan copy), karena ChamberItem setelah showcase cuma history

---

## ✅ FASE I — Jalur 1: Pipeline Hidup (SELESAI)

**Tujuan:** Membuat sistem "hidup sendiri" — scheduler otomatis + analis produktif dengan stats & bulk ops.

### I-1. Scheduler Scraping RSS

#### Tabel baru `scraper_sources`
```sql
id, name, source_label, feed_url (unique), type (rss|url_list|twitter_keyword),
limit_per_run, is_active, last_run_at, last_error,
items_fetched_total, items_dispatched_total, timestamps
```

#### `app/Models/ScraperSource.php` (NEW)
- Scope `active()`, static `defaultFeeds()` (6 RSS Indonesia: Detik/Kompas/Tribun/CNN/Antara/Tempo)

#### `app/Console/Commands/ScrapeNewsCommand.php` (REWRITE)
- Baca sources dari DB (auto-seed saat tabel kosong)
- Options: `--limit`, `--source=...`, `--dry-run`
- Track per-source: `last_run_at`, `last_error`, counter `fetched`/`dispatched`
- Call AI service `/rss` → dispatch `ScrapeAndAnalyzeJob` per URL

#### `routes/console.php`
```php
Schedule::command('osint:scrape')
    ->everyFifteenMinutes()
    ->withoutOverlapping()
    ->runInBackground();
```

#### `ai-service/scraper/rss_scraper.py` (FIX)
- Hapus `import schedule` top-level (modul belum terinstall) — scheduling di Laravel
- AI service tetap expose `/rss?feed_url=...&limit=N` endpoint

### I-2. Dashboard Chamber Stats

#### `ChamberController::index()` — tambah blok `analytics`:
- **inbox_trend**: 7 hari × count ChamberItem per hari
- **processed_week**: breakdown showcase/archive/trash 7 hari terakhir
- **oldest_pending**: item pending paling tua + age_hours
- **sources**: daftar ScraperSource dengan status last_run/error

#### `Chamber.vue` — panel Analytics (collapsible, default show):
4 mini-panel di atas filter bar:
1. **INBOX 7 HARI** — bar chart mini (h=14, tooltip on hover), total + avg
2. **KEPUTUSAN 7 HARI** — rate breakdown + showcase_rate%
3. **ITEM TERTUA** — callsign + judul + age_hours (warna kuning ≥24h, merah ≥48h)
4. **SCRAPER SOURCES** — 4 source teratas, status dot (hijau/merah), total dispatched

### I-3. Bulk Operations

#### `ChamberController::bulkAction(Request)` (NEW)
- Actions: `trash`, `archive`, `assign`
- Validasi: `action in [...]`, `ids array min:1 max:500`, `assigned_to?`
- Safety: trash tidak boleh untuk item yang sudah `showcase`
- Archive pakai `DB::transaction()` + promote to Article + migrate attachments (reuse helper FASE H)
- Response: counter `success/skipped/errors`

#### Route baru
```php
Route::post('/api/chamber/bulk-action', [ChamberController::class, 'bulkAction']);
```

#### `Chamber.vue` — UI bulk:
- **Checkbox kolom baru** di table header (select all) + per row
- **Floating action bar** di bottom-center saat ≥1 item selected:
  `✓ N item | [input assign] 👤 ASSIGN | 🗄 ARSIP | 🗑 SAMPAH | ✕ Batal`
- Confirm dialog sebelum bulk action
- Auto-reload `items/stats/analytics` setelah sukses via `router.reload`

### Verifikasi
✅ Migration sukses: `scraper_sources` created
✅ Auto-seed: 6 RSS feed default masuk saat pertama jalan
✅ `osint:scrape --source='Detik News' --limit=2` → 2 artikel real Detik ter-queue
✅ Schedule terdaftar: `*/15 * * * *`
✅ `bulkAction(assign)` test via tinker — success:1
✅ `npm run build`: `Chamber-BsfU3FzQ.js` 28.46 kB (+7kB untuk analytics + bulk)

### Dampak Real-World
- **Sebelum:** User harus manual panggil `osint:scrape`, tidak tahu source mana yang error, tidak tahu item mana paling lama nunggu, kalau sampah 50 item harus klik 50x.
- **Sesudah:** Sistem auto-scrape tiap 15 menit → Chamber kebanjiran data → analis buka Chamber, lihat 4 KPI panel (ada item tertua 36 jam berarti perlu review!), bulk-select 20 item spam → 1 klik trash.

---

## 🔎 Analisa Anomali / Cacat Alur Logika Sistem

Audit menyeluruh dilakukan pasca FASE I pada seluruh alur: scraping → Chamber → showcase → Case → Early Warning → Alert → Map. Format tiap temuan: **[SEVERITY] Judul** — File:baris / Gejala / Dampak / Fix.

---

### 🔴 CRITICAL — Wajib diperbaiki sebelum produksi

**C1. `ScrapeAndAnalyzeJob` bypass Chamber: Article langsung `showcase`**
- **File:** `app/Jobs/ScrapeAndAnalyzeJob.php:52-86` (khususnya baris `'data_status' => 'showcase'` di 73)
- **Gejala:** Job ini membuat Article dengan `data_status='showcase'` DAN ChamberItem `pending` sekaligus. Artikel langsung muncul di Map, Dashboard, Kasus — padahal filosofi FASE G/H menetapkan artikel baru masuk lewat **Chamber dulu** (`pending`), baru dipromosikan ke Article oleh analis via tombol Etalase.
- **Dampak:** Seluruh konsep Chamber sebagai "ruang verifikasi" RUSAK. Data belum tereview langsung jadi bahan pengambilan keputusan. Duplikasi logika: Article dan ChamberItem di-upsert terpisah, rawan drift bila salah satu gagal.
- **Fix:** Hapus blok `Article::updateOrCreate(...)` + `AlertService::checkThreatLevel($article)` di baris 52-89. Biarkan hanya ChamberItem yang dibuat (lewat ChamberIngestionService lebih baik). Article hanya dibuat oleh `ChamberController::showcase()` / `::archive()`.

**C2. Bug `getOriginal('risk_score')` setelah save() → RiskSpike selalu zero**
- **File:** `app/Jobs/ScrapeAndAnalyzeJob.php:172` (`$oldScore = $location->getOriginal('risk_score') ?? 0;`)
- **Gejala:** `getOriginal()` dipanggil **setelah** `$location->save()`. Di Eloquent, setelah save(), `getOriginal()` mengembalikan nilai BARU (bukan nilai sebelumnya). Akibatnya `$spike = newScore - oldScore` selalu = 0.
- **Dampak:** Alert `risk_spike` TIDAK PERNAH TERTRIGGER dari pipeline scraping. Sistem peringatan dini cacat.
- **Fix:** Simpan `$oldScore` SEBELUM modifikasi: pindahkan `$oldScore = (float)($location->risk_score ?? 0);` ke atas, sebelum `$location->article_count += 1`. (Note: ChamberController::updateLocationsAggregate sudah benar di `ChamberController.php:463`, tapi job ini belum difix.)

---

### 🟠 HIGH — Cacat operasional yang terasa pemakai

**H1. `ChamberController::trash()` tidak mendemosi Article jika item pernah di-showcase**
- **File:** `app/Http/Controllers/ChamberController.php:273-284`
- **Gejala:** Saat analis mengubah pikiran ("item ini ternyata sampah") dan klik Sampah setelah sebelumnya Etalase, ChamberItem jadi `trash` tapi Article-nya masih `data_status='showcase'` → masih tampil di Map, Dashboard, Kasus.
- **Dampak:** Data yang sudah dinyatakan sampah tetap mempengaruhi risk score, threat level, timeline Kasus.
- **Fix:** Tambah di `trash()`: kalau `$chamberItem->article_id`, update Article tsb ke `data_status='trash'` (atau soft-delete), lalu panggil `updateLocationsAggregate()` untuk recompute risk. Juga perbaiki `updateLocationsAggregate()` agar tetap jalan untuk artikel yang DIKELUARKAN dari showcase (saat ini hanya menghitung artikel showcase, tapi tidak memicu recompute saat ada yang di-demote).

**H2. `bulkAction` archive branch: archive artikel yang sudah showcase tidak mendemosi Article**
- **File:** `app/Http/Controllers/ChamberController.php:319-332`
- **Gejala:** Di branch `archive`, kalau `data_status != 'pending'` (misal sudah `showcase`), cuma `update(['data_status' => 'archive'])` tanpa memanggil `promoteToArticle()` / demote. Article masih `showcase` → masih tampil di Etalase.
- **Dampak:** Sama dengan H1 — data inconsistency antara ChamberItem dan Article.
- **Fix:** Jika `data_status === 'showcase'`, juga update `$article->data_status = 'archive'` + panggil `updateLocationsAggregate()`.

**H3. `CaseController::store()` tidak auto-set `primary_province`**
- **File:** `app/Http/Controllers/CaseController.php:80-105`
- **Gejala:** Kasus baru dibuat tanpa `primary_province`. `MapController::getCasesGeo()` (Peta Kasus) memfilter `!$prov || !isset($coords[$prov])` — kasus tanpa provinsi **tidak pernah muncul di peta**, walau sudah punya banyak artikel.
- **Dampak:** Mode "Peta Kasus" kelihatan kosong terus. Analis harus manual edit kasus dan isi provinsi — friction besar.
- **Fix:** Setelah `attachArticle()` (CaseController.php:169), atau di `recalculateMetrics()` (CaseFile.php), derive `primary_province` dari mayoritas provinsi semua artikel anggota. Contoh: `primary_province = array_count_values(flatten(locations))->sortDesc()->first()`.

**H4. `MapController::getFilteredData()` tidak filter `data_status='showcase'`**
- **File:** `app/Http/Controllers/MapController.php:43-64`
- **Gejala:** Query `Article::query()` tidak memfilter data_status. Karena `ScrapeAndAnalyzeJob` menulis Article langsung sebagai `showcase` (lihat C1), dan `ChamberController::archive()` bikin Article juga (status `archive`), query Map menarik SEMUA artikel — termasuk yang arsip.
- **Dampak:** Risk score peta ter-inflate oleh artikel arsip. Setelah C1 difix pun, query ini tetap harus explicit `->where('data_status', 'showcase')`.
- **Fix:** Tambah `$query->where('data_status', 'showcase');` di baris 49.

---

### 🟡 MEDIUM — Anomali halus, perlu diperbaiki tapi tidak menghentikan operasi

**M1. Race condition pada `generateCallsign()`**
- **File:** `app/Services/ChamberIngestionService.php:276-281` (juga `Article::generateCallsign` serupa)
- **Gejala:** `count(today) + 1` dipanggil di PHP layer. Jika 2 worker queue/scraper ingest bersamaan dalam 1 detik, keduanya bisa dapat `CHM-20260415-0007` — konflik callsign (unique constraint trigger error) atau kedua pakai sama (kalau tidak unique).
- **Dampak:** Pada traffic tinggi (terutama setelah scheduler FASE I-1 jalan tiap 15 menit), duplikat callsign akan muncul sporadic.
- **Fix:** Gunakan atomic sequence: manfaatkan `DB::transaction()` + `LOCK IN SHARE MODE`, atau migrasi ke format random seperti CaseFile (`KSS-YYYYMMDD-XXXX` md5 uniqid) yang sudah race-safe (CaseFile.php:86).

**M2. `reanalyze()` overwrites manual edit analis tanpa konfirmasi**
- **File:** `app/Http/Controllers/ChamberController.php:513-587`
- **Gejala:** Klik "Re-analyze" langsung timpa `locations`, `actors`, `prunckun_*`, `ai_domain_suggestion` — tanpa diff atau konfirmasi. Kalau analis sudah manual benerin `locations = ['DKI Jakarta']` lalu iseng klik Re-analyze → AI overwrite jadi `['Jawa Barat']` lagi.
- **Dampak:** Kerja manual analis hilang tiba-tiba. Low-trust feature.
- **Fix:** Tambah param `?mode=preview` yang return diff tanpa update DB. Frontend tampilkan modal "AI menyarankan perubahan berikut: [list diff]" dengan checkbox per field sebelum commit.

**M3. Dua sistem alerting paralel: `EarlyWarning` vs `Alert`**
- **File:** `app/Models/EarlyWarning.php` + `app/Services/AlertService.php`
- **Gejala:** `EarlyWarningPageController` menarik Article TL≥4 → masuk tabel `early_warnings`. `AlertService::checkThreatLevel` juga membuat record di tabel `alerts` untuk TL≥4. Dua tabel beda, dua konsep sama.
- **Dampak:** Analis bingung: harus resolve EarlyWarning atau markRead Alert? Risk double-notification. Pelacakan SLA jadi hanya separuh akurat.
- **Fix:** Pilih SATU. Rekomendasi: pertahankan `alerts` (lebih general: threat/risk_spike/volume_spike) dan tegaskan `early_warnings` hanya sebagai VIEW/derived filter dari `alerts` where type='threat_level'. Atau hapus duplikasi.

**M4. `CaseFile::recalculateMetrics()` membuat artikel "menghilang" saat di-archive**
- **File:** `app/Models/CaseFile.php:93-123`
- **Gejala:** `$articles = $this->articles()->where('data_status', 'showcase')->get();` — kalau analis mengubah status artikel dari `showcase` → `archive` di Chamber, recalc kasus menghitung artikel itu hilang dari kasus. Tapi artikel secara teknis masih terikat (pivot `case_articles` masih ada).
- **Dampak:** Metrik kasus fluktuatif. User tidak ada notifikasi "artikel hilang dari kasus karena status berubah".
- **Fix:** Dua opsi: (a) tampilkan di UI kasus juga artikel non-showcase dengan flag "archived/trashed"; atau (b) saat demote artikel, tampilkan warning ke analis "artikel ini terikat di Kasus X, yakin?".

**M5. `AlertService::checkThreatLevel` hanya pakai `locations[0]`**
- **File:** `app/Services/AlertService.php:21`
- **Gejala:** `$article->locations[0] ?? 'Unknown'` — kalau urutan provinsi di array random atau multi-provinsi, yang dipilih arbitrary.
- **Dampak:** Alert di-tag ke provinsi yang tidak paling representatif. Dedup `existing` check (1 jam, per provinsi) jadi bisa duplicate karena provinsi berbeda.
- **Fix:** Pakai `primary_province` atau kalkulasi provinsi dominan. Atau buat alert per-provinsi (loop semua `locations`).

**M6. `CaseController::destroy` hard-delete tanpa audit trail**
- **File:** `app/Http/Controllers/CaseController.php:143-151`
- **Gejala:** `$case->delete()` hard delete. Tidak ada recovery, tidak ada log siapa hapus kapan.
- **Dampak:** Kecelakaan hapus kasus dengan puluhan artikel tidak bisa undo.
- **Fix:** Migrasi ke soft-delete (`SoftDeletes` trait + `deleted_at`). Atau pindahkan ke `status='archived'` saja (sudah ada status ini).

---

### 🟢 LOW — Cosmetic / optimisasi, tidak urgent

**L1. `whereJsonContains('locations', $province)` tidak ter-index**
- **File:** `ChamberController.php:467, 473` + `MapController.php`
- **Gejala:** Query aggregate provinsi mencari string di kolom JSON `locations`. Tanpa GIN index di PostgreSQL → scan full table. Dengan 10k+ artikel performa menurun terasa.
- **Fix:** Tambah GIN index migration: `$table->index(['locations'], 'locations_gin')->using('gin');` atau pisahkan ke tabel pivot `article_locations`.

**L2. `EarlyWarningPageController::index` N+1 untuk stats**
- **File:** `app/Http/Controllers/EarlyWarningPageController.php:30-35`
- **Gejala:** `$warnings->where(...)->count()` dipanggil di collection PHP (bukan DB), tapi sudah di-load semua dulu. OK untuk 50 records, tapi scale-unsafe.
- **Fix:** Pisahkan query stats dengan groupBy di DB layer.

**L3. `ScraperSource` fetching RSS via AI service ambil round-trip tambahan**
- **File:** `ScrapeNewsCommand.php:69-72`
- **Gejala:** Laravel → AI service `/rss` → feedparser → balikan ke Laravel → dispatch job → AI service lagi `/analyze`. 2 round-trip per feed.
- **Fix:** Langsung pakai `simplexml_load_file` di PHP untuk tahap RSS fetch, atau cache hasil feedparser di AI service.

**L4. `promoteToArticle` lookup order rawan duplikasi**
- **File:** `ChamberController.php:363-418`
- **Gejala:** Jika `title_hash` kosong dan URL kosong (tweet tanpa tweet_url), create new Article tiap promote. Race: klik Etalase 2x cepat → 2 Article.
- **Fix:** Tambah unique constraint DB: `unique(title_hash)` + handle exception sebagai "already exists, use existing".

---

### 📋 Ringkasan Prioritas Fix (urutan kerja sesi depan)

| Prio | Fix | Estimasi | Dampak Unblock |
|------|-----|----------|---------------|
| 1 | C1 — Hapus Article creation di ScrapeAndAnalyzeJob | 10 mnt | Kembalikan konsep Chamber |
| 2 | C2 — Fix getOriginal bug untuk riskSpike | 5 mnt | RiskSpike alerting hidup |
| 3 | H1+H2 — Demote Article saat trash/archive ulang | 30 mnt | Data integrity |
| 4 | H3 — Auto-set primary_province kasus | 20 mnt | Peta Kasus terisi |
| 5 | H4 — Filter data_status=showcase di Map | 5 mnt | Risk score akurat |
| 6 | M1 — Callsign race safety | 15 mnt | Scale-safety |
| 7 | M3 — Konsolidasi EarlyWarning vs Alert | 1-2 jam | UX clarity |
| 8 | M2 — Re-analyze diff mode | 1 jam | Trust feature |

**Kesimpulan:** Aplikasi SECARA FITUR lengkap (FASE A-I selesai), tapi ada **2 cacat CRITICAL** yang membuat konsep inti (Chamber = ruang verifikasi) tidak benar-benar berlaku di jalur scraping, plus **4 HIGH** yang merusak integritas data. Fix 6 item pertama (~1.5 jam kerja) membuat sistem benar-benar **aplikatif** untuk produksi.

---

## 🛠️ FASE I-Fix — Remediation Pass (C1, C2, H1-H4)

**Durasi:** ~45 menit · **Status:** ✅ Selesai · **PHP lint:** clean · **Smoke test:** pass

Semua 6 cacat prioritas tertinggi dari audit di atas diperbaiki dalam satu batch remediation.

### ✅ C1 — ScrapeAndAnalyzeJob rewrite
**File:** `app/Jobs/ScrapeAndAnalyzeJob.php` (rewrite total)
- **Sebelum:** Bikin Article `showcase` + ChamberItem `pending` sekaligus → bypass Chamber.
- **Sesudah:** HANYA bikin ChamberItem via `ChamberIngestionService::ingestEvo71()`. Tidak sentuh tabel `articles` maupun `locations`.
- **Efek:** Konsep Chamber sebagai pintu masuk tunggal data sekarang berlaku konsisten untuk semua jalur (scheduler RSS + 3 scraper eksternal).

### ✅ C2 — getOriginal risk_score
**File:** `app/Jobs/ScrapeAndAnalyzeJob.php` (hilang otomatis setelah C1)
- Karena Job tidak lagi update Location, bug `getOriginal('risk_score')` setelah `save()` otomatis lenyap.
- RiskSpike alert sekarang hanya dipicu dari `ChamberController::updateLocationsAggregate()` yang sudah benar (oldScore disimpan sebelum save).

### ✅ H1 — trash() demote Article
**File:** `app/Http/Controllers/ChamberController.php::trash()`
- Tambah flag `$wasShowcase`, kalau true → update Article terhubung ke `data_status='trash'` dalam transaction.
- Panggil `updateLocationsAggregate()` sesudahnya untuk recompute risk score peta.
- Branch bulk-trash juga di-upgrade sama.

### ✅ H2 — archive() + bulkAction archive branch
**File:** `app/Http/Controllers/ChamberController.php::archive()` + `bulkAction()`
- `archive()`: Tambah flag `$wasShowcase`, kalau true, setelah promote/update Article ke `archive`, panggil `updateLocationsAggregate()`.
- `bulkAction` archive branch: dua path sekarang — (a) pending→archive (promote baru), (b) showcase/archive→archive (update existing Article + recompute locations).

### ✅ H3 — Auto-derive primary_province di CaseFile::recalculateMetrics
**File:** `app/Models/CaseFile.php`
- Kalau `primary_province` masih null saat recalc, tally semua provinsi dari artikel anggota → pilih yang paling sering.
- Juga auto-isi `locations` (array unik) jika kosong.
- Respect manual input: kalau analis sudah isi `primary_province` manual, jangan ditimpa.
- **Efek:** Peta Kasus otomatis terisi begitu artikel pertama di-attach.

### ✅ H4 — MapController filter data_status=showcase
**File:** `app/Http/Controllers/MapController.php`
- `index()`: Article count + categoryCounts sekarang `where('data_status','showcase')`.
- `getFilteredData()`: Query root di-prefix `->where('data_status','showcase')` → seluruh aggregate (locations, stats, categories) carry filter ini.
- **Efek:** Peta tidak lagi ter-inflate oleh artikel pending/archive/trash.

### Dampak Gabungan Fix
- **Integritas data:** Artikel di Map/Kasus/Dashboard SELALU tereview analis. Item yang di-demote (showcase → trash/archive) tidak tertinggal di peta.
- **UX Kasus:** Peta Kasus auto-populated tanpa input manual provinsi.
- **Konsistensi konsep:** Slogan "Chamber = ruang verifikasi" sekarang benar 100% (sebelumnya 50% — hanya berlaku untuk input manual + 3 scraper eksternal, scheduler bypass).

### Smoke Test Results
```
✅ PHP lint 4 files: clean
✅ Chamber routes: 7 registered
✅ ChamberIngestionService::ingestEvo71: OK (create chamber item, skip duplicate ok)
✅ CaseFile::recalculateMetrics: preserves manual primary_province
```

### Turunan Audit Tersisa (Belum Diperbaiki, Prioritas Rendah)
- M1: Race condition generateCallsign (scale-safety)
- M2: Re-analyze overwrite tanpa diff
- M3: Konsolidasi EarlyWarning vs Alert
- M4-M6: Cosmetic / edge cases
- L1-L4: Optimisasi index & round-trip

Rencana: diangkat sesi depan sebagai **FASE J — Quality Pass** (jika diperlukan).

---

## 🔜 Next Session — FASE J (Saran)

Sisa arah lanjutan dari FASE H saran:
1. **Scheduler scraping** — Laravel schedule call `ai-service/ingest/analyze-and-push` periodik dari daftar RSS (otomasi pipeline)
2. **Telegram alerts diperluas** — notifikasi saat ChamberItem baru masuk dengan `threat_level ≥ 4` (sebelum review analis)
3. **Unit tests** — coverage untuk `ChamberIngestionService` (duplikat, TL mapping, callsign) + `ChamberController::showcase` (attachment migration, location update)
4. **Dashboard Chamber stats** — grafik inbox Chamber per hari, rate showcase/archive/trash
5. **Bulk operations** — multi-select item di Chamber → bulk archive/trash

Start sesi berikutnya dengan: **"Lanjut FASE I"** (atau spesifikasikan)
