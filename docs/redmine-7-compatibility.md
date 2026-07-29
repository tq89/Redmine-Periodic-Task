# Đánh giá tương thích Redmine 7.0

Đối chiếu plugin (commit `e28a70f`) với **Redmine 7.0.0** (tag `7.0.0`, commit
`e192cf1`, clone từ https://github.com/redmine/redmine).

Ký hiệu nguồn: `rm7:<đường dẫn>:<dòng>` = file trong source Redmine 7.0.0;
`rails:<file>:<dòng>` = source Rails 8.1.3 (tag `v8.1.3`).

## Kết luận

**Không tìm thấy lỗi chặn (blocking).** Toàn bộ API Redmine/Rails mà plugin gọi
đều còn tồn tại trong 7.0.0 với chữ ký tương thích. Có **một hồi quy hiển thị
thật** (icon biến mất, mục A) và một ít code tương thích đã chết (mục B).

Cảnh báo về mức độ xác thực: đánh giá này là **đối chiếu source tĩnh**, chưa
chạy được test suite trên Redmine 7.0 (môi trường đánh giá không có Docker khả
dụng). Xem mục C.

Redmine 7.0.0 chạy Rails 8.1.3, Ruby `>= 3.2.0, < 4.1.0`
(`rm7:Gemfile:3,5`; `rm7:doc/INSTALL` liệt kê Ruby 3.2/3.3/3.4/4.0).

> **Cập nhật:** mục A và E đã được xử lý trong cùng nhánh — xem "Trạng thái xử
> lý" ở cuối file.

## A. Vấn đề thật: icon biến mất

Redmine 7.0 **đã xoá các class CSS `icon-*` khỏi stylesheet** — CHANGELOG mục
`Patch #43206: Remove deprecated icon-* classes from stylesheets`. Kiểm chứng
bằng grep trên `rm7:app/assets/stylesheets/application.css`: `icon-add`,
`icon-edit`, `icon-reload`, `icon-del`, `icon-add-bullet` đều **0 dòng**.

Class `.icon` vẫn còn (`rm7:app/assets/stylesheets/application.css:2175`) nhưng
giờ chỉ là flex container cho `<svg>` con; `.icon-error` cũng còn nhưng chỉ
dưới dạng `.icon-error svg.icon-svg {}` (dòng 2213) — tức là nó **tô màu cho
SVG con**, không tự vẽ icon nữa.

Hệ quả, xếp theo mức nghiêm trọng:

| Chỗ | Hiện trạng trên R7 |
|---|---|
| `app/views/periodictask/_issue_periodictask_link.html.erb:5` — `<span class="icon icon-reload"></span>` | **Span rỗng, không có SVG con → không hiện gì cả.** Đây là chỗ duy nhất icon mất hẳn. |
| `show.html.erb:101`, `_form.html.erb:129` — `<span class="icon icon-error">…</span>` | Chữ vẫn hiện, mất icon cảnh báo. |
| `show.html.erb:5,12,16`, `index.html.erb:7`, `_form.html.erb:114` — `class: 'icon icon-*'` trên `link_to` | **Không ảnh hưởng** — nội dung link đã là `sprite_icon(...)` nên SVG vẫn vẽ; class chỉ còn là rác. |

Cách sửa: thay span rỗng bằng `sprite_icon('reload')` / `sprite_icon('error')`.
Cả 4 tên icon plugin đang dùng (`add`, `edit`, `reload`, `del`) đều còn trong
sprite 7.0 — kiểm bằng id `icon--<tên>` trong `rm7:app/assets/images/icons.svg`
(tiền tố `icon--` do `svg_sprite_icon` tự thêm, xem
`rm7:app/helpers/icons_helper.rb:120`).

## B. Code tương thích đã chết trên R7 (vô hại)

Chỉ dọn nếu bỏ hỗ trợ Redmine 5.1:

- `app/helpers/periodictask_helper.rb:5-9` — nhánh fallback khi không có
  `sprite_icon`. Trên R7 `sprite_icon` luôn có
  (`rm7:app/helpers/icons_helper.rb:36`) nên nhánh sau không bao giờ chạy.
- `app/controllers/periodictask_controller.rb:2-6` — alias `before_filter`.
- `app/models/periodictask_journal.rb:6` — ternary `ApplicationRecord` /
  `ActiveRecord::Base`. R7 có `ApplicationRecord`.

## C. Chưa xác thực bằng test chạy thật

CI hiện chỉ chạy `5.1-bookworm`, `6.0-bookworm`, `6.1-bookworm`
(`.github/workflows/test.yml`). Image `redmine:7.0-bookworm` **đã có trên Docker
Hub** (kiểm qua API Docker Hub: tag `7.0`, `7.0.0`, `7.0-bookworm`,
`7.0.0-bookworm`, `7.0-trixie`, `7.0-alpine`… tổng 12 tag), nên chỉ cần thêm
một dòng vào ma trận CI.

Đánh giá này **không thay thế** việc chạy test — nó chỉ chứng minh không có API
nào bị xoá/đổi chữ ký. Các lỗi chỉ lộ ra khi chạy (thứ tự autoload, tương tác
Zeitwerk, hành vi runtime của Rails 8.1) vẫn còn nguyên rủi ro.

## D. Bảng đối chiếu API — tất cả đều PASS

### Đăng ký plugin & hook

| Plugin dùng | Nguồn xác thực 7.0 |
|---|---|
| `Redmine::Plugin.register` + `project_module` + `permission(name, hash)` | `rm7:lib/redmine/plugin.rb:381,362` — ví dụ trong docstring khớp đúng dạng hash plugin đang dùng |
| `activity_provider` | `rm7:lib/redmine/plugin.rb:409` |
| `menu :project_menu, …, param: :project_id` | `rm7:lib/redmine/plugin.rb:328` |
| `Redmine::Hook::ViewListener` + `render_on` | `rm7:lib/redmine/hook/view_listener.rb:24,58` (đã tách khỏi `hook.rb`, tên class không đổi) |
| hook `:view_issues_show_description_bottom` | vẫn được gọi tại `rm7:app/views/issues/show.html.erb:131` |
| `config/routes.rb` của plugin được nạp | `rm7:config/routes.rb:432` |
| `Gemfile` của plugin được nạp | `rm7:Gemfile:133` |

### Model / activity

| Plugin dùng | Nguồn |
|---|---|
| `acts_as_event(… group: :periodictask)` | `rm7:lib/plugins/acts_as_event/lib/acts_as_event.rb:28`; option `:group` được đọc tại dòng 68-69 |
| `acts_as_activity_provider(type/permission/author_key/timestamp/scope)` | `rm7:lib/plugins/acts_as_activity_provider/lib/acts_as_activity_provider.rb:34` — `assert_valid_keys` khớp **đúng** 5 khoá plugin truyền |
| `add_watcher(user)` | `rm7:lib/plugins/acts_as_watchable/lib/acts_as_watchable.rb:73` |
| `Project#assignable_users / members / issue_categories / active? / trackers / principals` | `rm7:app/models/project.rb:604, 35, 51, 401, 39, 258` |
| `Principal.assignable_watchers` | `rm7:app/models/principal.rb:119` |
| `User#allowed_to?(action, context, options)` | `rm7:app/models/user.rb:776` → `global: true` hợp lệ |
| `Issue#editable_custom_field_values / required_attribute?` | `rm7:app/models/issue.rb:664, 701` |
| `String#to_hours` | `rm7:lib/redmine/core_ext/string/conversions.rb:29` |
| `User::STATUS_ACTIVE` | `rm7:app/models/principal.rb:25` |

**Điểm cộng:** 7.0 deprecate `acts_as_activity_provider` khi truyền `:scope`
*ngầm* hoặc `:permission` *ngầm*
(`…/acts_as_activity_provider.rb:64,85`). Plugin truyền **cả hai một cách tường
minh** (`scope: proc {…}`, `permission: :periodictask`), và điều kiện tại dòng
61 (`scope.respond_to?(:call)`) / dòng 80 (`has_key?(:permission)`) cho thấy
plugin **không** kích hoạt deprecation nào.

### Controller / query

| Plugin dùng | Nguồn |
|---|---|
| `authorize` | `rm7:app/controllers/application_controller.rb:326` |
| `per_page_option` | `rm7:app/controllers/application_controller.rb:660` |
| `IssueQuery.new(name:, project:)` | `Query < ApplicationRecord` (`rm7:app/models/query.rb:250`) → mass-assignment AR bình thường |
| `query.filters = {}` | `serialize :filters` (`rm7:app/models/query.rb:266`), không có setter tuỳ biến ghi đè |
| `add_filter('issue_id', '=', …)` | `rm7:app/models/query.rb:747`; filter `issue_id` khai báo vô điều kiện tại `rm7:app/models/issue_query.rb:293` |
| `query.issue_count` / `query.issues(offset:, limit:)` / `sort_criteria=` | `rm7:app/models/issue_query.rb:380, 406`; `rm7:app/models/query.rb:909` |
| `Paginator.new(count, per_page, page)` | `rm7:lib/redmine/pagination.rb:22` — deprecation **chỉ** khi tham số đầu là controller instance; plugin truyền 3 giá trị nên sạch |

### View helper

| Plugin dùng | Nguồn |
|---|---|
| `sort_init / sort_update / sort_clause / sort_header_tag / sort_css_classes` | `rm7:app/helpers/sort_helper.rb:68, 83, 99, 146, 159` |
| `custom_field_tag_with_label(name, value, required:)` | `rm7:app/helpers/custom_fields_helper.rb:122`; `:required` được đọc tại `custom_field_label_tag` dòng 111 |
| `issue_fields_rows` (`rows.left` / `rows.right`) | `rm7:app/helpers/issues_helper.rb:366` |
| `delete_link` / `link_to_issue` / `error_messages_for` | `rm7:app/helpers/application_helper.rb:1588, 109, 1567` |
| `sprite_icon` | `rm7:app/helpers/icons_helper.rb:36` |
| `format_time` | `rm7:lib/redmine/i18n.rb:81` |
| `watchers_checkboxes(object, users)` | `rm7:app/helpers/watchers_helper.rb:77` — **diff với 6.1.3 = rỗng**, không đổi gì |
| `f.text_area … no_label: true` | `:no_label` tại `rm7:lib/redmine/views/labelled_form_builder.rb:61`; `text_area` vẫn là alias của `textarea` tại `rails:actionview/lib/action_view/helpers/form_helper.rb:1280` |
| `link_to … remote: true` | core 7.0 vẫn dùng 38 lần trong `app/views/` |
| `link_to … method: :post, data: {confirm:}` | core 7.0 vẫn dùng, ví dụ `rm7:app/views/projects/show.html.erb:10` |
| Toàn bộ khoá i18n mượn từ core | kiểm tự động 15 khoá: 12 khoá có trong `rm7:config/locales/en.yml`; 2 khoá còn lại (`label_select_template`, `label_checklist_template`) thuộc plugin `redmine_checklists` và chỉ chạy sau `checklist_plugin_installed?` |

### JavaScript / asset

Điểm này quan trọng vì Redmine 7 dùng importmap + Stimulus:

- **jQuery vẫn được ship**: `rm7:app/assets/javascripts/jquery-3.7.1-ui-1.13.3.js`.
- **SJR (`.js.erb`) vẫn dùng**: core 7.0 còn **64 file** `.js.erb` trong
  `app/views/`, đều viết bằng `$(...)`.
  → `app/views/periodictask/customfields.js.erb` (dùng `$('#issue_custom_fields').html(...)`) vẫn hợp lệ.
- **Tích hợp watcher picker vẫn khớp**: `rm7:app/views/watchers/append.js.erb`
  vẫn append vào `#watchers_inputs` và vẫn sinh input tên
  `issue[watcher_user_ids][]` (hardcode tại `watchers_helper.rb:80`) — đúng như
  giả định của workaround trong `_form.html.erb:157-159`. Hành vi này **y hệt
  6.1.3**.
- Plugin không có thư mục `assets/` nên không dính thay đổi
  `public/javascripts` → `app/assets/javascripts`.

### Migration / test

| Plugin dùng | Nguồn |
|---|---|
| `ActiveRecord::Migration[4.2]` (14 migration) | `V4_2` vẫn được định nghĩa tại `rails:activerecord/lib/active_record/migration/compatibility.rb:428`, **không** kèm deprecation |
| `Redmine::Plugin::Migrator` chạy migration plugin | `rm7:lib/redmine/plugin.rb:485,525` |
| `ActiveRecord::FixtureSet.create_fixtures(dir, names)` | `rails:activerecord/lib/active_record/fixtures.rb:595` |
| `ActionController::TestCase` (2 file functional) | core 7.0 vẫn kế thừa từ nó: `rm7:test/test_helper.rb:380` |
| `attribute :custom_field_values, :json` | type `:json` đăng ký tại `rails:activerecord/lib/active_record/type.rb:78` |
| `business_time 0.13.0` | phụ thuộc runtime chỉ gồm `activesupport >= 3.2.0` + `tzinfo` (API rubygems.org) → Rails 8.1.3 thoả |

Plugin **không** dùng thứ nào bị 7.0 xoá: `render_if_exist` (Patch #43321) và
`addable_watcher_users` (Patch #43429) — grep xác nhận không xuất hiện.

## E. Trạng thái xử lý

Đã làm:

1. **Sửa icon** (mục A) — 3 view.
   - `_issue_periodictask_link.html.erb`: span rỗng → `sprite_icon('reload')`,
     bọc `if respond_to?(:sprite_icon)` để R5.1 vẫn dùng đường CSS cũ. Ở đây
     **bắt buộc dùng `sprite_icon` chứ không phải helper của plugin**, vì
     Redmine đặt `config.action_controller.include_all_helpers = false`
     (`rm7:config/application.rb:73`) nên `PeriodictaskHelper` không có mặt
     trong view của `IssuesController`; `IconsHelper` thì có, do
     `ApplicationController` khai báo `helper :icons`
     (`rm7:app/controllers/application_controller.rb:35`).
   - `show.html.erb` + `_form.html.erb`: dùng
     `periodictask_sprite_icon('warning', …)`. **Không dùng tên `'error'`** —
     sprite 7.0 không có `icon--error`; chính core map `error` → `warning`
     (`rm7:app/helpers/icons_helper.rb:98-99`).
2. **Thêm `7.0-bookworm` vào ma trận CI** (`.github/workflows/test.yml`).
3. **Thêm cột `7.0` vào bảng hỗ trợ phiên bản trong README.**

Chưa làm (chờ quyết định): dọn code tương thích R5 ở mục B — chỉ nên làm nếu bỏ
hỗ trợ 5.1.

### Mức xác thực của các thay đổi trên

| Đã xác thực | Cách |
|---|---|
| Tên icon `reload`, `warning` tồn tại trong sprite 7.0 | grep `id="icon--…"` trong `rm7:app/assets/images/icons.svg` |
| `sprite_icon` dùng được trong view của IssuesController | `rm7:app/controllers/application_controller.rb:35` (`helper :icons`) |
| ERB compile được sau khi sửa | erubi 1.13.1 + `RubyVM::InstructionSequence.compile` trên `_issue_periodictask_link.html.erb` và `show.html.erb` → OK |
| Sửa `_form.html.erb` không làm hỏng cú pháp | erubi báo lỗi **giống hệt nhau** ở bản gốc và bản sửa (dòng 9, `<%= label(…) do %>` — construct mà Rails xử lý qua `BlockAwareEscape`, checker rời không mô phỏng được) |
| YAML workflow hợp lệ, ma trận đúng 4 bản | `YAML.load_file` |
| Bảng README cân cột | đếm `<td>` từng hàng: 9 cột phiên bản, 3 hàng nhánh × 10 ô |

**Chưa xác thực:** test suite chưa chạy trên Redmine 7.0 — môi trường phát triển
không có Docker khả dụng, và GitHub Actions đang tắt trên fork này nên CI cũng
không chạy. Muốn có bằng chứng thật, chạy:

```bash
docker build -f Dockerfile.test --build-arg REDMINE_TAG=7.0-bookworm -t periodictask-test .
docker run --rm periodictask-test
```
