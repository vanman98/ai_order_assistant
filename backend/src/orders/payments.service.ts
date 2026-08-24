import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentDto } from './dto/create-payment.dto';

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Ghi nhan 1 lan thanh toan cho don hang. Chong tao trung bang
   * clientRequestId (cung co che idempotent nhu OrdersService.confirm), va
   * chan thanh toan vuot qua so tien con no cua don (tinh tu tong don tru di
   * tong cac lan thanh toan da co).
   *
   * Luu y: buoc kiem tra "khong vuot qua so con no" va buoc ghi vao DB khong
   * nam trong cung 1 transaction khoa chat, nen ve ly thuyet neu co 2 yeu cau
   * thanh toan gui gan nhu dong thoi cho cung 1 don thi ca hai co the deu
   * qua duoc kiem tra truoc khi ban ghi dau tien duoc tao. Chap nhan duoc voi
   * quy mo 1 nguoi ban hang thao tac tuan tu; can xu ly ky hon (vi du dùng
   * SELECT ... FOR UPDATE) neu sau nay co nhieu nguoi cung thao tac 1 don.
   */
  async create(orderId: string, dto: CreatePaymentDto) {
    const clientRequestId = dto.clientRequestId.trim();
    if (!clientRequestId) {
      throw new BadRequestException('Thiếu mã yêu cầu (clientRequestId)');
    }

    const existing = await this.prisma.payment.findUnique({
      where: { clientRequestId },
    });
    if (existing) {
      if (existing.orderId !== orderId) {
        throw new ConflictException(
          'Mã yêu cầu thanh toán này đã được dùng cho một đơn hàng khác',
        );
      }
      // Yeu cau lap lai (retry do mat mang, double-tap...) - tra lai ban ghi
      // da tao truoc do thay vi tao moi hoac bao loi.
      return existing;
    }

    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { payments: true },
    });
    if (!order) {
      throw new NotFoundException('Không tìm thấy đơn hàng');
    }

    const paidSoFar = order.payments.reduce((sum, p) => sum + p.amount, 0);
    const remaining = order.total - paidSoFar;

    if (dto.amount > remaining) {
      throw new BadRequestException(
        `Số tiền thanh toán (${dto.amount}) vượt quá số tiền còn nợ (${remaining})`,
      );
    }

    try {
      return await this.prisma.payment.create({
        data: {
          orderId,
          clientRequestId,
          amount: dto.amount,
          method: dto.method ?? 'CASH',
          note: dto.note?.trim() || null,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        // Mot request khac voi cung clientRequestId vua tao ban ghi truoc -
        // tra lai ban ghi do thay vi bao loi (dung ngu nghia idempotent).
        const raced = await this.prisma.payment.findUnique({
          where: { clientRequestId },
        });
        if (raced) return raced;
      }
      throw error;
    }
  }

  listForOrder(orderId: string) {
    return this.prisma.payment.findMany({
      where: { orderId },
      orderBy: { createdAt: 'asc' },
    });
  }
}
