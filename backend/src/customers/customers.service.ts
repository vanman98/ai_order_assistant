import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeProductName } from '../products/product-name-normalizer';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

export interface DebtOrder {
  id: string;
  code: string;
  createdAt: Date;
  total: number;
  paidTotal: number;
  remaining: number;
}

export interface CustomerDebt {
  customerId: string;
  customerName: string;
  phone: string | null;
  totalDebt: number;
  unpaidOrderCount: number;
  orders: DebtOrder[];
}

@Injectable()
export class CustomersService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(query?: string) {
    const trimmedQuery = query?.trim();
    const normalizedQuery = trimmedQuery
      ? normalizeProductName(trimmedQuery)
      : undefined;

    return this.prisma.customer.findMany({
      where: trimmedQuery
        ? {
            OR: [
              {
                name: {
                  contains: trimmedQuery,
                  mode: Prisma.QueryMode.insensitive,
                },
              },
              { normalizedName: { contains: normalizedQuery } },
              { phone: { contains: trimmedQuery } },
            ],
          }
        : undefined,
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Tong hop cong no theo tung khach hang.
   *
   * KHONG luu san so du no trong DB: moi lan doc deu tinh lai tu
   * (order.total - tong payments cua don do). Neu luu san, chi can 1 lan
   * sua/xoa Payment ma quen cap nhat la so no sai vinh vien - loai bug rat
   * kho phat hien va rat dat voi 1 cua hang.
   *
   * Chi don da gan customerId moi duoc tinh. Don "Khach le" khong co chu no
   * cu the nen khong the doi ai tra.
   */
  async findDebts() {
    const orders = await this.prisma.order.findMany({
      where: { customerId: { not: null } },
      select: {
        id: true,
        code: true,
        total: true,
        createdAt: true,
        customerId: true,
        customerNameSnapshot: true,
        customer: { select: { id: true, name: true, phone: true } },
        payments: { select: { amount: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const byCustomer = new Map<string, CustomerDebt>();

    for (const order of orders) {
      if (!order.customerId) continue;

      const paidTotal = order.payments.reduce(
        (sum, payment) => sum + payment.amount,
        0,
      );
      const remaining = order.total - paidTotal;
      // Don da tra du (hoac tra du) khong con la cong no.
      if (remaining <= 0) continue;

      let entry = byCustomer.get(order.customerId);
      if (!entry) {
        entry = {
          customerId: order.customerId,
          // customer co the null neu khach da bi xoa (onDelete: SetNull) -
          // luc do dung ten da chup lai tren don de van hien thi duoc.
          customerName: order.customer?.name ?? order.customerNameSnapshot,
          phone: order.customer?.phone ?? null,
          totalDebt: 0,
          unpaidOrderCount: 0,
          orders: [],
        };
        byCustomer.set(order.customerId, entry);
      }

      entry.totalDebt += remaining;
      entry.unpaidOrderCount += 1;
      entry.orders.push({
        id: order.id,
        code: order.code,
        createdAt: order.createdAt,
        total: order.total,
        paidTotal,
        remaining,
      });
    }

    // Ai no nhieu nhat len dau - dung thu tu chu shop can nhin truoc.
    return [...byCustomer.values()].sort((a, b) => b.totalDebt - a.totalDebt);
  }

  async create(dto: CreateCustomerDto) {
    const name = dto.name.trim();
    const normalizedName = normalizeProductName(name);
    this.requireSearchableName(normalizedName);

    return this.prisma.customer.create({
      data: {
        name,
        normalizedName,
        phone: this.normalizePhone(dto.phone),
        note: dto.note?.trim() || null,
      },
    });
  }

  async update(id: string, dto: UpdateCustomerDto) {
    const customer = await this.requireCustomer(id);
    const name = dto.name?.trim() ?? customer.name;
    const normalizedName = normalizeProductName(name);
    this.requireSearchableName(normalizedName);

    return this.prisma.customer.update({
      where: { id },
      data: {
        name,
        normalizedName,
        ...(dto.phone !== undefined
          ? { phone: this.normalizePhone(dto.phone) }
          : {}),
        ...(dto.note !== undefined ? { note: dto.note?.trim() || null } : {}),
      },
    });
  }

  async remove(id: string) {
    await this.requireCustomer(id);
    // Xem giai thich trong schema.prisma: xoa Customer an toan vi Order
    // luon giu customerNameSnapshot rieng va customerId dùng onDelete:
    // SetNull, khong lam mat du lieu don hang cu.
    return this.prisma.customer.delete({ where: { id } });
  }

  private async requireCustomer(id: string) {
    const customer = await this.prisma.customer.findUnique({ where: { id } });
    if (!customer) {
      throw new NotFoundException('Không tìm thấy khách hàng');
    }
    return customer;
  }

  private requireSearchableName(normalizedName: string) {
    if (!normalizedName) {
      throw new BadRequestException('Tên khách hàng phải có chữ hoặc số');
    }
  }

  private normalizePhone(phone?: string): string | null {
    const trimmed = phone?.trim();
    return trimmed ? trimmed : null;
  }
}
