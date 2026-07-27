# Cấu trúc repo

Bản đồ toàn bộ repo để đọc nhanh trước khi sửa code. **Có thay đổi cấu trúc
(thêm/xoá/đổi vai trò file, đổi schema, đổi route) → cập nhật file này trong
cùng commit.**

Cập nhật lần cuối: commit `a0e60a0` (2026-07-27) — 71 file tracked, ~5.000 dòng.

## Tổng quan

Plugin Redmine (`:periodictask`) cho phép lên lịch tự động tạo issue theo chu
kỳ. Không phải Rails app độc lập — code được nạp vào runtime của Redmine, nên
`Issue`, `Project`, `User`, `IssueQuery`... là class của Redmine host, không
định nghĩa trong repo này.

Kiến trúc: một model chính (`Periodictask`) giữ cấu hình "issue mẫu + chu kỳ",
một rake task chạy từ cron quét task đến hạn và tạo issue thật, hai bảng phụ ghi
lịch sử (`periodictask_issues`) và activity log (`periodictask_journals`).

Redmine hỗ trợ: 5.1, 6.0, 6.1 (CI chạy đủ 3 bản). Ruby 3.4.

## Cây thư mục

```
init.rb                      Đăng ký plugin: version, project_module,
                             permission :periodictask, activity_provider,
                             menu project. Require hooks.rb + patch Project.
config/routes.rb             Route thủ công (dùng match cho update để tương
                             thích cả put lẫn patch).
config/locales/*.yml         12 ngôn ngữ. en.yml là bản gốc (58 key).

app/models/
  periodictask.rb            Model chính. Cấu hình chu kỳ + sinh issue.
  periodictask_issue.rb      Join Periodictask ↔ Issue đã sinh (lịch sử chạy).
  periodictask_journal.rb    Bản ghi audit create/update/delete/run, đẩy vào
                             activity log của Redmine qua acts_as_event +
                             acts_as_activity_provider.
app/controllers/
  periodictask_controller.rb CRUD + customfields (AJAX) + run_now.
app/helpers/
  periodictask_helper.rb     Helper view: icon tương thích R5/R6, label unit,
                             format time, link parent, picker watcher,
                             tích hợp redmine_checklists.
app/views/periodictask/
  index.html.erb             Bảng danh sách, sort theo nhiều cột.
  show.html.erb              Chi tiết task + lịch sử issue đã sinh.
  new/edit.html.erb          Bọc _form.
  _form.html.erb             Form chính (161 dòng).
  _customfields.html.erb     Khối custom field của issue mẫu.
  customfields.js.erb        Response AJAX render lại khối trên khi đổi tracker.
  _issue_periodictask_link   Partial hook: hiện "created by periodic task #n"
    .html.erb                trên trang issue.
  _credit.html.erb           Footer credit tác giả.
  destroy.html.erb           Trang xác nhận xoá.

lib/
  scheduled_tasks_checker.rb Vòng lặp scheduler: quét task đến hạn → tạo issue →
                             ghi lịch sử → dời next_run_date. Ghi last_error
                             thay vì raise.
  tasks/periodictask.rake    rake redmine:check_periodictasks — entry point cho
                             cron, gọi ScheduledTasksChecker.checktasks!
  redmine_periodictask/
    hooks.rb                 ViewListener render partial vào
                             :view_issues_show_description_bottom.
    project_patch.rb         Project has_many :periodictasks, dependent: :destroy

db/migrate/                  15 migration, xem mục Schema bên dưới.

test/
  test_helper.rb             Nạp test_helper của Redmine host.
  fixtures/periodictasks.yml
  unit/periodictasks_test.rb        734 dòng — model, sinh issue, macro,
                                    custom field, watcher, checker.
  unit/get_next_run_date_test.rb    Chống trôi lịch (drift) qua nhiều lần chạy.
  unit/timezone_test.rb             Bắt buộc dùng Time.current, không Time.now.
  functional/periodictask_controller_test.rb
  functional/issue_periodictask_hook_test.rb

Dockerfile                   Image dev (docker compose).
Dockerfile.test              Image CI: cài plugin vào Redmine, migrate DB test.
docker-compose.yml           Redmine + SQLite volume, mount repo vào
                             plugins/periodictask.
provision.sh                 Seed DB dev: migrate, load_default_data, bật module
                             cho project mẫu.
.claude/
  settings.json              Stop hook nhắc cập nhật file này.
  hooks/check-repo-          Script của hook trên. Chỉ nhắc, không chặn.
    structure-sync.sh
.rubocop.yml                 Ruby 3.4. Tắt Metrics, Style/Documentation,
                             FrozenStringLiteralComment, Naming/VariableNumber.
                             Exclude db/**/*.
.github/workflows/test.yml   CI: rubocop + test trên 3 bản Redmine.
```

