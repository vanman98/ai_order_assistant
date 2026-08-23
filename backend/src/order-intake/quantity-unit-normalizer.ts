/**
 * Chuan hoa cac cach viet tat so luong/don vi thuong gap tren don hang viet
 * tay cua tap hoa/quan nho o Viet Nam. Day la quy tac thuan (rule-based),
 * KHONG dung AI doan - chi nhan dien cac mau da biet chac chan, de khong vi
 * pham nguyen tac "AI chi doc du lieu xuat hien trong anh".
 *
 * Bo quy tac nay chi chuan hoa du lieu DA duoc Vision doc ra (quantity/unit),
 * no khong tu bia so lieu moi khong co trong anh.
 */

export interface QuantityUnitInput {
  quantity: number | null;
  unit: string | null;
  rawText: string;
}

export interface QuantityUnitNormalizationResult {
  quantity: number | null;
  unit: string | null;
  wasNormalized: boolean;
  /** true neu don vi viet tat khong ro nghia (vi du "b" = bao hay bich?) */
  ambiguousUnit: boolean;
}

/**
 * Cac don vi viet tat KHONG mo ho - chi co mot cach hieu hop ly trong ngu
 * canh tap hoa/quan nho.
 */
const UNAMBIGUOUS_UNIT_ALIASES: Record<string, string> = {
  th: 'thùng',
  thung: 'thùng',
  l: 'lít',
  lit: 'lít',
  c: 'chai',
  chai: 'chai',
  h: 'hộp',
  hop: 'hộp',
  goi: 'gói',
  kg: 'kg',
  g: 'gam',
  gam: 'gam',
  lon: 'lon',
  bich: 'bịch',
  bao: 'bao',
  tui: 'túi',
};

/**
 * Don vi viet tat mo ho - can nguoi dung xac nhan thay vi tu suy doan.
 * "b" co the la "bao" hoac "bich" tuy cua hang, nen khong tu dong anh xa.
 */
const AMBIGUOUS_UNIT_TOKENS = new Set(['b']);

function stripDiacritics(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/gi, 'd');
}

function normalizeToken(value: string): string {
  return stripDiacritics(value.trim().toLocaleLowerCase('vi'));
}

/**
 * Chuan hoa don vi viet tat ve dang day du khi khong mo ho.
 * Tra ve unit goc (khong doi) neu khong nhan dien duoc hoac bi mo ho.
 */
export function normalizeUnitAbbreviation(unit: string | null): {
  unit: string | null;
  wasNormalized: boolean;
  ambiguous: boolean;
} {
  if (!unit) return { unit, wasNormalized: false, ambiguous: false };

  const token = normalizeToken(unit);
  if (!token) return { unit, wasNormalized: false, ambiguous: false };

  if (AMBIGUOUS_UNIT_TOKENS.has(token)) {
    return { unit, wasNormalized: false, ambiguous: true };
  }

  const canonical = UNAMBIGUOUS_UNIT_ALIASES[token];
  if (!canonical || canonical === unit) {
    return { unit, wasNormalized: false, ambiguous: false };
  }

  return { unit: canonical, wasNormalized: true, ambiguous: false };
}

/**
 * Nhan dien cach viet can nang kieu "3k6" (= 3,6kg, tuc 3kg600g) thuong
 * thay tren don hang can ky viet tay. Chi ap dung khi AI chua doc duoc
 * quantity/unit (tranh ghi de du lieu da co).
 */
const KG_SHORTHAND_PATTERN = /(\d+)\s*k\s*(\d{1,3})(?!\d)/i;

function parseKgShorthand(
  rawText: string,
): { quantity: number; unit: string } | null {
  const match = KG_SHORTHAND_PATTERN.exec(rawText);
  if (!match) return null;

  const whole = Number(match[1]);
  const fractionDigits = match[2].padEnd(3, '0');
  const fraction = Number(fractionDigits) / 1000;
  const quantity = Math.round((whole + fraction) * 1000) / 1000;

  return { quantity, unit: 'kg' };
}

/**
 * Chuan hoa quantity + unit cua mot dong hang truoc khi doi chieu danh muc.
 * - Neu unit la viet tat khong mo ho, doi ve dang day du de so khop tot hon.
 * - Neu quantity con thieu va rawText co mau "3k6", suy ra quantity=3.6 va
 *   unit="kg" (chi khi unit hien tai dang trong hoac cung la "kg").
 */
export function normalizeQuantityUnit(
  input: QuantityUnitInput,
): QuantityUnitNormalizationResult {
  let quantity = input.quantity;
  let unit = input.unit;
  let wasNormalized = false;

  const unitResult = normalizeUnitAbbreviation(unit);
  unit = unitResult.unit;
  wasNormalized ||= unitResult.wasNormalized;

  const hasValidQuantity = quantity != null && quantity > 0;
  const unitLooksLikeKg = !unit || normalizeToken(unit) === 'kg';
  if (!hasValidQuantity && unitLooksLikeKg) {
    const shorthand = parseKgShorthand(input.rawText);
    if (shorthand) {
      quantity = shorthand.quantity;
      unit = shorthand.unit;
      wasNormalized = true;
    }
  }

  return {
    quantity,
    unit,
    wasNormalized,
    ambiguousUnit: unitResult.ambiguous,
  };
}
