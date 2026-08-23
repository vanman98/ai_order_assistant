# Implementation Plan

Tài liệu này là bản đồ tổng thể để phát triển AI Order Assistant theo từng
vertical slice. Mỗi giai đoạn phải chạy được từ UI tới database trước khi mở
rộng sang giai đoạn tiếp theo.

## Nguyên tắc thực hiện

1. Ưu tiên flow thật hơn số lượng màn hình.
2. Flutter chỉ hiển thị và nhận thao tác; backend giữ business rule.
3. AI chỉ đọc ảnh và trích xuất dữ liệu, không tính tiền hoặc công nợ.
4. Tiền VND luôn là số nguyên.
5. Mỗi giai đoạn đều phải có analyze, test và build smoke check.
6. Sau mỗi lượt làm việc phải cập nhật `docs/PROGRESS_LOG.md`.

## Giai đoạn 0 — Base Flutter

Trạng thái: Hoàn thành.

- Project Flutter sạch.
- Riverpod, GoRouter, Dio và Secure Storage.
- Error mapping và theme chữ lớn.
- Home có bốn hành động chính.
- iOS camera/photo permissions.
- Analyzer, widget test và iOS Simulator build chạy thành công.

## Giai đoạn 1 — Products vertical slice

Trạng thái: Hoàn thành ngày 2026-08-13.

### Mục tiêu

Hoàn thành luồng đầu tiên:

```text
ProductListPage
  -> ProductListNotifier
  -> ProductRepository
  -> ProductRemoteDataSource
  -> NestJS ProductsController
  -> ProductsService
  -> Prisma
  -> PostgreSQL
```

### Backend

- Dựng NestJS modular monolith.
- Thêm `GET /api/health`.
- Dựng PostgreSQL bằng Docker Compose.
- Tạo Prisma `Product` model.
- API danh sách/tìm kiếm/thêm/sửa/xóa sản phẩm.
- Validate tên và giá ở server.
- Product không có trạng thái; `DELETE` xóa record thật sau xác nhận.
- Test hàm chuẩn hóa tên sản phẩm.

### Flutter

- Entity, model, datasource, repository và providers.
- AsyncNotifier quản lý loading/error/data.
- Danh sách và tìm kiếm sản phẩm.
- Form thêm/sửa sản phẩm.
- Xác nhận trước khi xóa sản phẩm.
- Hiển thị tiền VND rõ ràng.
- Widget test dùng fake repository, không phụ thuộc backend thật.
- Danh mục hiển thị bảng bốn cột **Tên hàng – Đơn vị – Giá bán – Thao tác**;
  không có ảnh, trạng thái hoặc nhập Excel.

### Definition of done

- Backend build và test pass.
- Prisma schema validate và migration chạy được.
- Flutter analyze/test pass.
- iOS Simulator build pass.
- Có thể CRUD sản phẩm khi backend/database đang chạy.

## Giai đoạn 2 — Image intake và Vision AI

Trạng thái: Hoàn thành phần triển khai và kiểm tra tự động ngày 2026-08-15.
`OPENAI_API_KEY` đã được cấu hình trong `backend/.env`; live smoke test với
OpenAI đang chờ một ảnh đơn mẫu đã ẩn thông tin nhạy cảm.

### Mục tiêu

```text
Camera/Gallery -> Compress -> Multipart upload -> Vision AI -> Structured JSON
```

### Đã hoàn thành

- `image_picker` cho camera/gallery và `flutter_image_compress` nén về JPEG
  trong thư mục tạm trước khi upload.
- Preview, chụp lại/chọn lại và thông báo lỗi chuẩn bị ảnh.
- Multipart upload bằng Dio với progress, timeout, retry dùng lại ảnh đã nén và
  cancel token thật.
- Backend chỉ nhận một file multipart trường `image`, tối đa 8 MB.
- Backend kiểm tra magic bytes và chỉ chấp nhận JPEG, PNG hoặc WebP; không tin
  MIME type do client gửi.
- OpenAI Responses API nhận ảnh base64 ở backend; key không tồn tại trong
  Flutter hay `dart-define`.
- Structured Outputs dùng Zod với từng item gồm `rawText`,
  `rawProductName`, `quantity`, `unit`, `unitPrice`, `note`, `needsReview` và
  `uncertaintyReason`.
- Prompt cấm AI match danh mục, lấy giá hoặc tính tiền; UI cũng ghi rõ kết quả
  AI là dữ liệu thô; bước backend riêng mới đối chiếu danh mục và tính tiền.
