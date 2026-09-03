import { Injectable } from '@nestjs/common';
import type { Product } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeProductName } from '../products/product-name-normalizer';
import type {
  ResolveOrderDto,
  ResolveOrderItemDto,
} from './dto/resolve-order.dto';
import { normalizeQuantityUnit } from './quantity-unit-normalizer';
import { compareVariants } from './variant-validator';
import {
  checkWrittenPrice,
  describeWrittenPriceConflict,
} from './written-price-check';

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

/** Duoi diem nay thi khong con dang lam ung vien de nguoi dung chon. */
export const CANDIDATE_MIN_SCORE = 0.35;

/**
 * Nguong CONG TIN CAY cho phep tu dong ghep ma khong hoi nguoi dung.
 *
 * Hai nguong nay co chu dich dat CAO. Trieu ly: hoi lai nguoi dung mot lan
 * chi ton mot cu cham, con tu dong ghep sai thi sai gia, sai hoa don, sai
 * cong no - va khong ai biet. Do chinh xac quan trong hon do phu.
 *
 * Chi nen ha hai so nay khi da co so lieu benchmark tren don hang that,
 * KHONG ha theo cam tinh.
 */
export const AUTO_MIN_SCORE = 0.88;

/**
 * Khoang cach toi thieu giua ung vien tot nhat va ung vien thu hai.
 * Top1 = 0.90 va Top2 = 0.87 nghia la he thong dang phan van giua hai san
 * pham rat giong nhau - dung luc do phai hoi, du diem tuyet doi kha cao.
 */
export const AUTO_MIN_GAP = 0.15;

interface MatchDecision {
  product?: Product;
  status: MatchStatus;
  reason: string | null;
}

@Injectable()
export class OrderResolutionService {
  constructor(private readonly prisma: PrismaService) {}

