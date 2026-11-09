// =============================================================
// Perritos de la calle · página única con pestañas y mapas reales
// Mapas: Leaflet + OpenStreetMap (calles) y Esri (satélite), sin llave.
// Todas las peticiones usan rutas RELATIVAS (/api/..., /f/...), así
// funciona igual en localhost:8080 y en la URL del túnel.
// =============================================================

const SALTILLO = [25.4232, -101.0053];        // Alameda Zaragoza (Zona Centro)
const TECNOLOGICO = [25.4417474, -100.9928357]; // Instituto Tecnológico de Saltillo
const CENTRO_MAPA = [25.4318, -100.9966];      // entre el Tec y la Zona Centro

// ---------- Mapas (compartido con ruta.js) ----------
const Mapas = {
  disponible: typeof L !== 'undefined',

  crear(idElemento, zoom) {
    if (!this.disponible) {
      document.getElementById(idElemento).innerHTML =
        '<p class="ayuda">No se pudo cargar el mapa (revisa tu conexión a internet).</p>';
      return null;
    }
    const calles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap',
    });
    const satelite = L.tileLayer(
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      { maxZoom: 19, attribution: 'Imágenes &copy; Esri' }
    );
    const mapa = L.map(idElemento, { center: CENTRO_MAPA, zoom: zoom || 13, layers: [calles] });
    L.control.layers({ '🗺️ Calles': calles, '🛰️ Satélite': satelite }, null, { position: 'topright' }).addTo(mapa);
    return mapa;
  },

  // Pin con emoji (no depende de imágenes externas)
  icono(emoji, clase) {
    return L.divIcon({
      className: 'pin-mapa ' + (clase || ''),
      html: '<span><i>' + emoji + '</i></span>',
      iconSize: [34, 34],
      iconAnchor: [17, 34],
      popupAnchor: [0, -30],
    });
  },

  // Pide la ubicación del navegador (en el celular requiere https: la URL del túnel)
  ubicacion(alObtener, alFallar) {
    if (!navigator.geolocation) { alFallar('Este navegador no da la ubicación.'); return; }
    navigator.geolocation.getCurrentPosition(
      (pos) => alObtener(pos.coords.latitude, pos.coords.longitude),
      () => alFallar('No se pudo obtener la ubicación (en el celular abre la página con https).'),
      { enableHighAccuracy: true, timeout: 10000 }
    );
  },
};

// ---------- Pestañas: todo en la misma página ----------
const alMostrar = {}; // nombre de pestaña → función (p. ej. reajustar su mapa)

function mostrarPestana(nombre) {
  if (!document.getElementById('tab-' + nombre)) nombre = 'registrar';
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('activo', p.id === 'tab-' + nombre));
  document.querySelectorAll('.pestana').forEach((b) => b.classList.toggle('activa', b.dataset.tab === nombre));
  if (location.hash !== '#' + nombre) history.replaceState(null, '', '#' + nombre);
  window.scrollTo({ top: 0, behavior: 'smooth' });
  // Leaflet necesita recalcular su tamaño cuando su contenedor deja de estar oculto
  if (alMostrar[nombre]) setTimeout(alMostrar[nombre], 60);
}

document.querySelectorAll('.pestana').forEach((b) =>
  b.addEventListener('click', () => mostrarPestana(b.dataset.tab))
);
window.addEventListener('hashchange', () => mostrarPestana(location.hash.slice(1)));

// =============================================================
// REGISTRAR
// =============================================================
const estadoUbicacion = document.getElementById('estadoUbicacion');
const inputLat = document.getElementById('latitud');
const inputLng = document.getElementById('longitud');

const mapaRegistro = Mapas.crear('mapaRegistro', 15);
let pinRegistro = null;

function ponerUbicacionRegistro(lat, lng, centrar) {
  inputLat.value = Number(lat).toFixed(7);
  inputLng.value = Number(lng).toFixed(7);
  if (!mapaRegistro) return;
  if (!pinRegistro) {
    pinRegistro = L.marker([lat, lng], { draggable: true, icon: Mapas.icono('🐶', 'pin-nuevo') }).addTo(mapaRegistro);
    pinRegistro.on('dragend', () => {
      const p = pinRegistro.getLatLng();
      ponerUbicacionRegistro(p.lat, p.lng, false);
      estadoUbicacion.textContent = 'Ubicación elegida en el mapa ✓';
    });
  } else {
    pinRegistro.setLatLng([lat, lng]);
  }
  if (centrar) mapaRegistro.setView([lat, lng], 16);
}

