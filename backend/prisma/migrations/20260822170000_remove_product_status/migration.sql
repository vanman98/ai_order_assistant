-- Products are permanent catalog entries until the user explicitly deletes them.
-- Preserve legacy soft-deleted rows outside the live catalog before removing status.
CREATE TABLE "legacy_archived_products" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "name" TEXT NOT NULL,
  "normalizedName" TEXT NOT NULL,
  "unit" TEXT NOT NULL,
  "normalizedUnit" TEXT NOT NULL,
  "price" INTEGER NOT NULL,
  "originalCreatedAt" TIMESTAMP(3) NOT NULL,
  "originalUpdatedAt" TIMESTAMP(3) NOT NULL,
  "migratedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO "legacy_archived_products" (
  "id",
  "name",
  "normalizedName",
  "unit",
  "normalizedUnit",
  "price",
  "originalCreatedAt",
  "originalUpdatedAt"
)
SELECT
  "id",
  "name",
  "normalizedName",
  "unit",
  "normalizedUnit",
  "price",
  "createdAt",
  "updatedAt"
FROM "products"
WHERE "isActive" = false;

DELETE FROM "products" WHERE "isActive" = false;

DROP INDEX "products_isActive_name_idx";
ALTER TABLE "products" DROP COLUMN "isActive";

CREATE INDEX "products_name_idx" ON "products"("name");
