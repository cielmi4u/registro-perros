const estadoUbicacion = document.getElementById('estadoUbicacion');
const inputLat = document.getElementById('latitud');
const inputLng = document.getElementById('longitud');

// Pide la ubicacion automaticamente al abrir la pagina y llena los campos
// visibles de latitud/longitud. Si falla o el usuario la borra, puede
// escribirla el mismo a mano (por ejemplo, copiándola de Google Maps) y el
// perrito se ubicará igual en el mapa con esos valores.
if (navigator.geolocation) {
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      inputLat.value = pos.coords.latitude;
      inputLng.value = pos.coords.longitude;
      estadoUbicacion.textContent = 'Ubicación obtenida automáticamente ✓ (puedes corregirla si quieres)';
    },
    () => {
      estadoUbicacion.textContent = 'No se pudo obtener la ubicación automática. Escríbela tú a mano si la tienes.';
    },
    { enableHighAccuracy: true, timeout: 10000 }
  );
} else {
  estadoUbicacion.textContent = 'Este navegador no soporta geolocalización automática. Escribe la ubicación a mano.';
}

// Previsualizacion de la foto elegida / tomada.
const inputFoto = document.getElementById('foto');
const previsualizacion = document.getElementById('previsualizacion');
inputFoto.addEventListener('change', () => {
  const archivo = inputFoto.files[0];
  if (!archivo) return;
  previsualizacion.src = URL.createObjectURL(archivo);
  previsualizacion.classList.remove('oculto');
});

// Envio del formulario.
const form = document.getElementById('formPerro');
const mensaje = document.getElementById('mensaje');

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  mensaje.textContent = 'Guardando...';

  const datos = new FormData(form);

  try {
    const resp = await fetch('/api/registrar', { method: 'POST', body: datos });
    const json = await resp.json();

    if (json.ok) {
      // A proposito no distinguimos si se guardo o si era un perro
      // duplicado: en ambos casos se muestra el mismo mensaje neutral
      // y se limpia el formulario, sin marcar nada especial.
      mensaje.textContent = 'Registro procesado.';
      form.reset();
      previsualizacion.classList.add('oculto');
      cargarPerros();
    } else {
      mensaje.textContent = json.mensaje || 'Ocurrio un problema, intenta de nuevo.';
    }
  } catch (err) {
    mensaje.textContent = 'No se pudo conectar con el servidor.';
  }
});

// ---------- Mapa y lista de perritos registrados ----------

const NS_SVG = 'http://www.w3.org/2000/svg';

async function cargarPerros() {
  try {
    const resp = await fetch('/api/perros');
    const perros = await resp.json();
    renderLista(perros);
    renderMapa(perros);
  } catch (err) {
    console.error('No se pudo cargar la lista de perritos', err);
  }
}

// Guarda los perros por id para poder ubicarlos cuando se toca su foto en la lista.
let perrosPorId = {};

function renderLista(perros) {
  const cont = document.getElementById('listaPerros');
  cont.innerHTML = '';
  if (perros.length === 0) {
    cont.innerHTML = '<p class="ayuda">Todavía no hay perritos registrados.</p>';
    return;
  }
  perros.forEach((p) => {
    const div = document.createElement('div');
    div.className = 'perro-card';
    const img = document.createElement('img');
    img.src = p.foto;
    img.alt = p.nombre;
    img.title = 'Ver en el mapa';
    img.addEventListener('click', () => irAlPin(p.id));
    const span = document.createElement('span');
    span.textContent = p.nombre;
    div.appendChild(img);
    div.appendChild(span);
    cont.appendChild(div);
  });
}

// Cuadro aproximado (lat/lng) que cubre la ciudad de Saltillo y sus
// alrededores, usado para ubicar los pines sobre la ilustración. Es una
// aproximación centrada en Saltillo (25.42°N, -101.00°O), no coordenadas
// oficiales de un mapa exacto.
const SALTILLO_LNG_MIN = -101.20;
const SALTILLO_LAT_MAX = 25.58;
const SALTILLO_ESCALA = 1000; // pixeles por grado

function coordsAPixeles(lat, lng) {
  return {
    x: (lng - SALTILLO_LNG_MIN) * SALTILLO_ESCALA,
    y: (SALTILLO_LAT_MAX - lat) * SALTILLO_ESCALA,
  };
}

function renderMapa(perros) {
  perrosPorId = {};
  perros.forEach((p) => { perrosPorId[p.id] = p; });

  const capaPines = document.getElementById('capaPines');
  capaPines.innerHTML = '';
  document.getElementById('infoPin').classList.add('oculto');

  const conUbicacion = perros.filter((p) => p.lat !== null && p.lng !== null);
  conUbicacion.forEach((p) => {
    const { x, y } = coordsAPixeles(p.lat, p.lng);
    const circulo = document.createElementNS(NS_SVG, 'circle');
    circulo.setAttribute('cx', x);
    circulo.setAttribute('cy', y);
    circulo.setAttribute('r', 9);
    circulo.setAttribute('class', 'pin');
    circulo.setAttribute('data-id', p.id);
    circulo.addEventListener('click', () => mostrarInfoPin(p));
    capaPines.appendChild(circulo);
  });
}

/** Se llama al tocar la foto de un perrito en la lista: lleva al mapa y resalta su pin. */
function irAlPin(id) {
  const p = perrosPorId[id];
  if (!p) return;

  document.getElementById('seccionMapa').scrollIntoView({ behavior: 'smooth', block: 'start' });

  document.querySelectorAll('.pin.resaltado').forEach((el) => el.classList.remove('resaltado'));
  const pin = document.querySelector('circle.pin[data-id="' + id + '"]');
  if (pin) pin.classList.add('resaltado');

  mostrarInfoPin(p, !pin);
}

function mostrarInfoPin(p, sinUbicacion) {
  const panel = document.getElementById('infoPin');
  const colores = [p.colorPrincipal, p.colorSecundario, p.colorTerciario].filter(Boolean).join(', ');
  const ubicacion = [p.calle, p.entreCalle1 ? 'entre ' + p.entreCalle1 : '', p.entreCalle2 ? 'y ' + p.entreCalle2 : '']
    .filter(Boolean).join(' ');

  panel.innerHTML = '';
  const img = document.createElement('img');
  img.src = p.foto;
  img.alt = p.nombre;
  const info = document.createElement('div');
  info.innerHTML =
    '<strong>' + escaparHtml(p.nombre) + '</strong><br>' +
    (p.raza ? escaparHtml(p.raza) + '<br>' : '') +
    'Color: ' + escaparHtml(colores) + '<br>' +
    '📍 ' + escaparHtml(ubicacion) + '<br>' +
    'Registrado: ' + escaparHtml(p.fecha) +
    (sinUbicacion ? '<br><em>Sin coordenadas GPS guardadas (no aparece con pin en el mapa)</em>' : '');
  panel.appendChild(img);
  panel.appendChild(info);
  panel.classList.remove('oculto');
}

function escaparHtml(texto) {
  const div = document.createElement('div');
  div.textContent = texto || '';
  return div.innerHTML;
}

cargarPerros();
