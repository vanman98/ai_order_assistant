# Progress Log

File này ghi lại những gì đã hoàn thành sau từng lượt làm việc để có thể đọc
nhanh mà không cần xem lại toàn bộ cuộc trò chuyện.

## Cách cập nhật

Mỗi lượt thêm một mục mới gồm:

- Mục tiêu.
- Quyết định quan trọng.
- Việc đã làm và file chính.
- Kết quả kiểm tra.
- Việc tiếp theo.

Không xóa lịch sử cũ; nếu quyết định thay đổi, thêm ghi chú mới giải thích lý do.

---

## 2026-08-12 — Phân tích sản phẩm và kiến trúc

### Mục tiêu

Phân tích app xử lý đơn từ ảnh Zalo và chọn kiến trúc phù hợp.

### Quyết định

- Flutter cho iPhone.
- NestJS + Prisma + PostgreSQL tương tự backend mới của app Etsy.
- AI chỉ đọc ảnh; code backend match hàng, lấy giá, tính tiền và công nợ.
- Không clone nguyên source Etsy vì chứa Firebase, web, subscription và legacy.

### Kết quả

Đã xác định module, data model, API tối thiểu và roadmap MVP.

---

## 2026-08-12 — Audit riverpod_clean_architecture

### Mục tiêu

Đánh giá có nên dùng nguyên base Riverpod cũ hay không.

### Phát hiện

- Analyzer có 12 thông báo.
- Widget test mặc định thất bại.
- iOS flavor/scheme không khớp nên build thất bại.
- Auth chưa restore session/refresh token.
- ApiClient chưa có multipart/PATCH/DELETE.
- Mason brick chỉ chứa file rỗng.

### Quyết định

Tạo Flutter project mới và chỉ mang các pattern tốt sang theo Clean
Architecture Lite.

---

## 2026-08-13 — Dựng base Flutter mới

### Mục tiêu

Dựng nền móng sạch trong project `ai_order_assistant`.

### Đã làm

- Riverpod, GoRouter, Dio, Secure Storage.
- Config qua `dart-define`.
- Error mapping, theme chữ lớn và shared widgets.
- Home với bốn hành động chính.
- Route placeholder cho chụp đơn, ảnh, đơn hôm nay và sản phẩm.
- Camera/Photo Library permissions trên iOS.
- Tài liệu `ARCHITECTURE.md` và `START_HERE.md`.

### Kiểm tra

- `flutter analyze`: pass.
- `flutter test`: 2 tests pass.
- iOS Simulator debug build: pass.

### Việc tiếp theo

Hoàn thành Products vertical slice từ Flutter tới PostgreSQL.

---

## 2026-08-13 — Products vertical slice

Trạng thái: Hoàn thành.

### Mục tiêu

Dựng backend base và hoàn thành CRUD sản phẩm end-to-end.

### Đã làm — tài liệu

- Tạo `docs/IMPLEMENTATION_PLAN.md` làm roadmap tổng thể.
- Tạo file progress này và tổng hợp các lượt làm việc trước.

### Đã làm — backend

- Tạo NestJS modular monolith trong `backend/`.
- PostgreSQL 16 bằng Docker Compose, port `5434`.
- Prisma `Product` model và migration `init_products`.
- `GET /api/health`.
- Products API: list/search/create/update/soft-delete.
- Chuẩn hóa tên tiếng Việt để tìm kiếm.
- Khi thêm lại sản phẩm đã ngừng dùng, backend kích hoạt lại record cũ.

### Đã làm — Flutter

- Product entity, model, datasource, repository và providers.
- `ProductListNotifier` quản lý loading/error/data.
- Danh sách, tìm kiếm, thêm, sửa và ngừng dùng sản phẩm.
- Nút có text rõ ràng, font/giá lớn, không dùng menu hoặc gesture ẩn.
- Currency formatter VND.
- Widget tests dùng fake repository, không gọi backend thật.

### Kiểm tra

- `npm audit`: 0 vulnerabilities.
- Backend build: pass.
- Backend tests: 3 tests pass.
- Prisma migration: applied successfully.
- HTTP smoke test create/search/update/archive: pass.
- Reactivate sản phẩm đã archive: pass và giữ nguyên record ID.
- `flutter analyze`: no issues.
- Flutter tests: 4 tests pass.
- iOS Simulator build: pass.

### Ghi chú Docker

