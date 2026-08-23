import {
  Body,
  Controller,
  HttpCode,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import {
  MAX_ORDER_IMAGE_BYTES,
  ORDER_IMAGE_FIELD,
} from './order-intake.constants';
import { ResolveOrderDto } from './dto/resolve-order.dto';
import { OrderImagePipe } from './order-image.pipe';
import { OrderResolutionService } from './order-resolution.service';
import { VisionService } from './vision.service';

const imageUploadOptions = {
  storage: memoryStorage(),
  limits: {
    files: 1,
    fileSize: MAX_ORDER_IMAGE_BYTES,
  },
};

@Controller('order-intake')
export class OrderIntakeController {
  constructor(
    private readonly visionService: VisionService,
    private readonly orderResolutionService: OrderResolutionService,
  ) {}

  @Post('validate-image')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor(ORDER_IMAGE_FIELD, imageUploadOptions))
  validateImage(@UploadedFile(OrderImagePipe) file: Express.Multer.File) {
    return {
      valid: true,
      file: {
        mimeType: file.mimetype,
        sizeBytes: file.size,
      },
    };
  }

  @Post('analyze')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor(ORDER_IMAGE_FIELD, imageUploadOptions))
  async analyze(@UploadedFile(OrderImagePipe) file: Express.Multer.File) {
    const extraction = await this.visionService.extractOrder(file);
    return this.orderResolutionService.resolve(extraction);
  }

  @Post('resolve')
  @HttpCode(200)
  resolve(@Body() body: ResolveOrderDto) {
    return this.orderResolutionService.resolve(body);
  }
}
