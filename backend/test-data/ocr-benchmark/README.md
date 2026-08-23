# OCR Benchmark — AI Order Assistant

Bộ dữ liệu này dùng để đo độ chính xác thực tế của bước OCR/trích xuất đơn hàng
(`POST /api/order-intake/analyze`, dùng OpenAI Vision) trên ảnh đơn hàng viết tay thật.

## Cấu trúc thư mục

```
backend/test-data/ocr-benchmark/
  images/
    order-001.jpg ... order-006.jpg     # 6 ảnh đơn hàng viết tay thật do chủ shop cung cấp
  ground-truth/
    order-001.json ... order-006.json   # đáp án đúng (nhãn) cho từng ảnh
  README.md                             # file này
backend/scripts/
  ocr-benchmark.js                      # script chạy benchmark
```

## QUAN TRỌNG: ground-truth hiện là BẢN NHÁP, chưa dùng để đo được

Mình (AI) đọc chữ viết tay trong 6 ảnh và soạn sẵn file JSON đáp án (`ground-truth/*.json`),
nhưng nhiều chỗ chữ viết tay khó đọc / là tên viết tắt riêng của shop mà mình không chắc
chắn (ví dụ tên sản phẩm rút gọn, ký hiệu như "C", "T", "bịch"...). Mỗi dòng trong file JSON
có field:

- `"confidence"`: `"high"` / `"medium"` / `"low"` — mình tự tin đến đâu với dòng đó
- `"note"`: giải thích vì sao chưa chắc (nếu có)
- `"productNameGuess"`: tên sản phẩm mình đoán — **chưa chắc khớp với tên thật trong danh mục sản phẩm của shop**

**Trước khi dùng để đo độ chính xác thật, bạn cần mở từng file trong `ground-truth/`, đối
chiếu với ảnh gốc trong `images/` và ảnh gốc thật (giấy viết tay), sửa lại các dòng
`confidence: "low"` (và kiểm tra nhanh các dòng `"medium"`) cho đúng. Không cần sửa gì thêm
với các field `quantity`/`unit`/`productNameGuess` nếu bạn thấy đã đúng.**

Nếu bỏ qua bước này, script benchmark vẫn chạy được nhưng số liệu độ chính xác sẽ không
đáng tin cậy vì bản thân "đáp án" cũng có thể sai.

## Cách chạy benchmark

1. Sửa xong ground-truth (bước trên).
2. Đảm bảo backend đang chạy với `OPENAI_API_KEY` thật đã cấu hình trong `.env`:
   ```
   cd backend
   npm run start:dev
   ```
3. Mở terminal khác, chạy:
   ```
   cd backend
   npm run ocr:benchmark
   ```
4. Script sẽ gọi `POST /api/order-intake/analyze` cho từng ảnh trong `images/`, so sánh kết
   quả trả về với ground-truth tương ứng, in báo cáo ra màn hình, và lưu báo cáo chi tiết vào
   `backend/test-data/ocr-benchmark/report.json`.

Mặc định script gọi vào `http://localhost:3000/api`. Nếu backend chạy ở địa chỉ/port khác,
set biến môi trường `OCR_BENCHMARK_BASE_URL`, ví dụ:
```
OCR_BENCHMARK_BASE_URL=http://localhost:4000/api npm run ocr:benchmark
```

## Báo cáo đo những gì

Với mỗi ảnh, script ghép (match) từng dòng ground-truth với dòng gần nhất trong kết quả OCR
trả về (dựa trên số lượng + độ giống tên sản phẩm), rồi tính:

- **Item recall**: % số dòng trong ground-truth mà OCR có bắt được (không bỏ sót dòng nào)
- **Quantity accuracy**: trong số dòng bắt được, % có đúng số lượng
- **Unit accuracy**: trong số dòng bắt được, % có đơn vị tính khớp (bỏ qua nếu ground-truth
  không ghi đơn vị)
- **Name similarity trung bình**: độ giống tên sản phẩm (0–1, thang đo ký tự), giúp nhìn ra
  OCR đọc sai nhẹ (lỗi chính tả) hay đọc sai hẳn

Báo cáo tính riêng cho nhóm ground-truth `confidence: high/medium` (đáng tin) và tổng thể,
để tránh các dòng `low` (bản thân đáp án chưa chắc đúng) làm méo số liệu.

## Sau khi có kết quả

Đưa file `report.json` (hoặc chụp màn hình bảng tổng kết) lại cho mình xem — nếu độ chính
xác thấp ở một nhóm lỗi cụ thể (ví dụ luôn sai đơn vị viết tắt, hay luôn bỏ sót dòng cuối
ảnh), mình sẽ tinh chỉnh prompt của `VisionService` hoặc bổ sung rule ở
`quantity-unit-normalizer.ts` để xử lý đúng nhóm lỗi đó.
