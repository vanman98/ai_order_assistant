import { randomUUID } from 'node:crypto';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ConfirmOrderDto } from './dto/confirm-order.dto';

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Tao Order + OrderItem trong mot transaction, chong tao trung bang
   * clientRequestId (idempotency key do Flutter sinh ra khi mo man hinh
   * xac nhan). Gia luon lay tu danh muc hien tai trong DB - khong tin gia
   * hay thanh tien do client gui len.
   */
  async confirm(dto: ConfirmOrderDto) {
    const clientRequestId = dto.clientRequestId.trim();
    if (!clientRequestId) {
      throw new BadRequestException('Thiếu mã yêu cầu (clientRequestId)');
    }

    const existingByClientRequestId = await this.prisma.order.findUnique({
      where: { clientRequestId },
      include: { items: true, payments: true },
    });
    if (existingByClientRequestId) {
      // Yeu cau lap lai (retry do mat mang, double-tap...) - tra lai don da
      // tao truoc do thay vi tao moi hoac bao loi.
      return this.withPaymentSummary(existingByClientRequestId);
    }

    if (dto.items.length === 0) {
      throw new BadRequestException('Đơn hàng chưa có sản phẩm nào');
    }

    const productIds = [...new Set(dto.items.map((item) => item.productId))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
    });
    const productById = new Map(
      products.map((product) => [product.id, product]),
    );

    const missingProductIds = productIds.filter(
      (id) => !productById.has(id),
    );
    if (missingProductIds.length > 0) {
      throw new BadRequestException(
        'Một số sản phẩm không còn trong danh mục. Vui lòng resolve lại đơn trước khi xác nhận.',
      );
    }

    const lineItems = dto.items.map((item) => {
      const product = productById.get(item.productId)!;
      if (!(item.quantity > 0)) {
        throw new BadRequestException(
          `Số lượng không hợp lệ cho ${product.name}`,
        );
      }
      const lineTotal = Math.round(item.quantity * product.price);
      return {
        productId: product.id,
        nameSnapshot: product.name,
        unitSnapshot: product.unit,
        unitPriceSnapshot: product.price,
        quantity: item.quantity,
        lineTotal,
        rawText: item.rawText?.trim() || null,
      };
    });

    const total = lineItems.reduce((sum, item) => sum + item.lineTotal, 0);
    const id = randomUUID();
    const code = this.generateOrderCode(id);

    // Neu don gan voi 1 Customer co san, lay ten cua khach lam mac dinh
    // cho customerNameSnapshot (van cho phep dto.customerName ghi de neu
    // nguoi dung sua tay ten luc xac nhan).
    let customerNameSnapshot = dto.customerName?.trim();
    let customerId: string | null = null;
    if (dto.customerId) {
      const customer = await this.prisma.customer.findUnique({
        where: { id: dto.customerId },
      });
      if (!customer) {
        throw new BadRequestException('Không tìm thấy khách hàng đã chọn');
      }
      customerId = customer.id;
      customerNameSnapshot ||= customer.name;
    }

    try {
      const created = await this.prisma.order.create({
        data: {
          id,
          code,
          clientRequestId,
          customerId,
          customerNameSnapshot: customerNameSnapshot || 'Khách lẻ',
          subtotal: total,
          total,
          note: dto.note?.trim() || null,
          items: { create: lineItems },
        },
        include: { items: true, payments: true },
      });
      return this.withPaymentSummary(created);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        // Mot request khac voi cung clientRequestId vua tao don truoc -
        // tra lai don do thay vi bao loi (dung ngu nghia idempotent).
        const raced = await this.prisma.order.findUnique({
          where: { clientRequestId },
          include: { items: true, payments: true },
        });
        if (raced) return this.withPaymentSummary(raced);
      }
      throw error;
    }
  }

  async findToday() {
    const { start, end } = this.todayRange();
    const orders = await this.prisma.order.findMany({
      where: { createdAt: { gte: start, lt: end } },
      orderBy: { createdAt: 'desc' },
      include: { items: true, payments: true },
    });
    return orders.map((order) => this.withPaymentSummary(order));
  }

  async findOne(id: string) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: { items: true, payments: true },
    });
    if (!order) {
      throw new NotFoundException('Không tìm thấy đơn hàng');
    }
    return this.withPaymentSummary(order);
  }

  /**
   * Ghep them paidTotal (tong da thanh toan) va remaining (con no) vao don
   * hang, tinh truc tiep tu danh sach payments moi lan doc - khong luu san 2
   * gia tri nay trong DB de tranh lech du lieu neu 1 lan thanh toan bi sua
   * hoac xoa sau nay.
   */
  private withPaymentSummary<
    T extends { total: number; payments: { amount: number }[] },
  >(order: T) {
    const paidTotal = order.payments.reduce((sum, p) => sum + p.amount, 0);
    return {
      ...order,
      paidTotal,
      remaining: order.total - paidTotal,
    };
  }

  private todayRange() {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start);
    end.setDate(end.getDate() + 1);
    return { start, end };
  }

  private generateOrderCode(id: string): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const suffix = id.replace(/-/g, '').slice(0, 6).toUpperCase();
    return `HD${year}${month}${day}-${suffix}`;
  }
}
