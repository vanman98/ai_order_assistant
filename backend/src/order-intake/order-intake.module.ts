import { Module } from '@nestjs/common';
import { OrderIntakeController } from './order-intake.controller';
import { OrderImagePipe } from './order-image.pipe';
import { VisionService } from './vision.service';
import { OrderResolutionService } from './order-resolution.service';

@Module({
  controllers: [OrderIntakeController],
  providers: [OrderImagePipe, OrderResolutionService, VisionService],
})
export class OrderIntakeModule {}