Hai thư mục backend ban đầu bị trùng Docker Compose project name mặc định.
Container ListBoost bị thay tạm thời nhưng volume `backend_pgdata` không bị xóa.
Đã khắc phục bằng project name riêng `ai-order-assistant` và xác nhận:

- `listboost-db` chạy lại với volume `backend_pgdata`.
- `ai-order-assistant-db` chạy riêng với volume
  `ai_order_assistant_postgres_data`.

### Trạng thái service khi kết thúc

- PostgreSQL container đang chạy.
- NestJS process smoke-test đã dừng.
- Danh sách sản phẩm active trong database đang rỗng; record test đã soft-delete.

### Việc tiếp theo

Giai đoạn 2: chọn/chụp ảnh, preview/nén ảnh và upload multipart. Sau đó mới tích
hợp Vision AI structured output ở backend.

---

## 2026-08-15 — Phase 2 Image intake và Vision AI

Trạng thái: Hoàn thành phần code và kiểm tra tự động; live OpenAI smoke test chờ
key backend và ảnh mẫu an toàn.

### Mục tiêu

Hoàn thành luồng camera/gallery → preview → compress → multipart upload →
backend validation → OpenAI Vision → structured JSON.

### Review staging

- Chỉ dùng staging làm nguồn tham khảo, không chép đè nguyên thư mục.
- Giữ thiết kế memory upload, magic-byte validation, Zod schema và Responses
  API.
- Hạ OpenAI SDK từ staging `7.4.0` xuống `6.49.0` vì bản 7 yêu cầu Node 22,
  trong khi backend hiện dùng Node 20.
- Gia cố validation theo `buffer.length` thực tế và dùng HTTP 413 cho ảnh quá
  8 MB.

### Đã làm — backend

- Thêm module `order-intake` với:
  - `POST /api/order-intake/validate-image`.
  - `POST /api/order-intake/analyze`.
- Chỉ nhận JPEG/PNG/WebP tối đa 8 MB và xác định MIME bằng magic bytes.
- Tích hợp OpenAI Responses API với ảnh base64 và Zod Structured Outputs.
- Structured item có đủ `rawText`, `rawProductName`, `quantity`, `unit`,
  `note`, `needsReview`, `uncertaintyReason`.
- Prompt chỉ cho phép chép dữ liệu trong ảnh; cấm match sản phẩm, lấy giá và
  tính tiền.
- `OPENAI_API_KEY` chỉ được đọc ở backend; `.env.example` có placeholder và
  `backend/.env` tiếp tục được gitignore.

### Đã làm — Flutter

- Camera/gallery bằng `image_picker`.
- Nén về JPEG chất lượng 82, cạnh mục tiêu 2200 px, bỏ EXIF và kiểm tra lại
  giới hạn 8 MB trước upload.
- Preview và chụp lại/chọn lại.
- Dio multipart upload với progress, timeout, retry và cancel token.
- State chống race khi cancel rồi upload lại ngay.
- Hiển thị dữ liệu AI thô và cảnh báo từng dòng cần review; không dùng danh mục
  sản phẩm, không hiển thị giá và không tính tiền.
- Error mapping coi 413/415/422 là lỗi validation và cho retry với timeout,
  rate-limit hoặc lỗi server.

### iOS

- Giữ quyền Camera và Photo Library trong `Info.plist`.
- Đặt CocoaPods deployment target iOS 15.
- Dùng static modular Pods để plugin nén ảnh build ổn định trên Simulator.

### Kiểm tra

- `npm audit`: 0 vulnerabilities.
- Backend tests: 5 suites, 11 tests pass.
- Backend build: pass.
- `flutter analyze`: no issues.
- Flutter tests: 8 tests pass.
- iOS Simulator debug build: pass.

- Chưa gọi live OpenAI vì repo chưa có ảnh đơn mẫu đã được phép sử dụng. Key
  backend đã được cấu hình ngày 2026-08-18 và vẫn nằm ngoài Git.

### Việc tiếp theo

1. Người vận hành tự thêm key vào `backend/.env`.
2. Chạy live smoke test với ảnh đơn đã ẩn thông tin nhạy cảm.
3. Bắt đầu Phase 3 sau khi xác nhận chất lượng structured extraction.

---

## 2026-08-18 — Chẩn đoán chạy app trên iPhone iOS 26.5

### Kết quả

- Tái hiện lỗi Flutter CLI không kết nối được Dart VM Service trên iPhone thật.
- Crash report từ thiết bị xác nhận `EXC_BAD_ACCESS code=50`, `SIGBUS` trong
  vùng Dart JIT; lỗi WebSocket `127.0.0.1` chỉ là hậu quả sau khi Runner crash.
