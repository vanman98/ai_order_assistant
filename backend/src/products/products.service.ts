import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { normalizeProductName } from './product-name-normalizer';

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(query?: string) {
    const trimmedQuery = query?.trim();
    const normalizedQuery = trimmedQuery
      ? normalizeProductName(trimmedQuery)
      : undefined;

    return this.prisma.product.findMany({
      where: trimmedQuery
        ? {
            OR: [
              {
                name: {
                  contains: trimmedQuery,
                  mode: Prisma.QueryMode.insensitive,
                },
              },
              {
                normalizedName: {
                  contains: normalizedQuery,
                },
              },
            ],
          }
        : undefined,
      orderBy: { name: 'asc' },
    });
  }

  async create(dto: CreateProductDto) {
    const name = dto.name.trim();
    const unit = dto.unit.trim();
    const normalizedName = normalizeProductName(name);
    const normalizedUnit = normalizeProductName(unit);
    this.requireSearchableName(normalizedName);
    this.requireSearchableUnit(normalizedUnit);

    const existing = await this.prisma.product.findUnique({
      where: {
        normalizedName_normalizedUnit: { normalizedName, normalizedUnit },
      },
    });
    if (existing) {
      throw new ConflictException('Tên sản phẩm và đơn vị đã tồn tại');
    }

    return this.prisma.product.create({
      data: {
        name,
        normalizedName,
        unit,
        normalizedUnit,
        price: dto.price,
      },
    });
  }

  async createMany(dtos: CreateProductDto[]) {
    const entries = dtos.map((dto) => {
      const name = dto.name.trim();
      const unit = dto.unit.trim();
      const normalizedName = normalizeProductName(name);
      const normalizedUnit = normalizeProductName(unit);
      this.requireSearchableName(normalizedName);
      this.requireSearchableUnit(normalizedUnit);
      return {
        name,
        normalizedName,
        unit,
        normalizedUnit,
        price: dto.price,
      };
    });

    const requestKeys = new Set<string>();
    for (const entry of entries) {
      const key = `${entry.normalizedName}\u0000${entry.normalizedUnit}`;
      if (requestKeys.has(key)) {
        throw new ConflictException(
          `Sản phẩm bị lặp trong danh sách: ${entry.name} (${entry.unit})`,
        );
      }
      requestKeys.add(key);
    }

    const existing = await this.prisma.product.findMany({
      where: {
        OR: entries.map(({ normalizedName, normalizedUnit }) => ({
          normalizedName,
          normalizedUnit,
        })),
      },
      select: { name: true, unit: true },
    });
    if (existing.length > 0) {
      const first = existing[0];
      throw new ConflictException(
        `Sản phẩm đã có trong danh mục: ${first.name} (${first.unit})`,
      );
    }

    try {
      return await this.prisma.$transaction(
        entries.map((data) => this.prisma.product.create({ data })),
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException(
          'Một sản phẩm vừa được thêm vào danh mục. Hãy quét lại.',
        );
      }
      throw error;
    }
  }

  async update(id: string, dto: UpdateProductDto) {
    const product = await this.requireProduct(id);
    const name = dto.name?.trim() ?? product.name;
    const unit = dto.unit?.trim() ?? product.unit;
    const normalizedName = normalizeProductName(name);
    const normalizedUnit = normalizeProductName(unit);
    this.requireSearchableName(normalizedName);
    this.requireSearchableUnit(normalizedUnit);
    await this.ensureProductAvailable(normalizedName, normalizedUnit, id);

    return this.prisma.product.update({
      where: { id },
      data: {
        name,
        normalizedName,
        unit,
        normalizedUnit,
        ...(dto.price != null ? { price: dto.price } : {}),
      },
    });
  }

  async remove(id: string) {
    await this.requireProduct(id);
    return this.prisma.product.delete({ where: { id } });
  }

  private async requireProduct(id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) {
      throw new NotFoundException('Không tìm thấy sản phẩm');
    }
    return product;
  }

  private async ensureProductAvailable(
    normalizedName: string,
    normalizedUnit: string,
    excludedId?: string,
  ) {
    const existing = await this.prisma.product.findFirst({
      where: {
        normalizedName,
        normalizedUnit,
        ...(excludedId ? { id: { not: excludedId } } : {}),
      },
    });
    if (existing) {
      throw new ConflictException('Tên sản phẩm và đơn vị đã tồn tại');
    }
  }

  private requireSearchableName(normalizedName: string) {
    if (!normalizedName) {
      throw new BadRequestException('Tên sản phẩm phải có chữ hoặc số');
    }
  }

  private requireSearchableUnit(normalizedUnit: string) {
    if (!normalizedUnit) {
      throw new BadRequestException('Đơn vị phải có chữ hoặc số');
    }
  }
}
