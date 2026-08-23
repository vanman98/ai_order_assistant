# AI Order Assistant

Ứng dụng Flutter nội bộ giúp xử lý đơn hàng từ ảnh: đọc nội dung bằng AI,
đối chiếu danh mục sản phẩm, tính tiền bằng code và theo dõi công nợ.

## Mục tiêu hiện tại

Base source hiện có:

- Riverpod cho state management và dependency injection.
- GoRouter cho navigation.
- Dio cho REST API và multipart upload.
- Secure Storage cho access/refresh token.
- Error mapping dùng chung.
- Theme chữ lớn và Home với bốn hành động chính.
- Feature-first Clean Architecture Lite.
- NestJS + Prisma + PostgreSQL backend.
- Products vertical slice từ Flutter tới database.

Chưa có Firebase, Xcode flavor hoặc AI key trên mobile.

## Chạy project

Terminal 1 — database và backend:

```bash
make db-up
make backend-install
make backend-migrate
make backend-dev
```

Terminal 2 — Flutter:

```bash
flutter pub get
make dev
```

Hoặc:

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://192.168.1.197:3000/api \
  --dart-define=ENABLE_LOGGING=true
```

## Kiểm tra chất lượng

```bash
make check
```

## Luồng Products đã triển khai

Feature đầu tiên là `products`, triển khai xuyên suốt:

```text
ProductListPage
  -> ProductListNotifier
  -> ProductRepository
  -> ProductRemoteDataSource
  -> NestJS Products API
  -> Prisma/PostgreSQL
```

API:

```text
GET    /api/health
GET    /api/products?q=
POST   /api/products
POST   /api/products/bulk
PATCH  /api/products/:id
DELETE /api/products/:id
```

`DELETE` xóa sản phẩm khỏi danh mục. Product không có trạng thái active/inactive;
một sản phẩm tồn tại trong danh mục cho tới khi người dùng chủ động xóa.
Từ màn hình Danh mục, **QUÉT ĐƠN AI** cho phép chụp/chọn ảnh, bỏ qua hàng đã
có, xác nhận hàng gần giống và thêm tối đa 100 sản phẩm mới trong một
transaction.

Sau khi mọi dòng trong ảnh đã khớp danh mục, **XÁC NHẬN** mở hóa đơn khách hàng
đầy đủ đơn giá, thành tiền và tổng cộng do backend tính. Hóa đơn có thể sao chép
dạng text hoặc xuất PNG qua share sheet của iOS/Android. Phiên bản hiện tại chưa
lưu Order/Payment/công nợ; đó là bước tiếp theo của Phase 4.

Xem [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) và
[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).

Nhật ký những gì đã làm sau từng lượt nằm tại
[docs/PROGRESS_LOG.md](docs/PROGRESS_LOG.md).
