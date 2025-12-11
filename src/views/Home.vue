<script setup>
</script>

<template>
  <div class="home-page">

    <!-- Top collage image section -->
    <section class="skin-section">
      <img
        src="https://wallpapers.com/your-cinema-collage-example.jpg"
        alt="Movie scenes collage"
        class="skin-image"
      />
      <div class="overlay">
        <h1 class="welcome-text">StreamSpace: Welcome to your Movies Vault</h1>
        <p class="subtitle">Your way to store & share videos</p>
      </div>
    </section>

    <!-- Content below -->
    <section class="content-section">
      <div class="card-container">
        <div class="card">
          <h3>Latest Releases</h3>
          <p>Discover trending content and updates</p>
        </div>
        <div class="card">
          <h3>Your own Movie Storage</h3>
          <p>Store your videos privately or shared</p>
        </div>
        <div class="card">
          <h3>Online or Transfer</h3>
          <p>Watch online or download</p>
        </div>
      </div>
    </section>

  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap');

.home-page {
  width: 100%;
  min-height: 100vh;
  background: #0a0a0a;
  font-family: 'Inter', sans-serif;
  color: #ffffff;
}

/* Top collage section */
.skin-section {
  position: relative;
  width: 100%;
  height: 380px;
  overflow: hidden;
  display: flex;
  justify-content: center;
  align-items: center;
}

.skin-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: brightness(0.55);
}

.overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
  padding: 1rem;
}

.welcome-text {
  font-size: 3rem;
  font-weight: 700;
  color: #44aaff;
  text-shadow: 0 0 10px #00bfff, 0 0 20px #009dff;
}

.subtitle {
  font-size: 1.25rem;
  color: #9fcff7;
  text-shadow: 0 0 6px #00bfff;
}

/* Content cards */
.content-section {
  width: 100%;
  padding: 2rem 1rem;
  display: flex;
  justify-content: center;
}

.card-container {
  display: flex;
  gap: 1.5rem;
  flex-wrap: wrap;
  justify-content: center;
  max-width: 1200px;
}

.card {
  background: #111;
  border: 1px solid #0c4d8a;
  border-radius: 12px;
  padding: 1.5rem;
  flex: 1 1 280px;
  min-width: 280px;
  box-shadow: 0 0 15px rgba(0, 140, 255, 0.3);
  transition: transform 0.3s, box-shadow 0.3s;
}

.card:hover {
  transform: translateY(-5px);
  box-shadow: 0 0 25px rgba(0, 180, 255, 0.5);
}

.card h3 {
  margin-bottom: 0.5rem;
  color: #00bfff;
}

.card p {
  color: #a0d4ff;
  font-size: 0.95rem;
}

/* Responsive */
@media (max-width: 768px) {
  .welcome-text {
    font-size: 2.2rem;
  }
  .subtitle {
    font-size: 1rem;
  }
  .card-container {
    gap: 1rem;
  }
}
</style>