- Loại trừ backend, API base URL, quyền Local Network và USB pairing là nguyên
  nhân của crash Debug.
- Nâng Flutter stable từ `3.38.5` lên `3.47.0`, chạy migration UIScene/Swift
  Package Manager do Flutter tạo và nâng deployment target lên iOS 15.
- Debug/JIT trên thiết bị iOS 26.5 vẫn chịu lỗi runtime đã biết; bản Release/AOT
  cài, launch và giữ tiến trình ổn định trên iPhone.

### Kiểm tra

- `flutter analyze`: no issues.
- Flutter tests: 8 tests pass.
- iOS Simulator debug build: pass.
- iPhone Release build/install/launch: pass.
- PostgreSQL container chạy; Prisma không có migration chờ áp dụng.
- Backend health trả `200` qua cả localhost và
  `http://192.168.1.197:3000/api/health`.

### Cách chạy hiện tại

- Dùng iOS Simulator ở Debug khi cần hot reload.
- Dùng `flutter run --release` trên iPhone thật để test camera/gallery và API.
- Có thể thử launch trực tiếp từ Xcode; không dùng lỗi Dart VM Service để kết
  luận backend bị hỏng.

---

## 2026-08-18 — Matching danh mục và hóa đơn nháp sau Vision

Trạng thái: Hoàn thành phần matching/review và bảng hóa đơn nháp.

### Mục tiêu

Sau khi AI đọc ảnh, tự đối chiếu từng dòng với danh mục. Sản phẩm thiếu phải có
thể thêm ngay; khi tất cả dòng đã khớp thì hiển thị giá, thành tiền và tổng hóa
đơn.

### Quyết định

- OpenAI Vision tiếp tục chỉ chép dữ liệu trong ảnh.
- Matching, lấy giá và phép tính nằm trong `OrderResolutionService` ở backend.
- Product unique theo cặp tên chuẩn hóa + đơn vị chuẩn hóa, không chỉ theo tên.
- Kết quả hiện tại là hóa đơn nháp, chưa ghi Order vào database.

### Đã làm — backend và database

- Bổ sung `unit`, `normalizedUnit` vào Product và migration backfill 61 sản phẩm
  hiện có.
- Products CRUD validate đơn vị và chống trùng `(normalizedName,
  normalizedUnit)`.
- `POST /api/order-intake/analyze` tự resolve kết quả Vision; thêm
  `POST /api/order-intake/resolve` để resolve lại sau thao tác review.
- Exact match theo tên + đơn vị; fuzzy top 3 cho dòng gần giống; sản phẩm lạ
  không được gán giá giả.
- Backend tính `lineTotal`, `invoiceTotal` bằng số nguyên và trả `allMatched`.

### Đã làm — Flutter

- Product form/list/model/repository hỗ trợ đơn vị.
- Kết quả ảnh hiển thị dạng bảng rõ ràng với ba cột **Tên hàng – Đơn vị – Giá**.
- Cột đơn vị hiển thị số lượng × đơn vị; cột giá hiển thị đơn giá và thành tiền.
- Màu xanh/vàng/đỏ phân biệt đã khớp, cần chọn và chưa có trong danh mục.
- Có candidate chip chọn nhanh; chạm dòng để sửa tên, số lượng, đơn vị và giá.
- Dòng chưa có được thêm vào danh mục, sau đó toàn đơn tự resolve/tính lại.
- Khi tất cả dòng đã khớp, UI đổi sang hóa đơn nháp và hiển thị tổng tiền.

### Kiểm tra

- Prisma migration `20260818160000_add_product_unit`: applied; schema up to date.
- Backend test: 6 suites, 14 tests pass.
- Backend build: pass.
- HTTP smoke: exact match Bò Húc 2 lon = 26.000 ₫; sản phẩm lạ giữ trạng thái
  missing và không có giá; invoice tạm tính đúng.
- `flutter analyze`: no issues.
- Flutter tests: 9 tests pass, gồm widget test bảng ba cột và tổng hóa đơn.
- iOS Simulator debug build: pass.

### Việc tiếp theo

1. Test end-to-end trên iPhone Release với một ảnh mẫu.
2. Hoàn thiện alias learning/quy cách viết tắt.
3. Phase 4 lưu/xác nhận Order, thanh toán và công nợ.

---

