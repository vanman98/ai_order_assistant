/**
 * Kiem tra mau thuan BIEN THE giua ten khach viet tren giay va ten san pham
 * trong danh muc.
 *
 * Ly do ton tai: diem giong nhau ve chuoi KHONG du de ket luan cung mot mat
 * hang. "P/S thuong to" va "P/S thuong nho" giong nhau toi 90% ky tu nhung la
 * hai SKU khac gia. Neu chi dua vao diem so, he thong se tu dong chon sai ma
 * khong ai biet - dung loai "silent error" nguy hiem nhat.
 *
 * LUU Y QUAN TRONG: module nay lam viec tren text CON DAU, khac voi
 * normalizeProductName (bo dau). Ly do: bo dau se lam mat chinh cai thong tin
 * dung de phan biet.
 *
 *   "nho"  (kich co) -> bo dau -> "nho"
 *   "nho"   (huong vi) -> bo dau -> "nho"   <-- trung nhau!
 *   "lon"  (kich co) -> bo dau -> "lon"
 *   "lon"   (don vi hop/lon) -> bo dau -> "lon"  <-- trung nhau!
 *
 * Trong danh muc that cua cua hang co ca "Kun nho oi" va "Kun nho nho" - neu
 * bo dau thi khong the phan biet duoc size va huong vi nua.
 */

export type VariantSize = 'big' | 'small';
export type VariantSugar = 'less' | 'none';

export interface VariantProfile {
  size: VariantSize | null;
  sugar: VariantSugar | null;
  flavors: string[];
  measures: string[];
}

export interface VariantComparison {
  hasConflict: boolean;
  reason: string | null;
}

// Cum tu phai duoc nhan dien TRUOC tu don le, neu khong "tra xanh" se bi
// hieu thanh mau "xanh".
const FLAVOR_PHRASES = [
  'trà xanh',
  'bạc hà',
  'sô cô la',
  'socola',
  'cà phê',
  'dâu tây',
  'sầu riêng',
  'khoai môn',
];

const FLAVOR_TOKENS = [
  'dâu',
  'ổi',
  'nho',
  'cam',
  'xoài',
  'chanh',
  'táo',
  'dừa',
  'mít',
  'me',
  'sữa',
  'đỏ',
  'xanh',
  'vàng',
  'trắng',
  'đen',
  'hồng',
  'tím',
  'nâu',
];

// Chi giu nhung tu chi kich co pho bien va it gay hieu nham. Them tu la lam
// tang canh bao gia (giam so dong tu dong duoc), bot tu la tang nguy co bo
// sot mau thuan that.
const SIZE_PHRASES: Array<[string, VariantSize]> = [
  ['loại lớn', 'big'],
  ['cỡ lớn', 'big'],
  ['size lớn', 'big'],
  ['loại nhỏ', 'small'],
  ['cỡ nhỏ', 'small'],
  ['size nhỏ', 'small'],
];

const SIZE_TOKENS: Array<[string, VariantSize]> = [
  ['to', 'big'],
  ['lớn', 'big'],
  ['nhỏ', 'small'],
  ['bé', 'small'],
  ['mini', 'small'],
];

const SUGAR_PHRASES: Array<[string, VariantSugar]> = [
  ['ít đường', 'less'],
  ['ít ngọt', 'less'],
  ['không đường', 'none'],
  ['không ngọt', 'none'],
];

const MEASURE_PATTERN = /(\d+(?:\.\d+)?)\s*(kg|g|ml|lít|lit|l)(?![a-zà-ỹ])/giu;

/**
 * Chuan hoa nhe: ve chu thuong, GIU NGUYEN DAU, doi dau phay thap phan kieu
 * Viet ("3,6kg") thanh dau cham de con bat duoc khoi luong.
 */
