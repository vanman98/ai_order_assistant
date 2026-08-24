import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ConfirmOrderDto } from './dto/confirm-order.dto';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { OrdersService } from './orders.service';
import { PaymentsService } from './payments.service';

@Controller('orders')
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
    private readonly paymentsService: PaymentsService,
  ) {}

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

  @Post(':id/payments')
  createPayment(@Param('id') id: string, @Body() dto: CreatePaymentDto) {
    return this.paymentsService.create(id, dto);
  }

  @Get(':id/payments')
  listPayments(@Param('id') id: string) {
    return this.paymentsService.listForOrder(id);
  }
}