## 2026-08-22 — Thiết kế lại UI kiểm tra đơn hàng

Trạng thái: Hoàn thành UI theo mockup tham chiếu, chưa dùng ảnh sản phẩm.

### Đã làm

- Sau khi AI trả kết quả, ẩn preview ảnh nguồn và chuyển sang màn hình riêng
  **Kiểm tra đơn hàng**.
- Thêm khối tổng quan số dòng, ảnh đã chọn và nút xác nhận chỉ khả dụng khi mọi
  dòng đã khớp. Nút hiện chỉ báo hóa đơn nháp; chưa ghi Order trước Phase 4.
- Đổi bảng kết quả thành sáu cột: **Mặt hàng, SL, Đơn vị, Giá, Thành tiền, Trạng
  thái**.
- Hiển thị badge xanh/vàng/đỏ cho `matched`, `review`, `missing`.
- Dòng cần xác nhận có panel gợi ý sản phẩm, đơn vị, giá và nút chọn.
- Dòng chưa có có hành động chọn từ toàn bộ danh mục, thêm vào danh mục và sửa
  thông tin. Hộp chọn danh mục hỗ trợ tìm theo tên hoặc đơn vị.
- Thêm thanh tạm tính cố định ở cuối màn hình, chỉ cộng các dòng đã khớp và hiển
  thị số dòng cần xác nhận/chưa có.
- Chưa thêm thumbnail/ảnh minh họa sản phẩm theo yêu cầu hiện tại.
- Thu gọn typography toàn app về thang 14–20 px thông dụng; app bar, button,
  input, card, Home và Product form/list có padding/icon cân đối hơn.
- Thay bảng rộng cố định bằng `FlexColumnWidth`: sáu cột luôn fit chiều rộng
  iPhone, không scroll ngang; tên/đơn vị dài tự wrap trong cột.

### Kiểm tra

- `flutter analyze`: no issues.
- Flutter tests: 9 tests pass; widget test chạy ở viewport iPhone 390×844 xác
  nhận bảng sáu cột không scroll ngang/không overflow, trạng thái, panel gợi ý,
  tạm tính và không render ảnh sản phẩm.
- iOS Simulator debug build: pass.

---

## 2026-08-22 — Thiết kế lại UI danh mục hàng

### Đã làm

- Thay danh sách card bằng bảng bốn cột **Tên hàng – Đơn vị – Giá bán – Thao
  tác** theo mockup tham chiếu.
- Không thêm ảnh sản phẩm, cột trạng thái hoặc chức năng nhập Excel.
- Bảng dùng `FlexColumnWidth`, luôn fit chiều rộng iPhone và không scroll ngang;
  tên hàng/đơn vị/giá dài tự wrap trong cột.
- Cột thao tác có nút **Sửa** và **Xóa**; nút thêm hàng mới cố định phía dưới.
- Ô tìm kiếm chạy debounce 350 ms để tránh gọi API ở mỗi phím nhập liên tục.
- Product form vẫn bắt buộc tên, đơn vị và giá; mọi record trong danh mục đều
  được sử dụng mặc định.

### Kiểm tra

- `flutter analyze`: no issues.
- Flutter tests: 9 tests pass; widget test chạy ở viewport iPhone 390×844 xác
  nhận đủ bốn cột, không trạng thái/Excel/scroll ngang và tên sản phẩm dài không
  gây overflow.
- iOS Simulator debug build: pass.

---

## 2026-08-22 — Bỏ trạng thái sản phẩm và chuyển sang xóa thật

### Quyết định

- Sản phẩm không còn `isActive`; đã nằm trong danh mục nghĩa là được sử dụng lâu
  dài cho đến khi người dùng chủ động xóa.
- `DELETE /api/products/:id` xóa record thật thay vì soft delete.
- Các record đã soft-delete từ phiên bản cũ được chuyển sang bảng
  `legacy_archived_products` để có thể khôi phục thủ công, không đưa trở lại danh
  mục đang dùng.

### Đã làm

- Migration `20260822170000_remove_product_status` bỏ cột `isActive` và index
  liên quan; tạo index theo `name`.
- Products API không còn filter/reactivate theo trạng thái; Order Resolution đọc
  toàn bộ Product hiện có.
- Flutter entity/model/repository/notifier không còn trường hoặc action archive.
- UI đổi nút **Ngừng** thành **Xóa**, dùng icon thùng rác và hộp xác nhận cảnh báo
  không thể hoàn tác.

