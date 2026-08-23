# Start Here

## Trước khi chạy trên iPhone thật

- `127.0.0.1` chỉ phù hợp với iOS Simulator. Trên iPhone thật, đổi
  `API_BASE_URL` thành IP LAN của máy chạy backend hoặc URL backend đã deploy.
- Bundle ID hiện vẫn là `com.example.aiOrderAssistant`. Hãy đổi sang Bundle ID
  thuộc Apple Developer account trước khi ký build hoặc đưa lên TestFlight.
- Không đặt OpenAI API key trong `dart-define`; key chỉ tồn tại ở NestJS backend.

## Chạy vertical slice hiện tại

Terminal 1:

```bash
make db-up
make backend-migrate
make backend-dev
```

Terminal 2:

```bash
make dev
```

Sau đó mở **DANH MỤC HÀNG** để thử thêm/sửa/tìm/xóa sản phẩm. Mỗi sản phẩm bắt
buộc có tên, đơn vị và đơn giá. Product không có trạng thái active/inactive;
bảng bốn cột luôn hiển thị toàn bộ danh mục, tên dài tự xuống dòng và không cuộn
ngang.

Để tạo danh mục nhanh từ các đơn cũ, bấm **QUÉT ĐƠN AI** ở thanh dưới:

1. Chụp ảnh hoặc chọn ảnh đơn từ máy.
2. Bấm **AI QUÉT DANH MỤC**.
3. Hàng khớp chính xác được bỏ qua. Hàng gần giống bắt buộc chọn sản phẩm đã có
   hoặc xác nhận đây là sản phẩm mới.
4. Tên, đơn vị và giá xuất hiện rõ trong ảnh được điền sẵn. Bổ sung các ô còn
   thiếu, bỏ chọn dòng không muốn thêm rồi bấm **THÊM ... SẢN PHẨM**.

Backend kiểm tra trùng lại và thêm cả danh sách trong một transaction. AI không
tự đoán giá; giá chỉ được điền sẵn khi có đơn giá rõ ràng trong ảnh.

## Chạy thử Phase 2

Thêm secret vào `backend/.env` (không commit file này):

```dotenv
OPENAI_API_KEY=...
OPENAI_VISION_MODEL=gpt-5.6
```

Chạy backend và Flutter như phần trên, sau đó dùng **CHỤP ĐƠN** hoặc **CHỌN
ẢNH TỪ MÁY**. Chỉ dùng ảnh test đã ẩn tên, số điện thoại và địa chỉ.

Backend sẽ từ chối file không phải JPEG/PNG/WebP hoặc lớn hơn 8 MB. Flutter nén
ảnh, hiển thị progress và cho retry/cancel.

Sau khi AI đọc ảnh, backend tự đối chiếu danh mục. Màn hình kết quả hiển thị
bảng sáu cột **Mặt hàng – SL – Đơn vị – Giá – Thành tiền – Trạng thái**. Sáu
cột luôn fit trong chiều rộng iPhone, không cuộn ngang; tên dài tự xuống dòng:

- Xanh: đã khớp; có đơn giá và thành tiền.
- Vàng: có sản phẩm gần giống; chạm candidate để chọn nhanh.
- Đỏ: chưa có; chạm dòng để sửa tên, số lượng, đơn vị, giá và thêm vào danh mục.

UI hiện chưa hiển thị ảnh minh họa riêng cho từng sản phẩm. Dòng vàng có panel
gợi ý để chọn nhanh; dòng đỏ có thể chọn từ toàn bộ danh mục hoặc thêm mới.

Khi tất cả dòng đều khớp, nút **XÁC NHẬN** được bật. Bấm nút này để mở hóa đơn
khách hàng gồm tên hàng, số lượng/đơn vị, đơn giá, thành tiền từng dòng và tổng
cộng. Bảng hóa đơn luôn fit chiều rộng điện thoại, tên dài tự xuống dòng và
không có cột trạng thái nội bộ.

Tại màn hình hóa đơn có thể:

- Bấm **CHIA SẺ ẢNH** để xuất toàn bộ hóa đơn thành PNG và mở share sheet của
  iOS/Android.
- Bấm **SAO CHÉP** để lấy nội dung hóa đơn dạng text.

Giá và tổng tiền trên hóa đơn là kết quả backend đã đối chiếu và tính bằng
code, không phải do Vision AI tính. Đây vẫn chưa phải đơn hàng đã lưu; bước ghi
Order/Payment/công nợ vào database thuộc Phase 4.

## Bước code tiếp theo

### Hoàn thiện matching

- Học alias sau khi người dùng xác nhận một candidate.
- Chuẩn hóa thêm quy cách/viết tắt như `3k6 -> 3.6kg`.
- Không đưa logic matching hoặc giá vào prompt Vision AI.

### Sau đó: Orders và Payments

Backend phải tự lấy giá, tính tổng và cập nhật công nợ trong transaction.

## Cách học architecture

Khi đọc một feature, luôn hỏi:

1. Feature này làm gì?
2. Dữ liệu vào từ đâu?
3. Kết quả đi ra đâu?

Sau đó trace một action thật từ Page tới database và quay ngược response về UI.