if (mapaRegistro) {
  mapaRegistro.on('click', (e) => {
    ponerUbicacionRegistro(e.latlng.lat, e.latlng.lng, false);
    estadoUbicacion.textContent = 'Ubicación elegida en el mapa ✓';
  });
}

function pedirUbicacionRegistro() {
  estadoUbicacion.textContent = 'Obteniendo ubicación...';
  Mapas.ubicacion(
    (lat, lng) => {
      ponerUbicacionRegistro(lat, lng, true);
      estadoUbicacion.textContent = 'Ubicación obtenida automáticamente ✓ (puedes mover el pin)';
    },
    (msg) => { estadoUbicacion.textContent = msg + ' Toca el mapa para marcar el lugar.'; }
  );
}
document.getElementById('regMiUbicacion').addEventListener('click', pedirUbicacionRegistro);
pedirUbicacionRegistro();
alMostrar.registrar = () => mapaRegistro && mapaRegistro.invalidateSize();

// Previsualización de la foto
const inputFoto = document.getElementById('foto');
const previsualizacion = document.getElementById('previsualizacion');
const fotoTexto = document.getElementById('fotoTexto');
inputFoto.addEventListener('change', () => {
  const archivo = inputFoto.files[0];
  if (!archivo) return;
  previsualizacion.src = URL.createObjectURL(archivo);
  previsualizacion.classList.remove('oculto');
  fotoTexto.textContent = '📷 Toca para cambiar la foto';
});

// Envío del formulario
const form = document.getElementById('formPerro');
const mensaje = document.getElementById('mensaje');

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  mensaje.textContent = 'Guardando...';
  const datos = new FormData(form);

  try {
    const resp = await fetch('/api/registrar', { method: 'POST', body: datos });
    if (resp.status === 413) {
      mensaje.textContent = 'La foto es demasiado pesada (máximo 25 MB). Intenta con otra.';
      return;
    }
    if (resp.status === 502 || resp.status === 504) {
      mensaje.textContent = 'El servidor del P1 no está respondiendo. Intenta en un momento.';
      return;
    }
    const json = await resp.json();
    if (json.ok) {
      // A propósito no se distingue si se guardó o si era duplicado (igual que en el P1)
      mensaje.textContent = 'Registro procesado. ✓';
      const lat = inputLat.value, lng = inputLng.value; // se conserva el lugar
      form.reset();
      inputLat.value = lat; inputLng.value = lng;
      previsualizacion.classList.add('oculto');
      fotoTexto.textContent = '📷 Toca aquí para tomar o elegir la foto';
      cargarPerros();
      if (window.recargarEstadisticas) window.recargarEstadisticas();
    } else {
      mensaje.textContent = json.mensaje || 'Ocurrió un problema, intenta de nuevo.';
    }
  } catch (err) {
    mensaje.textContent = 'No se pudo conectar con el servidor.';
  }
});

// =============================================================
// LISTA DE PERRITOS REGISTRADOS
// =============================================================
async function cargarPerros() {
  try {
    const resp = await fetch('/api/perros');
    const perros = await resp.json();
    renderLista(perros);
    // ruta.js usa la lista para el número de perritos y los puntitos de su mapa
    document.dispatchEvent(new CustomEvent('perros-cargados', { detail: perros }));
  } catch (err) {
    document.getElementById('listaPerros').innerHTML =
      '<p class="ayuda">No se pudo cargar la lista de perritos.</p>';
  }
}

function renderLista(perros) {
  const cont = document.getElementById('listaPerros');
  document.getElementById('totalPerros').textContent = perros.length ? '(' + perros.length + ')' : '';
  cont.innerHTML = '';
  if (perros.length === 0) {
    cont.innerHTML = '<p class="ayuda">Todavía no hay perritos registrados.</p>';
    return;
  }
  perros.forEach((p) => {
    const tarjeta = document.createElement('div');
    tarjeta.className = 'perro-card';
    const img = document.createElement('img');
    img.src = p.foto;
    img.alt = p.nombre;
    img.loading = 'lazy';
    const nombre = document.createElement('span');
    nombre.textContent = p.nombre;
    const detalle = document.createElement('small');
    detalle.textContent = [p.colorPrincipal, p.calle].filter(Boolean).join(' · ');
    tarjeta.append(img, nombre, detalle);
    cont.appendChild(tarjeta);
  });
}

// ---------- Arranque ----------
cargarPerros();
mostrarPestana(location.hash.slice(1) || 'registrar');
