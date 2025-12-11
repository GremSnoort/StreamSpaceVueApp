<template>
  <div class="video-player-shell">
    <video
      ref="videoEl"
      :poster="poster"
      controls
      playsinline
      :muted="muted"
      @play="$emit('play')"
      @pause="$emit('pause')"
      @ended="$emit('ended')"
      @timeupdate="onTimeUpdate"
      class="video-element"
    >
      <!-- fallback source (mp4) -->
      <source v-if="isMp4" :src="src" />
      Your browser does not support the video tag.
    </video>

    <!-- optional error message -->
    <div v-if="error" class="player-error">{{ error }}</div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount } from 'vue'
import Hls from 'hls.js'

const props = defineProps({
  src: { type: String, required: true }, // m3u8 or mp4
  poster: { type: String, default: '' },
  autoplay: { type: Boolean, default: false },
  muted: { type: Boolean, default: true },
  startTime: { type: Number, default: 0 }
})

const emit = defineEmits(['ready','play','pause','ended','timeupdate','error'])

const videoEl = ref(null)
let hls = null
const error = ref(null)

const isMp4 = props.src && props.src.toLowerCase().endsWith('.mp4')

function attach() {
  error.value = null
  if (!props.src || !videoEl.value) return
  const isHls = props.src.toLowerCase().endsWith('.m3u8')

  // native HLS support (Safari) -> use native src
  const canPlayNative = videoEl.value.canPlayType('application/vnd.apple.mpegurl') !== ''

  if (isHls && !canPlayNative && Hls.isSupported()) {
    if (hls) {
      try { hls.destroy() } catch {}
      hls = null
    }
    hls = new Hls()
    hls.on(Hls.Events.ERROR, (event, data) => {
      // emit and set friendly message
      emit('error', { event, data })
      error.value = 'Playback error (HLS).'
    })
    hls.loadSource(props.src)
    hls.attachMedia(videoEl.value)
    hls.on(Hls.Events.MANIFEST_PARSED, () => {
      if (props.startTime) {
        try { videoEl.value.currentTime = props.startTime } catch {}
      }
      emit('ready')
      if (props.autoplay) {
        videoEl.value.muted = props.muted
        videoEl.value.play().catch(e => emit('error', e))
      }
    })
  } else {
    // fallback to native playback (mp4 or native HLS)
    try {
      videoEl.value.src = props.src
      if (props.startTime) {
        videoEl.value.currentTime = props.startTime
      }
      emit('ready')
      if (props.autoplay) {
        videoEl.value.muted = props.muted
        videoEl.value.play().catch(e => emit('error', e))
      }
    } catch (e) {
      error.value = 'Playback error.'
      emit('error', e)
    }
  }
}

watch(() => props.src, (n) => {
  if (hls) {
    try { hls.destroy() } catch {}
    hls = null
  }
  attach()
})

onMounted(() => attach())
onBeforeUnmount(() => {
  if (hls) {
    try { hls.destroy() } catch {}
    hls = null
  }
})

function onTimeUpdate(e){
  emit('timeupdate', { currentTime: e.target.currentTime, duration: e.target.duration })
}
</script>

<style scoped>
.video-player-shell {
  width: 100%;
  background: #000;
  border-radius: 12px;
  overflow: hidden;
  position: relative;
}

.video-element {
  width: 100%;
  height: auto;
  display: block;
  background: black;
}

.player-error {
  position: absolute;
  left: 12px;
  bottom: 12px;
  background: rgba(255,0,0,0.08);
  color: #ffdddd;
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 13px;
}
</style>
