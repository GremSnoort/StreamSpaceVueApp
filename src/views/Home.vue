<script setup>
import PageLayout from '../components/PageLayout.vue'
import homeCover from '@/assets/images/homeCover.png'
</script>

<template>
  <div class="home">
    <!-- COVER -->
    <section class="cover">
      <img
        :src="homeCover"
        alt="Movie scenes collage"
        class="cover-img"
      />
      <div class="cover-overlay">
        <div class="cover-inner">
          <h1 class="cover-title">StreamSpace</h1>
          <p class="cover-subtitle">Welcome to your Movies Vault — store & share videos</p>
        </div>
      </div>
    </section>

    <!-- CONTENT -->
    <PageLayout>
      <section class="panel features">
        <header class="features-header">
          <h2 class="features-title">What you can do</h2>
          <p class="features-desc">A quick overview of the core features.</p>
        </header>

        <div class="grid features-grid">
          <div class="feature-card">
            <h3>Latest Releases</h3>
            <p>Discover trending content and updates</p>
          </div>

          <div class="feature-card">
            <h3>Your own Movie Storage</h3>
            <p>Store your videos privately or shared</p>
          </div>

          <div class="feature-card">
            <h3>Online or Transfer</h3>
            <p>Watch online or download</p>
          </div>
        </div>
      </section>
    </PageLayout>
  </div>
</template>

<style scoped>
/* wrapper */
.home {
  width: 100%;
}

/* cover */
.cover {
  position: relative;
  width: 100%;
  height: 380px;
  overflow: hidden;
  border-bottom: 1px solid var(--border);
}

.cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: brightness(0.55);
  transform: scale(1.02);
}

.cover-overlay {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 16px;

  background:
    radial-gradient(circle at 50% 40%, var(--accent-1), transparent 55%),
    radial-gradient(circle at 70% 70%, var(--accent-2), transparent 60%);
}

.cover-inner {
  text-align: center;
  max-width: 980px;
}

.cover-title {
  margin: 0 0 10px;
  font-size: 52px;
  font-weight: 800;
  letter-spacing: 0.3px;

  background: linear-gradient(to right, var(--title-grad-1), var(--title-grad-2));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;

  text-shadow: 0 0 18px var(--shadow-color);
}

.cover-subtitle {
  margin: 0;
  font-size: 18px;
  color: var(--ui-fg-1);
  text-shadow: 0 0 10px rgba(0,0,0,0.35);
}

/* features section */
.features {
  padding: 28px;
  margin-top: 28px;
}

.features-header {
  margin-bottom: 18px;
}

.features-title {
  margin: 0 0 6px;
  font-size: 22px;
  font-weight: 800;
  color: var(--text);
}

.features-desc {
  margin: 0;
  color: var(--ui-fg-1);
  font-size: 14px;
  opacity: 0.9;
}

.features-grid {
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 18px;
}

.feature-card {
  background: linear-gradient(145deg, var(--glass-1), var(--glass-2));
  border: 1px solid var(--glass-border);
  border-radius: var(--r-md);
  padding: 18px;

  box-shadow: var(--shadow-md);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);

  transition: transform 0.25s, box-shadow 0.25s, border-color 0.25s;
}

.feature-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-lg);
  border-color: var(--ui-border-med);
}

.feature-card h3 {
  margin: 0 0 8px;
  font-size: 16px;
  color: var(--primary);
}

.feature-card p {
  margin: 0;
  color: var(--ui-fg-1);
  font-size: 14px;
}

@media (max-width: 768px) {
  .cover {
    height: 320px;
  }

  .cover-title {
    font-size: 38px;
  }

  .cover-subtitle {
    font-size: 15px;
  }

  .features {
    padding: 20px;
    margin-top: 20px;
  }
}
</style>
