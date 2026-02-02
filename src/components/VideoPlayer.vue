<template>
  <div class="video-player">
    <video
      ref="videoEl"
      :poster="poster"
      controls
      playsinline
      :muted="muted"
      class="video-player__el"
      @play="$emit('play')"
      @pause="$emit('pause')"
      @ended="$emit('ended')"
      @timeupdate="onTimeUpdate"
    >
      <!-- для mp4 можно оставить source, но для HLS мы ставим src через hls/native -->
      <source v-if="isMp4" :src="src" />
      Your browser does not support the video tag.
    </video>

    <div v-if="error" class="video-player__error">
      {{ error }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import Hls from 'hls.js'

const props = defineProps({
  src: { type: String, required: true }, // m3u8 or mp4
  poster: { type: String, default: '' },
  autoplay: { type: Boolean, default: false },
  muted: { type: Boolean, default: true },
  startTime: { type: Number, default: 0 }
})

const emit = defineEmits(['ready', 'play', 'pause', 'ended', 'timeupdate', 'error'])

const videoEl = ref(null)
const error = ref(null)

let hls = null
let onHlsError = null

const isMp4 = computed(() => (props.src || '').toLowerCase().endsWith('.mp4'))
const isHls = computed(() => (props.src || '').toLowerCase().endsWith('.m3u8'))

function destroyHls() {
  if (!hls) return
  try {
    if (onHlsError) hls.off(Hls.Events.ERROR, onHlsError)
    hls.destroy()
  } catch {}
  hls = null
  onHlsError = null
}

async function applyStartAndAutoplay() {
  const v = videoEl.value
  if (!v) return

  // startTime
  if (props.startTime && Number.isFinite(props.startTime)) {
    try {
      v.currentTime = props.startTime
    } catch {}
  }

  emit('ready')

  // autoplay
  if (props.autoplay) {
    try {
      v.muted = props.muted
      await v.play()
    } catch (e) {
      emit('error', e)
    }
  }
}

function attach() {
  error.value = null

  const v = videoEl.value
  const src = props.src

  if (!v || !src) return

  // сбрасываем предыдущие режимы
  destroyHls()

  // Native HLS support (Safari)
  const canPlayNativeHls = v.canPlayType('application/vnd.apple.mpegurl') !== ''

  // HLS.js
  if (isHls.value && !canPlayNativeHls && Hls.isSupported()) {
    hls = new Hls()

    onHlsError = (event, data) => {
      emit('error', { event, data })
      error.value = data?.fatal ? 'Playback error (HLS fatal).' : 'Playback error (HLS).'
    }

    hls.on(Hls.Events.ERROR, onHlsError)

    hls.loadSource(src)
    hls.attachMedia(v)

    hls.on(Hls.Events.MANIFEST_PARSED, () => {
      applyStartAndAutoplay()
    })

    return
  }

  // Native playback: mp4 or Safari HLS
  try {
    v.src = src
    // Иногда нужно дождаться загрузки метаданных, чтобы корректно поставить currentTime
    const onLoaded = () => {
      v.removeEventListener('loadedmetadata', onLoaded)
      applyStartAndAutoplay()
    }
    v.addEventListener('loadedmetadata', onLoaded)
  } catch (e) {
    error.value = 'Playback error.'
    emit('error', e)
  }
}

watch(
  () => [props.src, props.autoplay, props.muted, props.startTime],
  () => attach(),
  { immediate: false }
)

onMounted(() => attach())
onBeforeUnmount(() => destroyHls())

function onTimeUpdate(e) {
  emit('timeupdate', { currentTime: e.target.currentTime, duration: e.target.duration })
}
</script>

<style scoped>
/* только специфичное для компонента */
.video-player {
  width: 100%;
  background: #000;
  border-radius: var(--r-md);
  overflow: hidden;
  position: relative;
}

.video-player__el {
  width: 100%;
  height: auto;
  display: block;
  background: #000;
}

.video-player__error {
  position: absolute;
  left: 12px;
  bottom: 12px;
  background: rgba(255, 0, 0, 0.08);
  color: #ffdddd;
  padding: 6px 10px;
  border-radius: 999px;
  font-size: 13px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(6px);
}
</style>
