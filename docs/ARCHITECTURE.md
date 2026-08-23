# Architecture

## Mục tiêu

Giữ code đủ rõ để học và mở rộng, nhưng không tạo nhiều lớp trung gian khi
business logic còn đơn giản.

## Luồng chính

```text
Page -> Notifier -> Repository -> DataSource -> NestJS API
```

- `Page`: hiển thị và nhận thao tác.
- `Notifier`: giữ state của màn hình và điều phối action.
- `Repository`: contract mà presentation sử dụng.
- `DataSource`: gọi Dio và parse model từ API.
- `NestJS`: giữ business rule, giá, tính tiền và công nợ.

## Cấu trúc

```text
lib/
├── app/                 # Root app và router
├── core/                # Config, network, error, storage, theme
├── features/            # Module theo nghiệp vụ
│   ├── home/
│   ├── order_intake/
│   ├── orders/
│   └── products/
└── shared/widgets/      # Widget dùng lại giữa nhiều feature

backend/
├── prisma/              # Schema và migrations PostgreSQL
└── src/
    ├── order-intake/    # Vision extraction, catalog matching và draft invoice
    ├── prisma/          # Database client
    └── products/        # Controller, service và DTO
```

Khi một feature có data thật:

```text
features/products/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   └── repositories/
└── presentation/
    ├── notifier/
    ├── pages/
    └── widgets/
```

## Khi nào cần UseCase?

Không cần UseCase cho CRUD đơn giản. Chỉ tạo khi có flow nghiệp vụ đáng kể,
ví dụ:

- `AnalyzeOrderImage`
- `ConfirmOrder`
- `RecordPayment`
- `LearnProductAlias`

## Quy tắc quan trọng

1. Không gọi OpenAI trực tiếp từ Flutter.
2. Flutter không quyết định giá hoặc công nợ cuối cùng.
3. Backend luôn tính lại subtotal, total và debt.
4. Tiền VND dùng số nguyên, không dùng `double`.
5. Một màn hình chỉ có một hành động chính nổi bật.

## Vertical slice đã hoàn thành

```text
ProductListPage
  -> ProductListNotifier
  -> ProductRepository
  -> ProductRemoteDataSource
  -> GET/POST/PATCH/DELETE /api/products
  -> ProductsService
  -> Prisma Product
  -> PostgreSQL
```

## Image intake đã hoàn thành

```text
OrderIntakePage
  -> OrderIntakeNotifier
  -> OrderImagePicker (camera/gallery + compress)
  -> OrderIntakeRepository
  -> OrderIntakeRemoteDataSource
  -> POST /api/order-intake/analyze
  -> OrderImagePipe (8 MB + magic bytes)
  -> VisionService (OpenAI Structured Outputs)
  -> OrderResolutionService (exact/fuzzy catalog match)
  -> Prisma Product (unit + price)
  -> draft invoice response
  -> InvoicePage (customer invoice table)
  -> RepaintBoundary -> PNG -> native share sheet
```

`VisionService` chỉ đọc dữ liệu thô trong ảnh và không biết danh mục hoặc giá.
Sau đó `OrderResolutionService` chạy bằng code backend: match theo tên + đơn vị,
đọc giá từ PostgreSQL và tính thành tiền. Flutter hiển thị bảng review sáu cột
nghiệp vụ, panel gợi ý và thanh tạm tính; lựa chọn/chỉnh sửa của người dùng được
gửi lại backend để resolve toàn đơn. Ảnh minh họa theo từng sản phẩm chưa nằm
trong data model hiện tại.

Khi `allMatched = true`, nút xác nhận mở `InvoicePage`. Màn hình này chỉ trình
bày `unitPrice`, `lineTotal` và `invoiceTotal` đã được backend trả về; Flutter
không tự tìm giá hoặc tính lại tổng. Phần nội dung hóa đơn được bọc bằng
`RepaintBoundary` để xuất PNG và chia sẻ qua share sheet hệ điều hành, đồng thời
có bản text để sao chép. Hiện thao tác này chưa tạo record `Order`, `Payment`
hoặc `DebtEntry`; persistence vẫn thuộc Giai đoạn 4.

`Product` có khóa unique `(normalizedName, normalizedUnit)`, vì cùng một tên
hàng có thể được bán theo nhiều đơn vị khác nhau. Tiền và tổng hóa đơn vẫn là số
nguyên VND.

## Tạo danh mục từ ảnh đơn

```text
ProductListPage -> CatalogScanPage
  -> OrderImagePicker + POST /api/order-intake/analyze
  -> VisionService đọc tên/đơn vị/đơn giá có thật trong ảnh
  -> OrderResolutionService đối chiếu Product
  -> user xác nhận dòng gần giống và bổ sung trường thiếu
  -> POST /api/products/bulk
  -> ProductsService kiểm tra trùng + Prisma transaction
```

Dòng `matched` không xuất hiện trong danh sách thêm. Dòng `review` không được
thêm cho tới khi người dùng xác nhận đây là hàng mới; lựa chọn candidate nghĩa
là hàng đã có và được bỏ qua. `unitPrice` từ Vision chỉ là giá được ghi rõ trong
ảnh, không phải giá AI suy đoán và không thay thế giá hiện hành trong database.
