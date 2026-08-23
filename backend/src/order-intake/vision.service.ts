import {
  BadGatewayException,
  HttpException,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';
import { zodTextFormat } from 'openai/helpers/zod';
import {
  orderExtractionSchema,
  type OrderExtractionResponse,
} from './order-extraction.schema';

const SYSTEM_PROMPT = `
Bạn là bộ máy chép lại đơn hàng bán lẻ tiếng Việt từ ảnh.

Quy tắc bắt buộc:
- Chỉ lấy các dòng hàng hóa nhìn thấy trong ảnh; bỏ qua tên, số điện thoại và địa chỉ khách.
- Giữ rawText gần nguyên văn từng dòng và rawProductName đúng như ảnh.
- Không tự sửa tên thành sản phẩm trong danh mục, không đoán giá, không tính tiền.
- unitPrice chỉ là đơn giá được viết rõ cho chính sản phẩm trong ảnh; nếu ảnh
  không có đơn giá hoặc chỉ có tổng tiền không chắc chắn thì trả null.
- Không gộp các dòng lặp lại.
- Nếu số lượng hoặc đơn vị không rõ, trả null và bật needsReview.
- Nếu bất kỳ phần quan trọng nào không chắc chắn, bật needsReview và giải thích ngắn ở uncertaintyReason.
- note chỉ chứa ghi chú của chính dòng hàng. generalNote dùng cho vấn đề chung của ảnh.
`.trim();

@Injectable()
export class VisionService {
  private readonly logger = new Logger(VisionService.name);

  constructor(private readonly config: ConfigService) {}

  async extractOrder(
    file: Express.Multer.File,
  ): Promise<OrderExtractionResponse> {
    const apiKey = this.config.get<string>('OPENAI_API_KEY')?.trim();
    if (!apiKey) {
      throw new ServiceUnavailableException(
        'Vision AI chưa được cấu hình. Hãy thêm OPENAI_API_KEY vào backend/.env.',
      );
    }

    const model =
      this.config.get<string>('OPENAI_VISION_MODEL')?.trim() || 'gpt-5.6';
    const client = new OpenAI({
      apiKey,
      timeout: 60_000,
      maxRetries: 2,
    });
    const imageUrl = `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

    try {
      const response = await client.responses.parse({
        model,
        store: false,
        instructions: SYSTEM_PROMPT,
        input: [
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: 'Hãy chép lại các dòng hàng hóa trong ảnh đơn này theo schema đã cung cấp.',
              },
              {
                type: 'input_image',
                image_url: imageUrl,
                detail: 'high',
              },
            ],
          },
        ],
        text: {
          format: zodTextFormat(orderExtractionSchema, 'order_extraction'),
        },
      });

      if (!response.output_parsed) {
        throw new UnprocessableEntityException(
          'AI chưa đọc được ảnh này. Hãy chụp rõ hơn và thử lại.',
        );
      }

      return {
        ...response.output_parsed,
        meta: {
          model,
          mimeType: file.mimetype,
          sizeBytes: file.size,
        },
      };
    } catch (error) {
      if (error instanceof HttpException) throw error;

      const status =
        typeof error === 'object' && error !== null && 'status' in error
          ? String(error.status)
          : 'unknown';
      this.logger.error(`OpenAI Vision request failed (status=${status}).`);
      throw new BadGatewayException(
        'Không thể phân tích ảnh lúc này. Vui lòng thử lại sau.',
      );
    }
  }
}
