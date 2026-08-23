import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ConfirmOrderDto } from './dto/confirm-order.dto';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post()
  confirm(@Body() dto: ConfirmOrderDto) {
    return this.ordersService.confirm(dto);
  }

  @Get()
  findToday() {
    return this.ordersService.findToday();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.ordersService.findOne(id);
  }
}
