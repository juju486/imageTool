<template>
  <div>
    <header class="header">
      <h1>🖼️ 图片编辑工具</h1>
      <div style="display:flex;gap:8px;">
        <button class="btn" @click="selectRootFolder">📁 选择根文件夹</button>
        <button class="btn btn-primary" @click="toggleBatchPanel" v-if="images.length > 0">
          📦 批量处理 ({{ images.length }})
        </button>
      </div>
    </header>

    <div class="main-container">
      <aside class="sidebar">
        <div class="sidebar-header">
          <div style="display:flex;align-items:center;gap:6px;margin-bottom:8px;">
            <button class="btn btn-sm" @click="goBack" :disabled="!currentDirHandle">⮪ 返回上级</button>
            <h3 style="margin:0;">文件浏览器</h3>
          </div>
          <div v-if="currentPath" style="font-size:11px;color:var(--text-secondary);word-break:break-all;background:#f1f5f9;padding:6px;border-radius:4px;">
            {{ currentPath }}
          </div>
        </div>
        <div class="file-list" v-if="fileTree.length > 0">
          <div
            v-for="item in fileTree"
            :key="item.path"
            class="file-item"
            :class="{ active: activeImage && activeImage.path === item.path, folder: item.isFolder }"
            @click="item.isFolder ? openFolder(item) : selectImage(item)"
          >
            <div class="thumb folder-icon" v-if="item.isFolder">
              📁
            </div>
            <img class="thumb" :src="item.thumbUrl" @error="onThumbError" v-if="item.thumbUrl" />
            <div class="thumb thumb-placeholder" v-else>🖼</div>
            <div class="file-info">
              <div class="file-name">{{ item.name }}</div>
              <div class="file-meta">{{ item.sizeFormatted || '文件夹' }}</div>
            </div>
            <span v-if="item.isFolder" style="font-size:14px;color:var(--text-secondary);">▶</span>
          </div>
        </div>
        <div class="empty-state" v-else>
          <div class="icon">📁</div>
          <p>点击"📁 选择根文件夹"<br/>选择包含图片的文件夹</p>
        </div>
      </aside>

      <div class="editor-area">
        <div class="toolbar" v-if="activeImage">
          <div class="toolbar-group">
            <button class="btn btn-sm" @click="startCrop" :class="{ 'btn-primary': cropMode }">
              ✂️ 裁剪
            </button>
            <button class="btn btn-sm" @click="rotateLeft" title="左旋转90°">↺</button>
            <button class="btn btn-sm" @click="rotateRight" title="右旋转90°">↻</button>
          </div>

          <div class="toolbar-group">
            <div class="zoom-slider">
              <button class="btn btn-sm btn-icon" @click="zoomOut" :disabled="zoom <= 10">−</button>
              <input type="range" min="10" max="300" :value="zoom" @input="onZoomChange" />
              <span class="zoom-value">{{ zoom }}%</span>
              <button class="btn btn-sm btn-icon" @click="zoomIn" :disabled="zoom >= 300">+</button>
              <button class="btn btn-sm" @click="resetZoom">重置</button>
            </div>
          </div>

          <div class="toolbar-group">
            <label>压缩质量:</label>
            <select v-model="compressQuality" style="padding:4px 8px;border-radius:4px;border:1px solid var(--border);font-size:12px;">
              <option :value="100">100% (无损)</option>
              <option :value="90">90%</option>
              <option :value="80">80%</option>
              <option :value="70">70%</option>
              <option :value="60">60%</option>
              <option :value="50">50%</option>
              <option :value="40">40%</option>
              <option :value="30">30%</option>
            </select>
            <label>格式:</label>
            <select v-model="compressFormat" style="padding:4px 8px;border-radius:4px;border:1px solid var(--border);font-size:12px;">
              <option value="">保持原格式</option>
              <option value="jpeg">JPEG</option>
              <option value="png">PNG</option>
              <option value="webp">WebP</option>
              <option value="avif">AVIF</option>
            </select>
            <button class="btn btn-sm btn-primary" @click="compressCurrent" :disabled="compressing">
              {{ compressing ? '压缩中...' : '🗜️ 压缩当前图片' }}
            </button>
          </div>

          <div class="toolbar-group">
            <button class="btn btn-sm" @click="downloadImage">💾 下载</button>
          </div>

          <button v-if="cropMode" class="btn btn-sm btn-primary" @click="doCrop">✅ 确认裁剪</button>
          <button v-if="cropMode" class="btn btn-sm" @click="cancelCrop">❌ 取消</button>

          <div v-if="cropMode" class="toolbar-group" style="margin-left:auto;">
            <span style="font-size:12px;color:var(--text-secondary);margin-right:6px;">比例:</span>
            <button
              v-for="ratio in cropRatios"
              :key="ratio.value"
              class="btn btn-sm"
              :class="{ 'btn-primary': cropAspectRatio === ratio.value }"
              @click="setCropRatio(ratio.value)"
            >{{ ratio.label }}</button>
          </div>
        </div>

        <div class="canvas-container" ref="canvasContainer">
          <template v-if="activeImage && !cropMode">
            <img
              ref="displayImage"
              :src="displaySrc"
              :style="{ transform: `scale(${zoom / 100})`, transition: 'transform 0.1s' }"
              @load="onImageLoad"
            />
            <div class="image-info-overlay" v-if="imageInfo">
              {{ imageInfo.width }} × {{ imageInfo.height }} | {{ imageInfo.format?.toUpperCase() }} | {{ imageInfo.sizeFormatted }}
            </div>
          </template>

          <div v-if="cropMode" class="cropper-wrapper">
            <img ref="cropperImage" :src="displaySrc" />
          </div>

          <div class="empty-state" v-if="!activeImage">
            <div class="icon">🖼️</div>
            <h3>选择一张图片开始编辑</h3>
            <p>从左侧列表选择图片，或在工具栏中选择文件夹</p>
          </div>
        </div>

        <div class="batch-panel" v-if="showBatchPanel">
          <h3>📦 批量压缩处理</h3>
          <div class="batch-settings">
            <div class="form-group">
              <label>压缩质量</label>
              <select v-model="batchQuality" style="width:120px;">
                <option :value="100">100%</option>
                <option :value="90">90%</option>
                <option :value="80" selected>80%</option>
                <option :value="70">70%</option>
                <option :value="60">60%</option>
                <option :value="50">50%</option>
                <option :value="40">40%</option>
                <option :value="30">30%</option>
              </select>
            </div>
            <div class="form-group">
              <label>目标格式</label>
              <select v-model="batchFormat" style="width:120px;">
                <option value="">保持原格式</option>
                <option value="jpeg">JPEG</option>
                <option value="png">PNG</option>
                <option value="webp">WebP</option>
                <option value="avif">AVIF</option>
              </select>
            </div>
            <div class="form-group">
              <label>目标宽度 (px)</label>
              <input type="number" v-model="batchWidth" placeholder="不限制" style="width:100px;" />
            </div>
            <div class="form-group">
              <label>目标高度 (px)</label>
              <input type="number" v-model="batchHeight" placeholder="不限制" style="width:100px;" />
            </div>
            <button class="btn btn-primary" @click="batchCompress" :disabled="batchProcessing">
              {{ batchProcessing ? '处理中...' : `🚀 批量压缩 (${images.length} 张)` }}
            </button>
          </div>
          <div class="batch-results" v-if="batchResults.length > 0">
            <div class="batch-result-item" v-for="r in batchResults" :key="r.name">
              <span>{{ r.name }}</span>
              <span :class="r.success ? 'success' : 'error'">
                {{ r.success ? `压缩 ${r.ratio}% ${r.saved ? '✅已保存' : '⬇浏览器下载'}` : r.error }}
              </span>
            </div>
          </div>
          <div class="batch-summary" v-if="batchSummary">
            {{ batchSummary }}
          </div>
        </div>
      </div>
    </div>

    <div class="toast" :class="toast.type" v-if="toast.show">{{ toast.message }}</div>
  </div>
