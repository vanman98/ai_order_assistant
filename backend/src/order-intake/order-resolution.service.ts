import { Injectable } from '@nestjs/common';
import type { Product } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeProductName } from '../products/product-name-normalizer';
import type {
  ResolveOrderDto,
  ResolveOrderItemDto,
} from './dto/resolve-order.dto';
import { normalizeQuantityUnit } from './quantity-unit-normalizer';

type MatchStatus = 'matched' | 'review' | 'missing';

interface ProductSummary {
  id: string;
  name: string;
  unit: string;
  price: number;
}

interface ProductCandidate extends ProductSummary {
  score: number;
}

export interface ResolvedOrderItem extends ResolveOrderItemDto {
  matchStatus: MatchStatus;
  matchedProduct: ProductSummary | null;
  candidates: ProductCandidate[];
  lineTotal: number | null;
}

export interface ResolvedOrderResponse {
  items: ResolvedOrderItem[];
  imageQuality: ResolveOrderDto['imageQuality'];
  generalNote: string | null;
  allMatched: boolean;
  invoiceTotal: number;
}

@Injectable()
export class OrderResolutionService {
  constructor(private readonly prisma: PrismaService) {}

  async resolve(input: ResolveOrderDto): Promise<ResolvedOrderResponse> {
    const products = await this.prisma.product.findMany({
      orderBy: { name: 'asc' },
    });
    const productsById = new Map(products.map((product) => [product.id, product]));

    const items = input.items.map((item) =>
      this.resolveItem(item, products, productsById),
    );
    const invoiceTotal = items.reduce(
      (total, item) => total + (item.lineTotal ?? 0),
      0,
    );
    const allMatched =
      items.length > 0 &&
      items.every(
        (item) => item.matchStatus === 'matched' && item.lineTotal !== null,
      );

    return {
      items,
      imageQuality: input.imageQuality,
      generalNote: input.generalNote,
      allMatched,
      invoiceTotal,
    };
  }

  private resolveItem(
    rawItem: ResolveOrderItemDto,
    products: Product[],
    productsById: Map<string, Product>,
  ): ResolvedOrderItem {
    const item = this.applyRuleBasedNormalization(rawItem);
    const selected = item.selectedProductId
      ? productsById.get(item.selectedProductId)
      : undefined;
    const normalizedName = normalizeProductName(item.rawProductName);
    const normalizedUnit = item.unit ? normalizeProductName(item.unit) : '';

    const ranked = products
      .map((product) => ({
        product,
        score: this.matchScore(normalizedName, normalizedUnit, product),
      }))
      .filter(({ score }) => score >= 0.35)
      .sort((left, right) => right.score - left.score)
      .slice(0, 3);

    const exact = products.find(
      (product) =>
        product.normalizedName === normalizedName &&
        (!normalizedUnit || product.normalizedUnit === normalizedUnit),
    );
    const matched = selected ?? exact;
    const hasValidQuantity = item.quantity != null && item.quantity > 0;
    const matchStatus: MatchStatus = matched
      ? item.needsReview
        ? 'review'
        : 'matched'
      : ranked.length > 0
        ? 'review'
        : 'missing';

    return {
      ...item,
      selectedProductId: matched?.id ?? item.selectedProductId,
      matchStatus,
      matchedProduct: matched ? this.toSummary(matched) : null,
      candidates: ranked.map(({ product, score }) => ({
        ...this.toSummary(product),
        score: Number(score.toFixed(2)),
      })),
      lineTotal:
        matched && hasValidQuantity
          ? Math.round(item.quantity! * matched.price)
          : null,
    };
  }

  /**
   * Ap dung bo quy tac chuan hoa so luong/don vi viet tat (muc P0
   * "rule-based normalize") len du lieu Vision da doc, truoc khi doi chieu
   * danh muc. Khong bia du lieu moi - chi chuan hoa cach viet da co trong anh.
   */
  private applyRuleBasedNormalization(
    item: ResolveOrderItemDto,
  ): ResolveOrderItemDto {
    const normalized = normalizeQuantityUnit({
      quantity: item.quantity,
      unit: item.unit,
      rawText: item.rawText,
    });

    if (!normalized.wasNormalized && !normalized.ambiguousUnit) {
      return item;
    }

    return {
      ...item,
      quantity: normalized.quantity,
      unit: normalized.unit,
      needsReview: normalized.ambiguousUnit ? true : item.needsReview,
      uncertaintyReason:
        normalized.ambiguousUnit && !item.uncertaintyReason
          ? `Đơn vị viết tắt "${item.unit}" không rõ nghĩa, vui lòng xác nhận`
          : item.uncertaintyReason,
    };
  }

  private matchScore(
    normalizedName: string,
    normalizedUnit: string,
    product: Product,
  ): number {
    if (!normalizedName) return 0;

    let nameScore: number;
    if (product.normalizedName === normalizedName) {
      nameScore = 1;
    } else if (
      product.normalizedName.includes(normalizedName) ||
      normalizedName.includes(product.normalizedName)
    ) {
      nameScore = 0.82;
    } else {
      const inputTokens = new Set(normalizedName.split(' '));
      const productTokens = new Set(product.normalizedName.split(' '));
      const shared = [...inputTokens].filter((token) => productTokens.has(token));
      nameScore = shared.length / Math.max(inputTokens.size, productTokens.size);
    }

    if (!normalizedUnit) return nameScore;
    return product.normalizedUnit === normalizedUnit
      ? Math.min(1, nameScore + 0.08)
      : nameScore * 0.7;
  }

  private toSummary(product: Product): ProductSummary {
    return {
      id: product.id,
      name: product.name,
      unit: product.unit,
      price: product.price,
    };
  }
}