### Kiểm tra

- Migration đã áp dụng thành công; Prisma báo database schema up to date. Có 1
  record inactive cũ được giữ an toàn trong `legacy_archived_products`.
- Backend: 7 test suites, 15 tests pass; TypeScript build pass.
- Smoke test backend bằng process mới: `GET /api/products` trả danh mục bình
  thường và payload không còn trường `isActive`.
- `flutter analyze`: no issues.
- Flutter tests: 9 tests pass, gồm luồng mở xác nhận rồi xóa sản phẩm.
- iOS Simulator debug build: pass.

---

## 2026-08-23 — Tạo danh mục nhanh từ ảnh đơn hàng

### Mục tiêu

Cho phép người dùng đứng ngay trong Danh mục hàng, chụp/chọn các ảnh đơn cũ và
chỉ bổ sung những sản phẩm chưa có thay vì nhập tay từng dòng.

### Quyết định

- Tái sử dụng toàn bộ pipeline nén/upload/magic-byte validation/Vision và
  catalog matching hiện có.
- AI chỉ đọc `unitPrice` khi đơn giá xuất hiện rõ trong ảnh; không suy đoán giá,
  không lấy giá catalog và không tính tiền.
- Dòng khớp chính xác tự bỏ qua. Dòng gần giống bắt buộc người dùng xác nhận đã
  có hoặc xác nhận là sản phẩm mới để tránh tạo trùng.
- Thêm nhiều sản phẩm qua `POST /api/products/bulk`; backend kiểm tra trùng cả
  trong request lẫn database và ghi toàn bộ bằng một transaction.

### Đã làm

- Thêm nút **QUÉT ĐƠN AI** ở Danh mục, hỗ trợ Camera và Gallery.
- Thêm màn hình preview, upload progress, retry/cancel và kết quả thống kê
  **Đã có – Cần xem – Cần xử lý**.
- Form sản phẩm mới điền sẵn tên, đơn vị và giá đọc được; người dùng bổ sung ô
  còn thiếu, có thể bỏ chọn từng dòng và thêm cả danh sách một lần.
- Cảnh báo candidate gần giống kèm tên, đơn vị, giá để chọn hàng đã có hoặc chủ
  động thêm mới.
- Structured extraction có thêm `unitPrice` nullable và giữ nguyên nguyên tắc
  Vision không tham gia matching/tính tiền.

### Kiểm tra

- Backend: 7 test suites, 17 tests pass; build pass.
- `flutter analyze`: no issues.
- Flutter tests: 10 tests pass, gồm điền sẵn dữ liệu ảnh và bulk create.
- iOS Simulator debug build: pass.

---

## 2026-08-23 — Hoàn thiện hóa đơn khách hàng và xuất ảnh

### Mục tiêu

Hoàn tất bước sau review: khi toàn bộ dòng đã khớp danh mục, người dùng xác nhận
để nhận một hóa đơn rõ ràng, có thể gửi ngay cho khách.

### Đã làm

- Nút **XÁC NHẬN** chỉ bật khi `allMatched = true` và mở màn hình hóa đơn thay
  cho thông báo placeholder trước đây.
- Hóa đơn hiển thị bảng **Mặt hàng – SL/ĐV – Đơn giá – Thành tiền**, tổng cộng
  và thời gian tạo; tên dài tự xuống dòng, không cuộn ngang và không lộ trạng
  thái matching nội bộ.
- Giá từng dòng, thành tiền và tổng cộng dùng nguyên kết quả backend đã đối
  chiếu/tính toán; Flutter và Vision AI không tự quyết định giá.
- Thêm **SAO CHÉP** để lấy hóa đơn dạng text và **CHIA SẺ ẢNH** để render toàn
  bộ nội dung hóa đơn thành PNG rồi mở share sheet native.
- Thêm `share_plus 12.0.2`; nâng Android Gradle Plugin lên 8.12.1 để đáp ứng
  yêu cầu build của plugin.
- Chưa ghi Order, Payment hoặc công nợ vào database; phần persistence và chống
  confirm trùng tiếp tục thuộc Giai đoạn 4.

### Kiểm tra

- Backend: 7 test suites, 17 tests pass; build pass.
- `flutter analyze`: no issues.
- Flutter tests: 12 tests pass, gồm điều hướng từ xác nhận sang hóa đơn và kiểm
  tra bảng hóa đơn fit viewport iPhone.
- iOS Simulator debug build: pass.
- Android debug APK build: pass.
