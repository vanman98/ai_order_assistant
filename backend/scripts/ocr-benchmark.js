#!/usr/bin/env node
/**
 * OCR benchmark runner — see backend/test-data/ocr-benchmark/README.md
 *
 * Calls POST {BASE_URL}/order-intake/analyze for every image under
 * backend/test-data/ocr-benchmark/images/, compares the result against the
 * matching ground-truth file under backend/test-data/ocr-benchmark/ground-truth/,
 * prints a report, and writes backend/test-data/ocr-benchmark/report.json.
 *
 * Plain Node script (no ts-node needed) — uses global fetch/FormData/Blob
 * (Node 18+).
 */

const fs = require('fs');
const path = require('path');

const BASE_URL =
  process.env.OCR_BENCHMARK_BASE_URL || 'http://localhost:3000/api';

const ROOT = path.join(__dirname, '..', 'test-data', 'ocr-benchmark');
const IMAGES_DIR = path.join(ROOT, 'images');
const GT_DIR = path.join(ROOT, 'ground-truth');
const REPORT_PATH = path.join(ROOT, 'report.json');

function normalize(str) {
  return (str || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // strip diacritics for fuzzy compare
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Simple Levenshtein-based similarity, 0..1 (1 = identical).
function similarity(a, b) {
  const s1 = normalize(a);
  const s2 = normalize(b);
  if (!s1 && !s2) return 1;
  if (!s1 || !s2) return 0;
  const m = s1.length;
  const n = s2.length;
  const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));
  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      const cost = s1[i - 1] === s2[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      );
    }
  }
  const dist = dp[m][n];
  const maxLen = Math.max(m, n);
  return maxLen === 0 ? 1 : 1 - dist / maxLen;
}

