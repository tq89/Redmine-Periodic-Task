# CLAUDE.md

Hướng dẫn cho Claude Code khi làm việc trong repo này.

## Đọc trước khi làm

- `docs/repo-structure.md` — bản đồ toàn repo: cây thư mục, schema, luồng
  chính, các bẫy tương thích. **Bắt buộc cập nhật trong CÙNG commit** khi thay
  đổi cấu trúc: thêm/xoá/đổi vai trò file, đổi schema (migration), đổi route,
  đổi luồng scheduler. Sửa nội dung bên trong một hàm mà không đổi cấu trúc thì
  không cần đụng tới. Có Stop hook
  (`.claude/hooks/check-repo-structure-sync.sh`) nhắc khi quên — chỉ nhắc,
  không chặn.
- `docs/lessons.md` — bài học từ các session trước.

## Quy trình làm việc

1. **Plan trước, code sau.** Hiểu rõ yêu cầu, lên plan chi tiết trước khi viết
   code. Sai hướng giữa chừng → dừng, plan lại. Không cố đấm ăn xôi.

2. **Delegate việc nặng cho Sub-Agent.** Việc phức tạp (đọc nhiều file,
   research, migration lớn) → giao Sub-Agent, giữ context chính sạch.

3. **Self-improving loop.** Bài học quan trọng → ghi `docs/lessons.md`. Session
   sau đọc lại trước khi làm.

4. **Prove it works.** Chưa build/test/đọc log → chưa xong. Sau mỗi thay đổi:
   build → test → đọc output. Chỉ mark done khi có bằng chứng.

5. **Self-fix bugs.** Gặp bug → đọc log tìm root cause → fix ngay trong cùng
   session. Không báo bug mà không kèm bản vá.

6. **Comment bằng TIẾNG VIỆT (mặc định) cho code mới** (Ruby/Rails). Chuỗi hiển
   thị cho user vẫn qua i18n (`config/locales/*.yml`), không hard-code.

7. **YAGNI.** Chỉ làm đúng cái được yêu cầu ngay bây giờ. Không thêm
   field/option/abstraction/"điểm mở rộng" chưa cần; không generalize/tối ưu
   sớm; phân vân giữa gọn và "linh hoạt" → chọn gọn.

8. **Chức năng mới → đánh giá tổng thể, chờ Quí xác nhận rồi mới code.** Mỗi khi
   Quí yêu cầu thêm một chức năng mới, KHÔNG implement ngay. Trước tiên trình
   bày ngắn gọn (không lan man):
   - **Tác động tổng thể:** chức năng đụng phần nào của kiến trúc plugin
     (model / controller / view / migration / scheduler); có phá tương thích
     với các bản Redmine đang hỗ trợ không.
   - **Phương án tối ưu (khuyến nghị):** cách đơn giản nhất chạy đúng theo
     YAGNI, kèm đánh đổi và (nếu có) 1–2 phương án loại + lý do loại.
   - **Câu hỏi chốt:** nếu còn điểm mơ hồ ảnh hưởng hướng làm → hỏi thẳng.

   Chỉ bắt đầu code SAU KHI Quí xác nhận hướng. Sửa lỗi nhỏ / việc đã rõ trong
   phạm vi đã chốt thì làm luôn (§5); quy tắc này chỉ áp cho chức năng mới.

## Kiểm chứng (phục vụ §4)

```bash
# Lint
rubocop

# Build image test rồi chạy test của plugin
docker build -f Dockerfile.test --build-arg REDMINE_TAG=6.1-bookworm -t periodictask-test .
docker run --rm periodictask-test

# Unit test chạy độc lập
docker run --rm periodictask-test bundle exec ruby plugins/periodictask/test/unit/get_next_run_date_test.rb
docker run --rm periodictask-test bundle exec ruby plugins/periodictask/test/unit/timezone_test.rb
```

CI chạy test trên các bản Redmine `5.1-bookworm`, `6.0-bookworm`, `6.1-bookworm`
(xem `.github/workflows/test.yml`). Chạy dev server: `docker compose up --build`.