</template>

<script>
import Cropper from 'cropperjs'
import { markRaw } from 'vue'
import 'cropperjs/dist/cropper.min.css'

export default {
  name: 'App',
  data() {
    return {
      fileTree: [],
      images: [],
      activeImage: null,
      rootHandle: null,
      currentDirHandle: null,
      currentPath: '',
      pathStack: [],
      dirHandleMap: {},
      displaySrc: '',
      zoom: 100,
      cropMode: false,
      cropper: null,
      cropAspectRatio: null,
      cropRatios: [
        { label: '自由', value: null },
        { label: '1:1', value: 1/1 },
        { label: '4:3', value: 4/3 },
        { label: '3:4', value: 3/4 },
        { label: '16:9', value: 16/9 },
        { label: '9:16', value: 9/16 },
        { label: '3:2', value: 3/2 },
        { label: '2:3', value: 2/3 }
      ],
      imageInfo: null,
      compressing: false,
      compressQuality: 80,
      compressFormat: '',
      showBatchPanel: false,
      batchQuality: 80,
      batchFormat: '',
      batchWidth: null,
      batchHeight: null,
      batchProcessing: false,
      batchResults: [],
      batchSummary: '',
      toast: { show: false, message: '', type: 'info' }
    }
  },
  methods: {
    isImageFile(name) {
      const ext = '.' + name.split('.').pop()?.toLowerCase()
      const allowedExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.avif', '.svg', '.heic', 'heif']
      return allowedExts.includes(ext)
    },
    async scanDirectory(dirHandle, parentPath = '') {
      this.dirHandleMap[parentPath || dirHandle.name] = dirHandle
      const items = []
      const folders = []
      const images = []
      for await (const entry of dirHandle.values()) {
        const entryPath = parentPath ? `${parentPath}/${entry.name}` : entry.name
        if (entry.kind === 'directory') {
          this.dirHandleMap[entryPath] = markRaw(entry)
          folders.push({
            name: entry.name,
            path: entryPath,
            isFolder: true,
            handle: markRaw(entry)
          })
        } else if (entry.kind === 'file' && this.isImageFile(entry.name)) {
          const parentPathForFile = parentPath || dirHandle.name
          images.push({
            name: entry.name,
            path: entryPath,
            isFolder: false,
            handle: markRaw(entry),
            parentPath: parentPathForFile
          })
        }
      }
      items.push(...folders.sort((a, b) => a.name.localeCompare(b.name)))
      items.push(...images.sort((a, b) => a.name.localeCompare(b.name)))
      return items
    },
    async selectRootFolder() {
      try {
        if (!window.showDirectoryPicker) {
          const isLocalhost = location.hostname === 'localhost' || location.hostname === '127.0.0.1'
          if (!isLocalhost) {
            this.showToast('请使用 localhost 访问，不要用 IP 地址。File System Access API 需要安全上下文', 'error')
          } else {
            this.showToast('您的浏览器不支持 File System Access API，请使用 Chrome/Edge', 'error')
          }
          return
        }
        const dirHandle = await window.showDirectoryPicker({ mode: 'readwrite' })
        this.rootHandle = dirHandle
        this.pathStack = []
        this.dirHandleMap = {}
        this.dirHandleMap[dirHandle.name] = dirHandle
        await this.openFolder({ handle: dirHandle, path: dirHandle.name })
        this.showToast(`已加载 ${this.fileTree.length} 个项目`, 'success')
      } catch (err) {
        if (err.name !== 'AbortError') {
          this.showToast('选择文件夹失败: ' + err.message, 'error')
        }
      }
    },
    async openFolder(item) {
      try {
        if (this.currentDirHandle) {
          this.pathStack.push(this.currentDirHandle)
        }
        this.currentDirHandle = item.handle
        this.currentPath = item.path || item.handle.name
        this.fileTree = await this.scanDirectory(item.handle, this.currentPath)
        this.collectImages()
        this.loadThumbnails()
      } catch (err) {
        this.showToast('打开文件夹失败: ' + err.message, 'error')
      }
    },
    async goBack() {
      if (this.pathStack.length === 0) return
      const prevHandle = this.pathStack.pop()
      this.currentDirHandle = prevHandle
      if (prevHandle === this.rootHandle) {
        this.currentPath = this.rootHandle.name
      } else {
        this.currentPath = this.pathStack.map(p => p.name).join('/') + (this.pathStack.length > 0 ? '/' : '') + prevHandle.name
      }
      this.fileTree = await this.scanDirectory(prevHandle, this.currentPath.replace(/\/[^\/]+$/, ''))
      this.collectImages()
      this.loadThumbnails()
    },
    collectImages() {
      this.images = this.fileTree.filter(item => !item.isFolder)
    },
    async loadThumbnails() {
      for (const item of this.images) {
        if (!item.thumbUrl) {
          try {
            const file = await item.handle.getFile()
            item.thumbUrl = URL.createObjectURL(file)
          } catch (e) {
            // ignore
          }
        }
      }
    },
    onThumbError(event) {
      event.target.style.display = 'none'
    },
    async loadImagePreview(item) {
      this.activeImage = item
      this.cropMode = false
      if (this.cropper) {
        this.cropper.destroy()
        this.cropper = null
      }
      this.zoom = 100
      this.imageInfo = null
      try {
        const file = await item.handle.getFile()
        const url = URL.createObjectURL(file)
        this.displaySrc = url
        if (this._prevObjectUrl) URL.revokeObjectURL(this._prevObjectUrl)
        this._prevObjectUrl = url
        const img = new Image()
        img.onload = () => {
          this.imageInfo = {
            width: img.naturalWidth,
            height: img.naturalHeight,
            format: this.activeImage.name.split('.').pop(),
            sizeFormatted: this.formatFileSize(file.size)
          }
        }
        img.src = url
      } catch (err) {
        this.showToast('加载图片失败: ' + err.message, 'error')
      }
    },
    selectImage(item) {
      this.loadImagePreview(item)
    },
    onImageLoad() {
    },
    zoomIn() {
      this.zoom = Math.min(300, this.zoom + 10)
    },
    zoomOut() {
      this.zoom = Math.max(10, this.zoom - 10)
    },
    onZoomChange(e) {
      this.zoom = parseInt(e.target.value)
    },
    resetZoom() {
      this.zoom = 100
    },
    startCrop() {
      if (!this.activeImage || !this.displaySrc) return
      this.cropMode = true
      this.cropAspectRatio = null
      this.$nextTick(() => {
        this.initCropper()
      })
    },
    initCropper() {
      if (this.cropper) this.cropper.destroy()
      const img = this.$refs.cropperImage
      if (!img) return
      this.cropper = new Cropper(img, {
        viewMode: 1,
        dragMode: 'move',
        autoCropArea: 0.8,
        responsive: true,
        background: false,
        aspectRatio: this.cropAspectRatio || NaN
      })
    },
    setCropRatio(value) {
      this.cropAspectRatio = value
      if (this.cropper) {
        this.cropper.setAspectRatio(value || NaN)
      }
    },
    async doCrop() {
      if (!this.cropper) return
      const canvas = this.cropper.getCroppedCanvas()
      if (!canvas) return
      const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
      const url = URL.createObjectURL(blob)
      this.displaySrc = url
      if (this._prevObjectUrl) URL.revokeObjectURL(this._prevObjectUrl)
      this._prevObjectUrl = url
      this.cropMode = false
      this.cropper.destroy()
      this.cropper = null
      this.zoom = 100
      this.showToast('裁剪成功', 'success')
    },
    cancelCrop() {
      this.cropMode = false
      this.cropAspectRatio = null
      if (this.cropper) {
        this.cropper.destroy()
        this.cropper = null
      }
    },
    async rotateLeft() {
      await this.rotateImage(-90)
    },
    async rotateRight() {
      await this.rotateImage(90)
    },
    async rotateImage(angle) {
      if (!this.activeImage || !this.displaySrc) return
      try {
        const img = new Image()
        img.crossOrigin = 'anonymous'
        img.src = this.displaySrc
        await new Promise((resolve, reject) => {
          img.onload = resolve
          img.onerror = reject
        })
        const canvas = document.createElement('canvas')
        const rad = (angle * Math.PI) / 180
        const sin = Math.abs(Math.sin(rad))
        const cos = Math.abs(Math.cos(rad))
        canvas.width = img.width * cos + img.height * sin
        canvas.height = img.width * sin + img.height * cos
        const ctx = canvas.getContext('2d')
        ctx.translate(canvas.width / 2, canvas.height / 2)
        ctx.rotate(rad)
        ctx.drawImage(img, -img.width / 2, -img.height / 2)
        const url = canvas.toDataURL('image/png')
        this.displaySrc = url
        if (this._prevObjectUrl) URL.revokeObjectURL(this._prevObjectUrl)
        this._prevObjectUrl = url
        this.zoom = 100
        this.showToast('旋转成功', 'success')
      } catch (err) {
        this.showToast('旋转失败', 'error')
      }
    },
    async getFileFromHandle(handle) {
      if (handle?.getFile) return await handle.getFile()
      if (handle?.file) return handle.file
      return null
    },
    async compressCurrent() {
      if (!this.activeImage || !this.displaySrc) return
      this.compressing = true
      try {
        const img = new Image()
        img.crossOrigin = 'anonymous'
        img.src = this.displaySrc
        await new Promise((resolve, reject) => {
          img.onload = resolve
          img.onerror = reject
        })
        const canvas = document.createElement('canvas')
        canvas.width = img.width
        canvas.height = img.height
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0)
        const format = this.compressFormat || 'image/png'
        const mimeType = format === 'jpeg' ? 'image/jpeg' : format === 'webp' ? 'image/webp' : 'image/png'
        const blob = await new Promise(resolve => canvas.toBlob(resolve, mimeType, this.compressQuality / 100))
        const url = URL.createObjectURL(blob)
        this.displaySrc = url
        if (this._prevObjectUrl) URL.revokeObjectURL(this._prevObjectUrl)
        this._prevObjectUrl = url
        const originalFile = await this.getFileFromHandle(this.activeImage.handle)
        const ratio = originalFile ? ((1 - blob.size / originalFile.size) * 100).toFixed(1) : '?'
        this.showToast(`压缩完成: ${this.formatFileSize(blob.size)} (减少 ${ratio}%)`, 'success')
      } catch (err) {
        this.showToast('压缩失败: ' + err.message, 'error')
      }
      this.compressing = false
    },
    async saveBlobToOriginalFolder(blob, fileName, parentPath) {
      try {
        const dirHandle = this.dirHandleMap[parentPath]
        if (!dirHandle) {
          this.showToast(`找不到目录: ${parentPath}，将使用浏览器下载`, 'info')
          this.fallbackDownload(blob, fileName)
          return
        }
        const fileHandle = await dirHandle.getFileHandle(fileName, { create: true })
        const writable = await fileHandle.createWritable()
        await writable.write(blob)
        await writable.close()
        return true
      } catch (err) {
        this.showToast(`保存到原文件夹失败: ${err.message}，将使用浏览器下载`, 'info')
        this.fallbackDownload(blob, fileName)
        return false
      }
    },
    fallbackDownload(blob, fileName, url) {
      const a = document.createElement('a')
      a.href = blob ? URL.createObjectURL(blob) : url
      a.download = fileName
      a.click()
      if (blob) setTimeout(() => URL.revokeObjectURL(a.href), 2000)
    },
    async downloadImage() {
      if (!this.displaySrc || !this.activeImage) return
      const ext = this.compressFormat || (this.activeImage.name.split('.').pop())
      const fileName = `edited_${Date.now()}.${ext}`
      const parentPath = this.activeImage.parentPath || this.currentPath
      try {
        const res = await fetch(this.displaySrc)
        const blob = await res.blob()
        const saved = await this.saveBlobToOriginalFolder(blob, fileName, parentPath)
        if (saved) {
          this.showToast(`已保存到原文件夹: ${fileName}`, 'success')
        }
      } catch {
        this.fallbackDownload(null, fileName, this.displaySrc)
      }
    },
    toggleBatchPanel() {
      this.showBatchPanel = !this.showBatchPanel
      this.batchResults = []
      this.batchSummary = ''
    },
    async batchCompress() {
      if (this.images.length === 0) return
      this.batchProcessing = true
      this.batchResults = []
      this.batchSummary = ''
      let totalOriginal = 0
      let totalCompressed = 0
      let successCount = 0
      for (const img of this.images) {
        try {
          const file = await this.getFileFromHandle(img.handle)
          if (!file) {
            this.batchResults.push({ name: img.name, success: false, error: '无法读取文件' })
            continue
          }
          const url = URL.createObjectURL(file)
          const image = new Image()
          image.src = url
          await new Promise((resolve, reject) => {
            image.onload = resolve
            image.onerror = reject
          })
          const canvas = document.createElement('canvas')
          let w = image.width
          let h = image.height
          if (this.batchWidth || this.batchHeight) {
            const targetW = this.batchWidth ? parseInt(this.batchWidth) : w
            const targetH = this.batchHeight ? parseInt(this.batchHeight) : h
            const ratio = Math.min(targetW / w, targetH / h)
            w = Math.round(w * ratio)
            h = Math.round(h * ratio)
          }
          canvas.width = w
          canvas.height = h
          const ctx = canvas.getContext('2d')
          ctx.drawImage(image, 0, 0, w, h)
          const format = this.batchFormat || 'image/png'
          const mimeType = format === 'jpeg' ? 'image/jpeg' : format === 'webp' ? 'image/webp' : 'image/png'
          const blob = await new Promise(resolve => canvas.toBlob(resolve, mimeType, this.batchQuality / 100))
          URL.revokeObjectURL(url)
          const ratio = ((1 - blob.size / file.size) * 100).toFixed(1)
          totalOriginal += file.size
          totalCompressed += blob.size
          successCount++
          const ext = this.batchFormat || img.name.split('.').pop()
          const fileName = img.name.replace(/\.[^.]+$/, '') + '_compressed.' + ext
          const parentPath = img.parentPath || this.currentPath
          const saved = await this.saveBlobToOriginalFolder(blob, fileName, parentPath)
          this.batchResults.push({ name: img.name, success: true, ratio, saved: !!saved })
        } catch (err) {
          this.batchResults.push({ name: img.name, success: false, error: err.message })
        }
      }
      const totalRatio = totalOriginal > 0 ? ((1 - totalCompressed / totalOriginal) * 100).toFixed(1) : '0'
      this.batchSummary = `处理完成: ${successCount}/${this.images.length} 张成功, 总计节省 ${totalRatio}% 空间`
      this.batchProcessing = false
    },
    onThumbError(e) {
      e.target.style.display = 'none'
    },
    showToast(message, type = 'info') {
      this.toast = { show: true, message, type }
      setTimeout(() => { this.toast.show = false }, 2500)
    },
    formatFileSize(bytes) {
      if (!bytes) return '0 B'
      if (bytes < 1024) return bytes + ' B'
      if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
      return (bytes / (1024 * 1024)).toFixed(2) + ' MB'
    }
  }
}
</script>