#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { deflateSync, inflateSync } from "node:zlib";
import { isMain } from "./lib/cli.mjs";

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

export const MACHADO_DEUTERANOPIA_MATRIX = [
  [0.367322, 0.860646, -0.227968],
  [0.280085, 0.672501, 0.047413],
  [-0.01182, 0.04294, 0.968881],
];

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

const SRGB_TO_LINEAR_LUT = (() => {
  const lut = new Float32Array(256);
  for (let i = 0; i < 256; i++) {
    const c = i / 255;
    lut[i] = c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  }
  return lut;
})();

function linearToSrgbByte(v) {
  const clamped = v <= 0 ? 0 : v >= 1 ? 1 : v;
  const srgb = clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * clamped ** (1 / 2.4) - 0.055;
  return Math.max(0, Math.min(255, Math.round(srgb * 255)));
}

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function paethPredictor(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

export function decodePng(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 33) {
    throw new Error("Invalid PNG: buffer too short");
  }
  if (!buffer.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error("Invalid PNG: bad signature");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let compression = 0;
  let filterMethod = 0;
  let interlace = 0;
  let sawIhdr = false;
  let sawIend = false;
  const idatChunks = [];

  while (offset + 12 <= buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    if (dataEnd + 4 > buffer.length) {
      throw new Error(`Invalid PNG: truncated chunk "${type}"`);
    }
    const chunkData = buffer.subarray(dataStart, dataEnd);
    offset = dataEnd + 4;

    if (type === "IHDR") {
      if (length !== 13) throw new Error("Invalid PNG: IHDR length must be 13");
      width = chunkData.readUInt32BE(0);
      height = chunkData.readUInt32BE(4);
      bitDepth = chunkData[8];
      colorType = chunkData[9];
      compression = chunkData[10];
      filterMethod = chunkData[11];
      interlace = chunkData[12];
      sawIhdr = true;
    } else if (type === "IDAT") {
      idatChunks.push(chunkData);
    } else if (type === "IEND") {
      sawIend = true;
      break;
    }
  }

  if (!sawIhdr || !sawIend) throw new Error("Invalid PNG: missing IHDR or IEND chunk");
  if (width === 0 || height === 0) throw new Error("Invalid PNG: zero dimension");
  if (bitDepth !== 8) throw new Error(`Unsupported PNG bit depth ${bitDepth}`);
  if (compression !== 0 || filterMethod !== 0 || interlace !== 0) {
    throw new Error("Unsupported PNG compression/filter/interlace");
  }

  let bpp;
  if (colorType === 2) bpp = 3;
  else if (colorType === 6) bpp = 4;
  else if (colorType === 0) bpp = 1;
  else if (colorType === 4) bpp = 2;
  else throw new Error(`Unsupported PNG color type ${colorType}`);

  const raw = inflateSync(Buffer.concat(idatChunks));
  const stride = width * bpp;
  const expectedLength = height * (stride + 1);
  if (raw.length < expectedLength) {
    throw new Error(`Invalid PNG: decompressed data too short (${raw.length} < ${expectedLength})`);
  }

  const pixels = new Uint8Array(height * stride);
  for (let y = 0; y < height; y++) {
    const rowIn = y * (stride + 1);
    const filterType = raw[rowIn];
    const rowOut = y * stride;
    const prevOut = (y - 1) * stride;
    for (let x = 0; x < stride; x++) {
      const value = raw[rowIn + 1 + x];
      const left = x >= bpp ? pixels[rowOut + x - bpp] : 0;
      const up = y > 0 ? pixels[prevOut + x] : 0;
      const upLeft = y > 0 && x >= bpp ? pixels[prevOut + x - bpp] : 0;
      let recon;
      if (filterType === 0) recon = value;
      else if (filterType === 1) recon = (value + left) & 0xff;
      else if (filterType === 2) recon = (value + up) & 0xff;
      else if (filterType === 3) recon = (value + ((left + up) >> 1)) & 0xff;
      else if (filterType === 4) recon = (value + paethPredictor(left, up, upLeft)) & 0xff;
      else throw new Error(`Invalid PNG: unknown filter type ${filterType} at row ${y}`);
      pixels[rowOut + x] = recon;
    }
  }

  const rgb = new Uint8Array(width * height * 3);
  for (let i = 0; i < width * height; i++) {
    const dst = i * 3;
    if (colorType === 2) {
      rgb[dst] = pixels[dst];
      rgb[dst + 1] = pixels[dst + 1];
      rgb[dst + 2] = pixels[dst + 2];
    } else if (colorType === 6) {
      const src = i * 4;
      rgb[dst] = pixels[src];
      rgb[dst + 1] = pixels[src + 1];
      rgb[dst + 2] = pixels[src + 2];
    } else if (colorType === 0) {
      const v = pixels[i];
      rgb[dst] = v;
      rgb[dst + 1] = v;
      rgb[dst + 2] = v;
    } else {
      const v = pixels[i * 2];
      rgb[dst] = v;
      rgb[dst + 1] = v;
      rgb[dst + 2] = v;
    }
  }
  return { width, height, rgb };
}

export function encodeRgbPng(width, height, rgb) {
  const stride = width * 3;
  const scanlines = Buffer.alloc(height * (stride + 1));
  for (let y = 0; y < height; y++) {
    const outRow = y * (stride + 1);
    const inRow = y * stride;
    scanlines[outRow] = 1;
    for (let x = 0; x < stride; x++) {
      const left = x >= 3 ? rgb[inRow + x - 3] : 0;
      scanlines[outRow + 1 + x] = (rgb[inRow + x] - left) & 0xff;
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  return Buffer.concat([
    PNG_SIGNATURE,
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", deflateSync(scanlines, { level: 6 })),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

export function resizeRgb(srcWidth, srcHeight, srcRgb, dstWidth, dstHeight) {
  if (srcWidth === dstWidth && srcHeight === dstHeight) {
    return new Uint8Array(srcRgb);
  }
  const out = new Uint8Array(dstWidth * dstHeight * 3);
  const scaleX = srcWidth / dstWidth;
  const scaleY = srcHeight / dstHeight;

  if (dstWidth <= srcWidth && dstHeight <= srcHeight) {
    for (let dy = 0; dy < dstHeight; dy++) {
      const y0 = dy * scaleY;
      const y1 = (dy + 1) * scaleY;
      const iy0 = Math.floor(y0);
      const iy1 = Math.min(srcHeight - 1, Math.ceil(y1) - 1);
      for (let dx = 0; dx < dstWidth; dx++) {
        const x0 = dx * scaleX;
        const x1 = (dx + 1) * scaleX;
        const ix0 = Math.floor(x0);
        const ix1 = Math.min(srcWidth - 1, Math.ceil(x1) - 1);
        let r = 0;
        let g = 0;
        let b = 0;
        let weightSum = 0;
        for (let sy = iy0; sy <= iy1; sy++) {
          const wy = Math.min(y1, sy + 1) - Math.max(y0, sy);
          const rowOff = sy * srcWidth * 3;
          for (let sx = ix0; sx <= ix1; sx++) {
            const wx = Math.min(x1, sx + 1) - Math.max(x0, sx);
            const w = wx * wy;
            const p = rowOff + sx * 3;
            r += srcRgb[p] * w;
            g += srcRgb[p + 1] * w;
            b += srcRgb[p + 2] * w;
            weightSum += w;
          }
        }
        const inv = weightSum > 0 ? 1 / weightSum : 0;
        const dst = (dy * dstWidth + dx) * 3;
        out[dst] = Math.round(r * inv);
        out[dst + 1] = Math.round(g * inv);
        out[dst + 2] = Math.round(b * inv);
      }
    }
    return out;
  }

  for (let dy = 0; dy < dstHeight; dy++) {
    const sy = Math.max(0, Math.min(srcHeight - 1, (dy + 0.5) * scaleY - 0.5));
    const y0 = Math.floor(sy);
    const y1 = Math.min(srcHeight - 1, y0 + 1);
    const fy = sy - y0;
    for (let dx = 0; dx < dstWidth; dx++) {
      const sx = Math.max(0, Math.min(srcWidth - 1, (dx + 0.5) * scaleX - 0.5));
      const x0 = Math.floor(sx);
      const x1 = Math.min(srcWidth - 1, x0 + 1);
      const fx = sx - x0;
      const p00 = (y0 * srcWidth + x0) * 3;
      const p10 = (y0 * srcWidth + x1) * 3;
      const p01 = (y1 * srcWidth + x0) * 3;
      const p11 = (y1 * srcWidth + x1) * 3;
      const dst = (dy * dstWidth + dx) * 3;
      for (let c = 0; c < 3; c++) {
        const top = srcRgb[p00 + c] * (1 - fx) + srcRgb[p10 + c] * fx;
        const bot = srcRgb[p01 + c] * (1 - fx) + srcRgb[p11 + c] * fx;
        out[dst + c] = Math.round(top * (1 - fy) + bot * fy);
      }
    }
  }
  return out;
}

export function toRec709GreyscaleRgb(rgb) {
  const out = new Uint8Array(rgb.length);
  for (let i = 0; i < rgb.length; i += 3) {
    const yLin =
      0.2126 * SRGB_TO_LINEAR_LUT[rgb[i]] +
      0.7152 * SRGB_TO_LINEAR_LUT[rgb[i + 1]] +
      0.0722 * SRGB_TO_LINEAR_LUT[rgb[i + 2]];
    const byte = linearToSrgbByte(yLin);
    out[i] = byte;
    out[i + 1] = byte;
    out[i + 2] = byte;
  }
  return out;
}

export function toMachadoDeuteranopiaRgb(rgb) {
  const out = new Uint8Array(rgb.length);
  const m0 = MACHADO_DEUTERANOPIA_MATRIX[0];
  const m1 = MACHADO_DEUTERANOPIA_MATRIX[1];
  const m2 = MACHADO_DEUTERANOPIA_MATRIX[2];
  for (let i = 0; i < rgb.length; i += 3) {
    const r = SRGB_TO_LINEAR_LUT[rgb[i]];
    const g = SRGB_TO_LINEAR_LUT[rgb[i + 1]];
    const b = SRGB_TO_LINEAR_LUT[rgb[i + 2]];
    out[i] = linearToSrgbByte(m0[0] * r + m0[1] * g + m0[2] * b);
    out[i + 1] = linearToSrgbByte(m1[0] * r + m1[1] * g + m1[2] * b);
    out[i + 2] = linearToSrgbByte(m2[0] * r + m2[1] * g + m2[2] * b);
  }
  return out;
}

export function imageLumaStats(rgb) {
  const count = Math.floor(rgb.length / 3);
  if (count === 0) return { mean_luma: 0, min_luma: 0, max_luma: 0 };
  let sum = 0;
  let min = 255;
  let max = 0;
  for (let i = 0; i < rgb.length; i += 3) {
    const luma = 0.2126 * rgb[i] + 0.7152 * rgb[i + 1] + 0.0722 * rgb[i + 2];
    sum += luma;
    if (luma < min) min = luma;
    if (luma > max) max = luma;
  }
  return {
    mean_luma: Number((sum / count).toFixed(2)),
    min_luma: Number(min.toFixed(2)),
    max_luma: Number(max.toFixed(2)),
  };
}

export function buildVisualQaPackFromBuffer(pngBuffer, { stem = "capture", outDir } = {}) {
  const decoded = decodePng(pngBuffer);
  const rgb1080 = resizeRgb(decoded.width, decoded.height, decoded.rgb, 1920, 1080);
  const rgb720 = resizeRgb(decoded.width, decoded.height, decoded.rgb, 1280, 720);
  const greyscale = toRec709GreyscaleRgb(rgb720);
  const deuteranopia = toMachadoDeuteranopiaRgb(rgb720);

  const oracles = {
    rgb_1080p: {
      width: 1920,
      height: 1080,
      buffer: encodeRgbPng(1920, 1080, rgb1080),
      stats: imageLumaStats(rgb1080),
    },
    downscale_720p: {
      width: 1280,
      height: 720,
      buffer: encodeRgbPng(1280, 720, rgb720),
      stats: imageLumaStats(rgb720),
    },
    greyscale_rec709: {
      width: 1280,
      height: 720,
      buffer: encodeRgbPng(1280, 720, greyscale),
      stats: imageLumaStats(greyscale),
    },
    cvd_deuteranopia_machado: {
      width: 1280,
      height: 720,
      buffer: encodeRgbPng(1280, 720, deuteranopia),
      stats: imageLumaStats(deuteranopia),
    },
  };

  const manifest = {
    stem,
    source_width: decoded.width,
    source_height: decoded.height,
    upscaled_for_1080p: decoded.width < 1920 || decoded.height < 1080,
    oracles: {},
  };

  if (outDir) {
    mkdirSync(outDir, { recursive: true });
    const fileMap = {
      rgb_1080p: path.join(outDir, `${stem}_1080p_rgb.png`),
      downscale_720p: path.join(outDir, `${stem}_720p.png`),
      greyscale_rec709: path.join(outDir, `${stem}_greyscale.png`),
      cvd_deuteranopia_machado: path.join(outDir, `${stem}_deuteranopia.png`),
    };
    for (const [key, oracle] of Object.entries(oracles)) {
      writeFileSync(fileMap[key], oracle.buffer);
      manifest.oracles[key] = {
        path: fileMap[key],
        width: oracle.width,
        height: oracle.height,
        bytes: oracle.buffer.length,
        ...oracle.stats,
      };
    }
    const manifestPath = path.join(outDir, `${stem}_qa_pack.json`);
    writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
    manifest.manifest_path = manifestPath;
  } else {
    for (const [key, oracle] of Object.entries(oracles)) {
      manifest.oracles[key] = {
        width: oracle.width,
        height: oracle.height,
        bytes: oracle.buffer.length,
        ...oracle.stats,
      };
    }
  }

  return { manifest, oracles };
}

export function buildVisualQaPack(inputPngPath, { outDir = null, stem = null } = {}) {
  const absIn = path.resolve(inputPngPath);
  const resolvedStem = stem ?? path.basename(absIn, path.extname(absIn));
  const resolvedOut = outDir
    ? path.resolve(outDir)
    : path.join(path.dirname(absIn), `${resolvedStem}-qa-pack`);
  const { manifest } = buildVisualQaPackFromBuffer(readFileSync(absIn), {
    stem: resolvedStem,
    outDir: resolvedOut,
  });
  return { ...manifest, input: absIn, out: resolvedOut };
}

if (isMain(import.meta.url)) {
  try {
    const argv = process.argv.slice(2);
    let input = null;
    let outDir = null;
    let json = false;
    for (let i = 0; i < argv.length; i++) {
      if (argv[i] === "--out") outDir = argv[++i];
      else if (argv[i] === "--json") json = true;
      else if (!argv[i].startsWith("--") && !input) input = argv[i];
      else throw new Error(`Unknown argument: ${argv[i]}`);
    }
    if (!input) {
      console.log("Usage: node scripts/visual-qa-pack.mjs <input.png> [--out <dir>] [--json]");
      process.exitCode = 2;
    } else {
      const result = buildVisualQaPack(input, { outDir });
      if (json) console.log(JSON.stringify(result, null, 2));
      else {
        console.log(`visual-qa-pack -> ${result.out}`);
        for (const [k, v] of Object.entries(result.oracles)) {
          console.log(`  ${k}: ${v.width}x${v.height} mean_luma=${v.mean_luma} -> ${v.path}`);
        }
      }
    }
  } catch (error) {
    console.error(`visual-qa-pack: ${error?.message ?? error}`);
    process.exitCode = 1;
  }
}
