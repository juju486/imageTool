const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const multer = require('multer');

const app = express();
const PORT = 5172;

app.use(cors());
app.use(express.json({ limit: '200mb' }));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 200 * 1024 * 1024 }
});

const UPLOAD_DIR = path.join(__dirname, 'uploads');
const OUTPUT_DIR = path.join(__dirname, 'output');

if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

app.use('/uploads', express.static(UPLOAD_DIR));
app.use('/output', express.static(OUTPUT_DIR));

app.get('/api/images', (req, res) => {
  try {
    const dirPath = req.query.path;
    if (!dirPath || !fs.existsSync(dirPath)) {
      return res.status(400).json({ error: '无效的目录路径' });
    }
    const allowedExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.avif', '.svg'];
    const files = fs.readdirSync(dirPath).filter(f => {
      const ext = path.extname(f).toLowerCase();
      return allowedExts.includes(ext) && fs.statSync(path.join(dirPath, f)).isFile();
    });
    res.json({
      files: files.map(f => ({
        name: f,
        path: path.join(dirPath, f).replace(/\\/g, '/')
      }))
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/image/info', async (req, res) => {
  try {
    const imagePath = req.query.path;
    if (!imagePath || !fs.existsSync(imagePath)) {
      return res.status(400).json({ error: '图片不存在' });
    }
    const metadata = await sharp(imagePath).metadata();
    const stats = fs.statSync(imagePath);
    res.json({
      name: path.basename(imagePath),
      path: imagePath,
      format: metadata.format,
      width: metadata.width,
      height: metadata.height,
      size: stats.size,
      sizeFormatted: formatFileSize(stats.size)
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/image/crop', upload.single('image'), async (req, res) => {
  try {
    const { x, y, width, height } = req.body;
    if (!req.file) {
      const { path: imagePath } = req.body;
      if (!imagePath || !fs.existsSync(imagePath)) {
        return res.status(400).json({ error: '图片不存在' });
      }
      const outputName = `cropped_${Date.now()}.${path.extname(imagePath).slice(1)}`;
      const outputPath = path.join(OUTPUT_DIR, outputName);
      await sharp(imagePath)
        .extract({ left: parseInt(x), top: parseInt(y), width: parseInt(width), height: parseInt(height) })
        .toFile(outputPath);
      return res.json({ url: `/output/${outputName}`, path: outputPath, name: outputName });
    }
    const outputName = `cropped_${Date.now()}.png`;
    const outputPath = path.join(OUTPUT_DIR, outputName);
    await sharp(req.file.buffer)
      .extract({ left: parseInt(x), top: parseInt(y), width: parseInt(width), height: parseInt(height) })
      .toFile(outputPath);
    res.json({ url: `/output/${outputName}`, path: outputPath, name: outputName });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/image/resize', async (req, res) => {
  try {
    const { imagePath, width, height, fit } = req.body;
    if (!imagePath || !fs.existsSync(imagePath)) {
      return res.status(400).json({ error: '图片不存在' });
    }
    const ext = path.extname(imagePath).slice(1);
    const outputName = `resized_${Date.now()}.${ext}`;
    const outputPath = path.join(OUTPUT_DIR, outputName);
    const resizeOptions = {
      width: width ? parseInt(width) : undefined,
      height: height ? parseInt(height) : undefined,
      fit: fit || 'inside',
      withoutEnlargement: true
    };
    await sharp(imagePath).resize(resizeOptions).toFile(outputPath);
    res.json({ url: `/output/${outputName}`, path: outputPath, name: outputName });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/image/rotate', async (req, res) => {
  try {
    const { imagePath, angle } = req.body;
    if (!imagePath || !fs.existsSync(imagePath)) {
      return res.status(400).json({ error: '图片不存在' });
    }
    const ext = path.extname(imagePath).slice(1);
    const outputName = `rotated_${Date.now()}.${ext}`;
    const outputPath = path.join(OUTPUT_DIR, outputName);
    await sharp(imagePath).rotate(parseInt(angle)).toFile(outputPath);
    res.json({ url: `/output/${outputName}`, path: outputPath, name: outputName });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/image/compress', async (req, res) => {
  try {
    const { imagePath, quality, format } = req.body;
    if (!imagePath || !fs.existsSync(imagePath)) {
      return res.status(400).json({ error: '图片不存在' });
    }
    const targetFormat = format || path.extname(imagePath).slice(1);
    const outputName = `compressed_${Date.now()}.${targetFormat}`;
    const outputPath = path.join(OUTPUT_DIR, outputName);
    await sharp(imagePath)
      .toFormat(targetFormat, { quality: parseInt(quality) || 80 })
      .toFile(outputPath);
    const stats = fs.statSync(outputPath);
    const originalStats = fs.statSync(imagePath);
    res.json({
      url: `/output/${outputName}`,
      path: outputPath,
      name: outputName,
      originalSize: originalStats.size,
      compressedSize: stats.size,
      ratio: ((1 - stats.size / originalStats.size) * 100).toFixed(1)
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/image/batch-compress', async (req, res) => {
  try {
    const { images, quality, format, width, height } = req.body;
    if (!images || !Array.isArray(images) || images.length === 0) {
      return res.status(400).json({ error: '请选择图片' });
    }
    const batchId = Date.now();
    const batchDir = path.join(OUTPUT_DIR, `batch_${batchId}`);
    fs.mkdirSync(batchDir, { recursive: true });
    const results = [];
    for (const img of images) {
      try {
        if (!fs.existsSync(img.path)) {
          results.push({ name: img.name, error: '文件不存在', success: false });
          continue;
        }
        const targetFormat = format || path.extname(img.path).slice(1);
        const outputName = `${path.parse(img.name).name}.${targetFormat}`;
        const outputPath = path.join(batchDir, outputName);
        let pipeline = sharp(img.path);
        if (width || height) {
          pipeline = pipeline.resize({
            width: width ? parseInt(width) : undefined,
            height: height ? parseInt(height) : undefined,
            fit: 'inside',
            withoutEnlargement: true
          });
        }
        await pipeline
          .toFormat(targetFormat, { quality: parseInt(quality) || 80 })
          .toFile(outputPath);
        const stats = fs.statSync(outputPath);
        const originalStats = fs.statSync(img.path);
        results.push({
          name: img.name,
          outputName,
          success: true,
          originalSize: originalStats.size,
          compressedSize: stats.size,
          ratio: ((1 - stats.size / originalStats.size) * 100).toFixed(1)
        });
      } catch (e) {
        results.push({ name: img.name, error: e.message, success: false });
      }
    }
    res.json({ results, batchDir: `/output/batch_${batchId}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/image/save', async (req, res) => {
  try {
    const { imagePath, outputDir } = req.body;
    if (!imagePath || !fs.existsSync(imagePath)) {
      return res.status(400).json({ error: '源文件不存在' });
    }
    const name = path.basename(imagePath);
    const dest = path.join(outputDir || OUTPUT_DIR, name);
    fs.copyFileSync(imagePath, dest);
    res.json({ success: true, path: dest });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

app.listen(PORT, () => {
  console.log(`图片编辑服务已启动: http://localhost:${PORT}`);
});