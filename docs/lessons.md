# Lessons

Ghi lại bài học quan trọng rút ra trong lúc làm việc (§3 của `CLAUDE.md`).
Đọc file này trước khi bắt đầu session mới.

Định dạng mỗi mục: bối cảnh → điều đã sai / đã học → cách làm đúng lần sau.

## 2026-07-27 — grep source lạ: xác nhận chủ sở hữu trước khi kết luận

Bối cảnh: đối chiếu plugin với source Redmine 7.0.

Hai lần suýt báo sai:

1. `grep -n "def initialize" app/models/query.rb` trả về dòng 26 với chữ ký
   `initialize(name, options={})`. Suýt kết luận `IssueQuery.new(name:, project:)`
   của plugin là sai. Thực tế dòng 26 thuộc `class QueryColumn`; `class Query <
   ApplicationRecord` mãi ở dòng 250 → mass-assignment AR hoàn toàn hợp lệ.
2. Grep `id="add"` trong `icons.svg` không ra gì → suýt báo "icon không tồn
   tại". Thực tế id có tiền tố `icon--`, do `svg_sprite_icon` tự ghép.

Cách làm đúng: sau khi grep ra một `def`, **luôn** kiểm class/module bao quanh
nó (`grep -n "^class \|^module "` rồi so số dòng) trước khi kết luận về chữ ký.
Với chuỗi định danh (id, tên icon, tên khoá), tìm chỗ **sinh ra** chuỗi đó thay
vì đoán dạng đầy đủ.

Ngoài ra: một tên xuất hiện trong view chưa chắc là hàm — `watchers_form` và
`watchers_inputs` trong plugin là **id HTML**, không phải helper. Kiểm bằng cách
xem chính dòng gọi, đừng chỉ grep `def <tên>`.