## Schema

**`periodictasks`** — cấu hình một task định kỳ.

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `project_id`, `tracker_id`, `assigned_to_id`, `author_id` | integer | FK sang bảng Redmine |
| `subject`, `description` | string / text | Hỗ trợ macro `**YEAR**`, `**MONTH**`... |
| `interval_number`, `interval_units` | integer / string | Unit: `day`, `business_day`, `week`, `month`, `year` |
| `next_run_date` | datetime | Mốc scheduler so sánh |
| `last_assigned_date` | datetime | Di sản từ migration đầu; không code nào đọc/ghi, chỉ còn trong fixtures |
| `set_start_date` | boolean | Gán start_date = ngày chạy |
| `due_date_number`, `due_date_units` | integer / string | Offset due date |
| `issue_category_id`, `estimated_hours`, `parent_id`, `priority_id` | | Map thẳng sang Issue |
| `checklists_template_id` | integer | Chỉ dùng khi có plugin redmine_checklists |
| `custom_field_values` | text (JSON) | Migration `20260629000001` chuyển từ YAML sang JSON |
| `watcher_user_ids` | json | Mảng id, model tự lọc giá trị rác |
| `last_error` | string | Lỗi lần chạy gần nhất, hiện trên UI |
| `created_at`, `updated_at` | datetime | |

**`periodictask_issues`** — `periodictask_id`, `issue_id`, `created_at`. Index
trên cả hai FK. Join này khiến issue đã xoá tự biến mất khỏi lịch sử.

**`periodictask_journals`** — `periodictask_id` (nullable, giữ lại sau khi task
bị xoá), `project_id`, `user_id`, `action` (`create`/`update`/`delete`/`run`),
`subject`, `created_on`. Index `(project_id, created_on)`.

## Luồng chính

**Người dùng tạo/sửa task** → `PeriodictaskController#create|update` → dựng
`@issue = generate_issue` để validate trước → `save` → `log_activity`. Sinh
journal ở controller chứ không ở model callback, để scheduler ghi
`next_run_date`/`last_error` không bị log thành "user sửa".

**Cron chạy** → `rake redmine:check_periodictasks` →
`ScheduledTasksChecker.checktasks!` → lấy mọi task có `next_run_date <= now` →
`generate_issue` → `save!` → `fill_watchers` → `record_generated_issue` →
`next_run_date = get_next_run_date(now)`. Lỗi validate được nuốt vào `last_error`
để một task hỏng không chặn các task còn lại.

**`get_next_run_date`** cộng bội số chu kỳ từ `next_run_date` cũ (không phải từ
`now`) nên giờ chạy không trôi dần; `business_day` lặp cộng từng bước vì không
cộng bù được.

**Nút "Run now"** (`#run_now`) sinh issue ngay mà **không** đụng
`next_run_date` — lịch giữ nguyên.

**Quyền**: một permission duy nhất `:periodictask` gác toàn bộ action; scope
`Periodictask.accessible` kiểm tra lại ở tầng model.

## Điểm cần lưu ý khi sửa

- **Tương thích 3 bản Redmine.** Đã có sẵn các nhánh fallback: `before_action` vs
  `before_filter`, `ApplicationRecord` vs `ActiveRecord::Base`, `sprite_icon` chỉ
  có ở R6. Thêm API mới của Redmine → phải có nhánh fallback cho R5.1.
- **Luôn dùng `Time.current`, không `Time.now`.** `timezone_test.rb` đọc thẳng
  source của model / checker / controller và assert vào chữ ký hàm — đổi
  signature `generate_issue` hay `get_next_run_date` là test đỏ.
- **Chuỗi hiển thị phải qua i18n.** Thêm key vào `config/locales/en.yml` trước;
  các ngôn ngữ khác thiếu key sẽ tự fallback về en.
- **`db/**/*` bị exclude khỏi rubocop** — migration cũ vẫn dùng hash rocket.
- **redmine_checklists là tuỳ chọn.** Mọi truy cập `ChecklistTemplate` phải bọc
  `checklist_plugin_installed?`.

## Lệnh

```bash
rubocop                                    # lint
docker build -f Dockerfile.test --build-arg REDMINE_TAG=6.1-bookworm -t periodictask-test .
docker run --rm periodictask-test          # toàn bộ test plugin
docker compose up --build                  # dev server :3000
./provision.sh                             # seed DB dev
```
