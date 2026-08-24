import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeProductName } from '../products/product-name-normalizer';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

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
