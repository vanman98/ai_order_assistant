-- Add unit fields with a temporary default so existing catalog rows remain valid.
ALTER TABLE "products"
ADD COLUMN "unit" TEXT NOT NULL DEFAULT 'cái',
ADD COLUMN "normalizedUnit" TEXT NOT NULL DEFAULT 'cai';

-- Best-effort backfill for the sample grocery catalog imported from order images.
UPDATE "products"
SET
  "unit" = CASE
    WHEN "normalizedName" LIKE 'mi %' THEN 'gói'
    WHEN "normalizedName" LIKE 'pho %' THEN 'gói'
    WHEN "normalizedName" LIKE 'bun %' THEN 'gói'
    WHEN "normalizedName" LIKE 'mien %' THEN 'gói'
    WHEN "normalizedName" LIKE 'keo %' THEN 'bị'
    WHEN "normalizedName" LIKE 'banh %' THEN 'hộp'
    WHEN "normalizedName" IN ('duong trang', 'dau phong', 'tieu xay', 'nem chua') THEN 'kg'
    WHEN "normalizedName" LIKE 'bot %' THEN 'bị'
    WHEN "normalizedName" LIKE 'hat nem %' THEN 'bị'
    WHEN "normalizedName" IN ('bo huc it duong', 'coca cola lon', 'cot dua lon nho', 'sua dac ha lan xanh') THEN 'lon'
    WHEN "normalizedName" LIKE 'dau an %' THEN 'chai'
    WHEN "normalizedName" LIKE 'nuoc %' THEN 'chai'
    WHEN "normalizedName" LIKE 'sot %' THEN 'chai'
    WHEN "normalizedName" LIKE 'sua tam %' THEN 'chai'
    WHEN "normalizedName" LIKE 'tra %' THEN 'hộp'
    WHEN "normalizedName" LIKE 'ca phe %' THEN 'gói'
    WHEN "normalizedName" LIKE 'xuc xich %' THEN 'bị'
    ELSE 'cái'
  END,
  "normalizedUnit" = CASE
    WHEN "normalizedName" LIKE 'mi %' THEN 'goi'
    WHEN "normalizedName" LIKE 'pho %' THEN 'goi'
    WHEN "normalizedName" LIKE 'bun %' THEN 'goi'
    WHEN "normalizedName" LIKE 'mien %' THEN 'goi'
    WHEN "normalizedName" LIKE 'keo %' THEN 'bi'
    WHEN "normalizedName" LIKE 'banh %' THEN 'hop'
    WHEN "normalizedName" IN ('duong trang', 'dau phong', 'tieu xay', 'nem chua') THEN 'kg'
    WHEN "normalizedName" LIKE 'bot %' THEN 'bi'
    WHEN "normalizedName" LIKE 'hat nem %' THEN 'bi'
    WHEN "normalizedName" IN ('bo huc it duong', 'coca cola lon', 'cot dua lon nho', 'sua dac ha lan xanh') THEN 'lon'
    WHEN "normalizedName" LIKE 'dau an %' THEN 'chai'
    WHEN "normalizedName" LIKE 'nuoc %' THEN 'chai'
    WHEN "normalizedName" LIKE 'sot %' THEN 'chai'
    WHEN "normalizedName" LIKE 'sua tam %' THEN 'chai'
    WHEN "normalizedName" LIKE 'tra %' THEN 'hop'
    WHEN "normalizedName" LIKE 'ca phe %' THEN 'goi'
    WHEN "normalizedName" LIKE 'xuc xich %' THEN 'bi'
    ELSE 'cai'
  END;

ALTER TABLE "products"
ALTER COLUMN "unit" DROP DEFAULT,
ALTER COLUMN "normalizedUnit" DROP DEFAULT;

DROP INDEX "products_normalizedName_key";
CREATE UNIQUE INDEX "products_normalizedName_normalizedUnit_key"
ON "products"("normalizedName", "normalizedUnit");