export function normalizeForVariant(value: string): string {
  return value
    .toLocaleLowerCase('vi')
    .replace(/,(\d)/g, '.$1')
    .replace(/[^\p{L}\p{N}.]+/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function toCanonicalMeasure(amount: number, rawUnit: string): string {
  const unit = rawUnit.toLowerCase();
  if (unit === 'kg') return `${Math.round(amount * 1000)}g`;
  if (unit === 'g') return `${Math.round(amount)}g`;
  if (unit === 'l' || unit === 'lit' || unit === 'lít') {
    return `${Math.round(amount * 1000)}ml`;
  }
  return `${Math.round(amount)}ml`;
}

export function extractVariantProfile(value: string): VariantProfile {
  let text = normalizeForVariant(value);

  const measures = new Set<string>();
  for (const match of text.matchAll(MEASURE_PATTERN)) {
    const amount = Number.parseFloat(match[1]);
    if (Number.isFinite(amount) && amount > 0) {
      measures.add(toCanonicalMeasure(amount, match[2]));
    }
  }

  let sugar: VariantSugar | null = null;
  for (const [phrase, value_] of SUGAR_PHRASES) {
    if (text.includes(phrase)) {
      sugar = value_;
      text = text.split(phrase).join(' ');
    }
  }

  let size: VariantSize | null = null;
  for (const [phrase, value_] of SIZE_PHRASES) {
    if (text.includes(phrase)) {
      size = value_;
      text = text.split(phrase).join(' ');
    }
  }

  const flavors = new Set<string>();
  for (const phrase of FLAVOR_PHRASES) {
    if (text.includes(phrase)) {
      flavors.add(phrase);
      text = text.split(phrase).join(' ');
    }
  }

  const tokens = text.split(' ').filter(Boolean);
  if (!size) {
    for (const [token, value_] of SIZE_TOKENS) {
      if (tokens.includes(token)) {
        size = value_;
        break;
      }
    }
  }
  for (const token of FLAVOR_TOKENS) {
    if (tokens.includes(token)) flavors.add(token);
  }

  return {
    size,
    sugar,
    flavors: [...flavors].sort(),
    measures: [...measures].sort(),
  };
}

interface Dimension {
  name: string;
  /** Khoa so sanh; chuoi rong nghia la "khong ghi gi ve chieu nay". */
  valueOf: (profile: VariantProfile) => string;
  describe: (profile: VariantProfile) => string;
}

const DIMENSIONS: Dimension[] = [
  {
    name: 'khối lượng/dung tích',
    valueOf: (profile) => profile.measures.join(','),
    describe: (profile) => profile.measures.join(', '),
  },
  {
    name: 'kích cỡ',
    valueOf: (profile) => profile.size ?? '',
    describe: (profile) => describeSize(profile.size),
  },
  {
    name: 'độ ngọt',
    valueOf: (profile) => profile.sugar ?? '',
    describe: (profile) => describeSugar(profile.sugar),
  },
  {
    name: 'hương vị/màu',
    valueOf: (profile) => profile.flavors.join(','),
    describe: (profile) => profile.flavors.join(', '),
  },
];

/**
 * So sanh bien the, CO XET den danh muc that su dang co nhung gi.
 *
 * Phan biet hai tinh huong khac han nhau ve muc nguy hiem:
 *
 * 1. MAU THUAN TRUC DIEN - ca hai ben deu ghi ro va khac nhau.
 *    "P/S thuong to" vs "P/S thuong nho".
 *    -> LUON chan. Khach da noi ro la "to", ghep vao "nho" chac chan sai.
 *
 * 2. LECH MOT CHIEU - mot ben khong ghi gi.
 *    "banh ca to" vs "Banh ca".
 *    -> Chi chan khi trong danh muc THAT SU co san pham khac phan biet tren
 *       chieu do. Neu ca danh muc chi co dung mot "Banh ca" thi khong ton tai
 *       lua chon sai nao de ma chon nham - bat xac nhan luc nay la lam phien
 *       vo ich, khong doi lai duoc an toan nao.
 *
 * Nho quy tac 2, he thong tu dong noi long khi danh muc con it mat hang va tu
 * dong that chat lai khi chu cua hang them cac bien the vao danh muc.
 *
 * @param contenderNames Ten cac san pham dang la ung vien hop le cho dong nay.
 *   De trong nghia la KHONG BIET GI ve danh muc -> giu che do nghiem ngat.
 */
export function compareVariants(
  inputName: string,
  productName: string,
  contenderNames: string[] = [],
): VariantComparison {
  const input = extractVariantProfile(inputName);
  const product = extractVariantProfile(productName);
  const contenders = contenderNames.map(extractVariantProfile);

  for (const dimension of DIMENSIONS) {
    const inputValue = dimension.valueOf(input);
    const productValue = dimension.valueOf(product);
    if (inputValue === productValue) continue;

    const bothStated = inputValue !== '' && productValue !== '';
    if (bothStated) {
      return {
        hasConflict: true,
        reason: buildReason(
          dimension.name,
          dimension.describe(input),
          dimension.describe(product),
        ),
      };
    }

    // Lech mot chieu: danh muc co thuc su phan biet tren chieu nay khong?
    const catalogDistinguishes =
      contenders.length > 0
        ? new Set(contenders.map(dimension.valueOf)).size > 1
        : true;
    if (!catalogDistinguishes) continue;

    return {
      hasConflict: true,
      reason: buildReason(
        dimension.name,
        dimension.describe(input),
        dimension.describe(product),
      ),
    };
  }

  return { hasConflict: false, reason: null };
}

function describeSize(size: VariantSize | null): string {
  if (size === 'big') return 'loại lớn';
  if (size === 'small') return 'loại nhỏ';
  return '';
}

function describeSugar(sugar: VariantSugar | null): string {
  if (sugar === 'less') return 'ít đường';
  if (sugar === 'none') return 'không đường';
  return '';
}

function buildReason(
  dimension: string,
  written: string,
  catalog: string,
): string {
  const writtenPart = written ? `"${written}"` : 'không ghi';
  const catalogPart = catalog ? `"${catalog}"` : 'không ghi';
  return `Khác ${dimension}: trên giấy ${writtenPart}, danh mục ${catalogPart}. Vui lòng chọn đúng sản phẩm.`;
}