  async resolve(input: ResolveOrderDto): Promise<ResolvedOrderResponse> {
    const products = await this.prisma.product.findMany({
      orderBy: { name: 'asc' },
    });
    const productsById = new Map(
      products.map((product) => [product.id, product]),
    );

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

    // `contenders` giu TAT CA san pham dat nguong ung vien (khong cat bot),
    // dung de biet danh muc co thuc su phan biet bien the hay khong.
    // `ranked` chi lay 3 de hien cho nguoi dung chon.
    const contenders = products
      .map((product) => ({
        product,
        ...this.scoreProduct(normalizedName, normalizedUnit, product),
      }))
      .filter(({ score }) => score >= CANDIDATE_MIN_SCORE)
      .sort((left, right) => right.score - left.score);
    const ranked = contenders.slice(0, 3);

    const exact = products.find(
      (product) =>
        product.normalizedName === normalizedName &&
        (!normalizedUnit || product.normalizedUnit === normalizedUnit),
    );

    const decision = this.decide({
      item,
      selected,
      exact,
      ranked,
      normalizedUnit,
      contenderNames: contenders.map(({ product }) => product.name),
    });

    const matched = decision.product;
    const hasValidQuantity = item.quantity != null && item.quantity > 0;

    return {
      ...item,
      needsReview: decision.status === 'review' ? true : item.needsReview,
      uncertaintyReason: decision.reason ?? item.uncertaintyReason,
      selectedProductId: matched?.id ?? item.selectedProductId,
      matchStatus: decision.status,
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
   * CONG TIN CAY.
   *
   * Chi tra ve `product` (tuc la RANG BUOC san pham vao dong hang) khi that su
   * chac chan. Khi khong chac, tra ve status 'review' KEM theo `candidates` de
   * nguoi dung chon - chu KHONG doan bua roi tinh tien luon.
   */
  private decide(input: {
    item: ResolveOrderItemDto;
    selected: Product | undefined;
    exact: Product | undefined;
    ranked: Array<{ product: Product; score: number; nameScore: number }>;
    normalizedUnit: string;
    contenderNames: string[];
  }): MatchDecision {
    const { item, selected, exact, ranked, normalizedUnit, contenderNames } =
      input;

    // 1. Nguoi dung da tu tay chon -> luon tin, khong kiem tra gi them.
    if (selected) {
      return {
        product: selected,
        status: item.needsReview ? 'review' : 'matched',
        reason: null,
      };
    }

    const fallbackStatus: MatchStatus =
      ranked.length > 0 ? 'review' : 'missing';

    // 2. Khop chuoi tuyet doi. Van phai qua doi chieu gia - ten trung khong
    //    co nghia la dung SKU (co the danh muc co hai ban ghi gan giong, hoac
    //    gia da thay doi tu lan ban truoc).
    if (exact) {
      if (item.needsReview) {
        return { product: exact, status: 'review', reason: null };
      }
      const priceReason = this.checkPrice(item, exact);
      if (priceReason) {
        return { product: exact, status: 'review', reason: priceReason };
      }
      return { product: exact, status: 'matched', reason: null };
    }

    const top1 = ranked[0];
    if (!top1) {
      return { status: 'missing', reason: null };
    }

    // 3. Vision tu bao khong doc chac -> khong bao gio tu dong.
    if (item.needsReview) {
      return { status: fallbackStatus, reason: null };
    }

    // 4. Don vi khac nhau doi hoan toan y nghia: 1 thung khac 1 lon.
    //
    //    Kiem tra nay dat TRUOC nguong diem co chu dich. Diem tong da bi phat
    //    san khi lech don vi nen no gan nhu chac chan tut xuong duoi nguong -
    //    neu de sau, nhanh nay khong bao gio chay va nguoi dung chi thay o
    //    "cần kiểm tra" ma khong biet vi sao. Dung `nameScore` (diem chua bi
    //    phat) de chi bao ly do nay khi TEN that su khop tot.
    if (
      normalizedUnit &&
      top1.product.normalizedUnit !== normalizedUnit &&
      top1.nameScore >= AUTO_MIN_SCORE
    ) {
      return {
        status: fallbackStatus,
        reason:
          `Đơn vị trên giấy ("${item.unit}") khác đơn vị trong danh mục ` +
          `("${top1.product.unit}"). Vui lòng kiểm tra.`,
      };
    }

    // 5. Diem tuyet doi chua du cao.
    //
    //    Van phai kem ly do. Mot dong hien "cần kiểm tra" ma khong noi vi sao
    //    la bat nguoi lon tuoi tu doan - va cung lam chinh chung ta mat kha
    //    nang chan doan sau nay khi can biet tai sao ty le tu nhan con thap.
    if (top1.score < AUTO_MIN_SCORE) {
      return {
        status: fallbackStatus,
        reason:
          `Chưa đủ chắc chắn (gần giống nhất: "${top1.product.name}"). ` +
          `Vui lòng chọn đúng sản phẩm.`,
      };
    }

    // 6. Hai ung vien qua sat nhau -> he thong dang phan van, phai hoi.
    const top2 = ranked[1];
    if (top2 && top1.score - top2.score < AUTO_MIN_GAP) {
      return {
        status: fallbackStatus,
        reason:
          `Có ${ranked.length} sản phẩm gần giống nhau ` +
          `("${top1.product.name}" và "${top2.product.name}"). Vui lòng chọn đúng.`,
      };
    }

    // 7. Mau thuan bien the (kich co / huong vi / khoi luong / do ngot).
    const variant = compareVariants(
      item.rawProductName,
      top1.product.name,
      contenderNames,
    );
    if (variant.hasConflict) {
      return { status: fallbackStatus, reason: variant.reason };
    }

    // 8. So tien khach viet tren giay khong khop danh muc.
    const priceReason = this.checkPrice(item, top1.product);
    if (priceReason) {
      return { status: fallbackStatus, reason: priceReason };
    }

    return { product: top1.product, status: 'matched', reason: null };
  }

  /** Tra ve chuoi ly do neu gia viet tay mau thuan, nguoc lai tra ve null. */
  private checkPrice(
    item: ResolveOrderItemDto,
    product: Product,
  ): string | null {
    const writtenPrice = item.unitPrice;
    if (writtenPrice == null) return null;

    const result = checkWrittenPrice({
      writtenPrice,
      catalogPrice: product.price,
      quantity: item.quantity,
    });
    if (result.status !== 'conflict') return null;

    return describeWrittenPriceConflict(writtenPrice, result);
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

  /**
   * Tra ve ca hai diem:
   *  - `nameScore`: chi xet ten, CHUA bi phat vi lech don vi.
   *  - `score`    : diem cuoi cung dung de xep hang va vao cong tin cay.
   * Tach ra de con biet duoc "ten khop tot nhung don vi khac" - thong tin
   * can thiet de giai thich cho nguoi dung vi sao phai xac nhan.
   */
  private scoreProduct(
    normalizedName: string,
    normalizedUnit: string,
    product: Product,
  ): { score: number; nameScore: number } {
    if (!normalizedName) return { score: 0, nameScore: 0 };

    let nameScore: number;
    if (product.normalizedName === normalizedName) {
      nameScore = 1;
    } else if (
      product.normalizedName.includes(normalizedName) ||
      normalizedName.includes(product.normalizedName)
    ) {
      // Truoc day chuoi con luon duoc 0.82 - qua hao phong. "keo" nam trong
      // "keo dau" khong co nghia hai thu la mot: chuoi cang ngan hon so voi
      // chuoi kia thi cang thieu thong tin, nen phai bi phat theo ty le do dai.
      const shorter = Math.min(
        normalizedName.length,
        product.normalizedName.length,
      );
      const longer = Math.max(
        normalizedName.length,
        product.normalizedName.length,
      );
      nameScore = 0.55 + 0.35 * (shorter / longer);
    } else {
      const inputTokens = new Set(normalizedName.split(' '));
      const productTokens = new Set(product.normalizedName.split(' '));
      const shared = [...inputTokens].filter((token) =>
        productTokens.has(token),
      );
      nameScore = shared.length / Math.max(inputTokens.size, productTokens.size);
    }

    if (!normalizedUnit) return { score: nameScore, nameScore };
    const score =
      product.normalizedUnit === normalizedUnit
        ? Math.min(1, nameScore + 0.08)
        : nameScore * 0.7;
    return { score, nameScore };
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