- Unit tests bao phủ magic bytes/kích thước/schema/backend-key guard và phía
  Flutter bao phủ parse result/progress/retry/cancel.

### Còn cần xác nhận thủ công

- Giữ `OPENAI_API_KEY` trong `backend/.env`, không commit file này.
- Chạy live smoke test với ảnh đơn thật đã ẩn tên, số điện thoại và địa chỉ.
- Bổ sung bộ ảnh test an toàn sau khi có dữ liệu mẫu được phép sử dụng.

### Ghi chú môi trường iOS

- Flutter stable đã nâng lên `3.47.0`; iOS deployment target là 15.0.
- Debug/JIT qua USB trên iPhone iOS 26.5 hiện có thể crash với
  `EXC_BAD_ACCESS code=50` trước khi Dart VM Service kết nối. Đây là lỗi
  toolchain/runtime trên thiết bị thật, không phải lỗi API của ứng dụng.
- Dùng iOS Simulator cho hot reload hoặc chạy thiết bị thật bằng Release (AOT).
  Bản Release trên iPhone và iOS Simulator debug build đã được xác nhận.

## Giai đoạn 3 — Matching, review và alias learning

Trạng thái: Đã hoàn thành matching theo tên/đơn vị, review ba trạng thái và hóa
đơn nháp ngày 2026-08-18. Alias learning và chuẩn hóa quy cách nâng cao còn chờ.

- [ ] Chuẩn hóa quy cách nâng cao như `3k6 -> 3.6kg`.
- [ ] Ưu tiên alias exact và chỉ lưu alias sau khi user xác nhận.
- [x] Exact product theo tên + đơn vị, sau đó fuzzy match.
- [x] Trả tối đa 3 candidates.
- [x] Review theo ba trạng thái xanh/vàng/đỏ.
- [x] UI review sáu cột, panel candidates, chọn toàn danh mục và thanh tạm tính.
- [x] Bảng dùng tỷ lệ cột responsive, luôn fit iPhone và wrap tên thay vì cuộn ngang.
- [x] Bỏ ảnh minh họa sản phẩm cho đến khi có product image data model.
- [x] Cho sửa tên, số lượng, đơn vị và giá ngay sau khi đọc ảnh.
- [x] Thêm sản phẩm thiếu vào danh mục rồi resolve lại toàn đơn.
- [x] Tự tạo hóa đơn nháp và tổng tiền khi mọi dòng đã match.
- [x] Nút xác nhận mở hóa đơn khách hàng dạng bảng, không còn cột trạng thái.
- [x] Xuất toàn bộ hóa đơn thành PNG để chia sẻ và hỗ trợ sao chép dạng text.
- [x] Từ Danh mục, chụp/chọn ảnh đơn để phát hiện và thêm hàng còn thiếu.
- [x] Điền sẵn tên/đơn vị/đơn giá có rõ trong ảnh; không để AI đoán giá.
- [x] Bắt buộc xác nhận candidate gần giống và thêm nhiều sản phẩm bằng một
  database transaction có kiểm tra trùng.

## Giai đoạn 4 — Customers, orders và payments

- Customer: tên và công nợ.
- Persist hóa đơn hiện tại thành Order khi confirm, dùng `clientRequestId`
  chống tạo trùng. Màn hình/ảnh hóa đơn ở Giai đoạn 3 hiện chưa ghi database.
- Backend tự lấy giá hiện hành và lưu price snapshot.
- Tính subtotal/total bằng code.
- Thanh toán đủ, một phần hoặc ghi nợ.
- Order, Payment và DebtEntry chạy trong một database transaction.
- Danh sách đơn hôm nay và chi tiết đơn.

## Giai đoạn 5 — Hardening và TestFlight

- Auth đăng nhập một lần và refresh session.
- Backup/export dữ liệu.
- Crash reporting production.
- Test trên iPhone thật với ảnh đơn thật.
- Kiểm tra Dynamic Type, VoiceOver, button size và contrast.
- Đo KPI xử lý một đơn dưới 60 giây.
- Đổi Bundle ID, app icon và ký TestFlight.

## Thứ tự ưu tiên hiện tại

1. Chạy end-to-end luồng quét danh mục trên iPhone Release với các ảnh đơn mẫu
   an toàn và đo tỷ lệ tên/đơn vị/giá cần sửa.
2. Hoàn thiện alias learning và chuẩn hóa quy cách nâng cao.
3. Bắt đầu Giai đoạn 4: lưu/xác nhận đơn, thanh toán và công nợ.