async function analyzeImage(imagePath) {
  const buffer = fs.readFileSync(imagePath);
  const blob = new Blob([buffer], { type: 'image/jpeg' });
  const form = new FormData();
  form.append('image', blob, path.basename(imagePath));

  const res = await fetch(`${BASE_URL}/order-intake/analyze`, {
    method: 'POST',
    body: form,
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(
      `analyze failed (${res.status} ${res.statusText}) for ${path.basename(imagePath)}: ${text}`,
    );
  }
  return res.json();
}

// Greedily match each ground-truth item to the best remaining extracted item.
function matchItems(gtItems, extractedItems) {
  const remaining = extractedItems.map((item, idx) => ({ item, idx }));
  const matches = [];

  for (const gt of gtItems) {
    let bestIdx = -1;
    let bestScore = -1;
    for (let i = 0; i < remaining.length; i++) {
      const candidate = remaining[i].item;
      const nameScore = similarity(
        gt.productNameGuess,
        candidate.rawProductName,
      );
      const qtyScore =
        gt.quantity != null && candidate.quantity === gt.quantity ? 0.3 : 0;
      const score = nameScore + qtyScore;
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    if (bestIdx === -1 || bestScore < 0.25) {
      matches.push({ gt, extracted: null, nameSimilarity: 0 });
      continue;
    }
    const matched = remaining.splice(bestIdx, 1)[0].item;
    matches.push({
      gt,
      extracted: matched,
      nameSimilarity: similarity(gt.productNameGuess, matched.rawProductName),
    });
  }

  return matches;
}

function summarize(matches) {
  const total = matches.length;
  if (total === 0) {
    return {
      total: 0,
      recall: null,
      quantityAccuracy: null,
      unitAccuracy: null,
      avgNameSimilarity: null,
    };
  }
  const found = matches.filter((m) => m.extracted !== null);
  const withQty = found.filter((m) => m.gt.quantity != null);
  const qtyCorrect = withQty.filter(
    (m) => m.extracted.quantity === m.gt.quantity,
  );
  const withUnit = found.filter((m) => m.gt.unit != null);
  const unitCorrect = withUnit.filter(
    (m) =>
      normalize(m.extracted.unit || '') === normalize(m.gt.unit || ''),
  );
  const avgNameSimilarity =
    found.reduce((sum, m) => sum + m.nameSimilarity, 0) /
    Math.max(found.length, 1);

  return {
    total,
    matchedCount: found.length,
    recall: found.length / total,
    quantityAccuracy:
      withQty.length > 0 ? qtyCorrect.length / withQty.length : null,
    unitAccuracy:
      withUnit.length > 0 ? unitCorrect.length / withUnit.length : null,
    avgNameSimilarity,
  };
}

function fmtPct(v) {
  return v == null ? 'n/a' : `${(v * 100).toFixed(1)}%`;
}

async function main() {
  if (!fs.existsSync(IMAGES_DIR) || !fs.existsSync(GT_DIR)) {
    console.error(
      `Không tìm thấy thư mục ảnh/ground-truth. Kỳ vọng:\n  ${IMAGES_DIR}\n  ${GT_DIR}`,
    );
    process.exit(1);
  }

  const imageFiles = fs
    .readdirSync(IMAGES_DIR)
    .filter((f) => /\.(jpe?g|png|webp)$/i.test(f))
    .sort();

  if (imageFiles.length === 0) {
    console.error(`Không có ảnh nào trong ${IMAGES_DIR}`);
    process.exit(1);
  }

  const report = { baseUrl: BASE_URL, images: [] };

  for (const imageFile of imageFiles) {
    const gtPath = path.join(
      GT_DIR,
      imageFile.replace(/\.(jpe?g|png|webp)$/i, '.json'),
    );
    if (!fs.existsSync(gtPath)) {
      console.warn(`  [bỏ qua] Không có ground-truth cho ${imageFile}`);
      continue;
    }
    const gt = JSON.parse(fs.readFileSync(gtPath, 'utf-8'));

    process.stdout.write(`Đang phân tích ${imageFile} ... `);
    let extraction;
    try {
      extraction = await analyzeImage(path.join(IMAGES_DIR, imageFile));
    } catch (err) {
      console.log('LỖI');
      console.error(`  ${err.message}`);
      report.images.push({ imageFile, error: err.message });
      continue;
    }
    console.log(`xong (${extraction.items.length} dòng OCR đọc được)`);

    const allMatches = matchItems(gt.items, extraction.items);
    const reliableGt = gt.items.filter((i) => i.confidence !== 'low');
    const reliableMatches = matchItems(reliableGt, extraction.items);

    const imageReport = {
      imageFile,
      groundTruthItemCount: gt.items.length,
      reliableGroundTruthItemCount: reliableGt.length,
      extractedItemCount: extraction.items.length,
      imageQuality: extraction.imageQuality,
      overall: summarize(allMatches),
      reliableOnly: summarize(reliableMatches),
      details: allMatches.map((m) => ({
        groundTruth: m.gt.productNameGuess,
        groundTruthConfidence: m.gt.confidence,
        groundTruthQuantity: m.gt.quantity,
        groundTruthUnit: m.gt.unit,
        extractedRawProductName: m.extracted ? m.extracted.rawProductName : null,
        extractedQuantity: m.extracted ? m.extracted.quantity : null,
        extractedUnit: m.extracted ? m.extracted.unit : null,
        nameSimilarity: Number(m.nameSimilarity.toFixed(2)),
        matched: m.extracted !== null,
      })),
    };
    report.images.push(imageReport);
  }

  const valid = report.images.filter((i) => !i.error);
  const agg = (key, subKey) => {
    const values = valid
      .map((i) => i[key][subKey])
      .filter((v) => v != null);
    return values.length > 0
      ? values.reduce((a, b) => a + b, 0) / values.length
      : null;
  };

  console.log('\n=== TỔNG KẾT ===');
  console.log('Ảnh                | Recall | SL đúng | Đơn vị đúng | Tên giống TB');
  for (const img of valid) {
    console.log(
      `${img.imageFile.padEnd(19)} | ${fmtPct(img.overall.recall).padStart(6)} | ${fmtPct(img.overall.quantityAccuracy).padStart(7)} | ${fmtPct(img.overall.unitAccuracy).padStart(11)} | ${fmtPct(img.overall.avgNameSimilarity)}`,
    );
  }
  console.log('---');
  console.log(
    `Trung bình (tất cả dòng ground-truth): recall=${fmtPct(agg('overall', 'recall'))}, số lượng đúng=${fmtPct(agg('overall', 'quantityAccuracy'))}, đơn vị đúng=${fmtPct(agg('overall', 'unitAccuracy'))}, tên giống TB=${fmtPct(agg('overall', 'avgNameSimilarity'))}`,
  );
  console.log(
    `Trung bình (chỉ dòng ground-truth đáng tin cậy — confidence != low): recall=${fmtPct(agg('reliableOnly', 'recall'))}, số lượng đúng=${fmtPct(agg('reliableOnly', 'quantityAccuracy'))}, đơn vị đúng=${fmtPct(agg('reliableOnly', 'unitAccuracy'))}, tên giống TB=${fmtPct(agg('reliableOnly', 'avgNameSimilarity'))}`,
  );

  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2), 'utf-8');
  console.log(`\nĐã lưu báo cáo chi tiết: ${REPORT_PATH}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
