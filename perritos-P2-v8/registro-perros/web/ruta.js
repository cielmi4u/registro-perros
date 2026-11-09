// =============================================================
// P2 · Funcionalidad 6: ruta de rescate sobre un mapa real
// - El ORDEN de visita lo calcula el núcleo Elixir (GET /f/ruta, vecino más cercano).
// - El CAMINO por las calles lo traza OSRM (routing.openstreetmap.de, a pie),
//   así la línea sigue las calles y no pasa por encima de las casas.
// Usa Mapas (definido en app.js): Leaflet + OpenStreetMap.
// =============================================================
(() => {
  const $ = (id) => document.getElementById(id);
  const inLat = $('rutaLat');
  const inLon = $('rutaLon');
  const mensaje = $('rutaMensaje');
  const selectMax = $('rutaMax');

  // Radio grande: la zona es toda la ciudad, solo importa cuántos perritos
  const RADIO_CIUDAD = 100000;
  const OSRM = 'https://routing.openstreetmap.de/routed-foot/route/v1/driving/';

  const mapa = Mapas.crear('mapaRuta', 14);
  const capaRuta = mapa ? L.layerGroup().addTo(mapa) : null;
  const capaReferencia = mapa ? L.layerGroup().addTo(mapa) : null;
  let pinInicio = null;
  let marcadoresParadas = [];
  let boundsPendientes = null;

  // ---------- número de perritos: depende de cuántos hay registrados ----------
  document.addEventListener('perros-cargados', (e) => {
    const perros = e.detail;
    const conUbicacion = perros.filter((p) => p.lat !== null && p.lng !== null);
    llenarSelect(conUbicacion.length);
    $('rutaHay').textContent = 'Hay ' + conUbicacion.length +
      (conUbicacion.length === 1 ? ' perrito registrado' : ' perritos registrados') + ' con ubicación.';

    // puntitos de referencia: dónde hay perritos (ayuda a elegir el inicio)
    if (!capaReferencia) return;
    capaReferencia.clearLayers();
    conUbicacion.forEach((p) =>
      L.circleMarker([p.lat, p.lng], { radius: 4, className: 'punto-referencia', interactive: false }).addTo(capaReferencia)
    );
  });

  function llenarSelect(total) {
    const anterior = Number(selectMax.value) || 5;
    selectMax.innerHTML = '';
    if (total === 0) {
      const op = document.createElement('option');
      op.value = '';
      op.textContent = 'No hay perritos registrados';
      selectMax.appendChild(op);
      selectMax.disabled = true;
      return;
    }
    selectMax.disabled = false;
    for (let n = 1; n <= total; n++) {
      const op = document.createElement('option');
      op.value = n;
      op.textContent = n + (n === 1 ? ' perrito' : ' perritos') + (n === total ? ' (todos)' : '');
      selectMax.appendChild(op);
    }
    selectMax.value = String(Math.min(anterior, total));
  }

  // ---------- punto de partida ----------
  function ponerInicio(lat, lon, centrar) {
    inLat.value = Number(lat).toFixed(6);
    inLon.value = Number(lon).toFixed(6);
    $('rutaInicioTexto').textContent = '★ Inicio elegido (puedes arrastrarlo)';
    if (!mapa) return;

    if (!pinInicio) {
      pinInicio = L.marker([lat, lon], { draggable: true, icon: Mapas.icono('★', 'pin-inicio'), zIndexOffset: 1000 })
        .addTo(mapa)
        .bindTooltip('Inicio');
      pinInicio.on('dragend', () => {
        const p = pinInicio.getLatLng();
        ponerInicio(p.lat, p.lng, false);
      });
    } else {
      pinInicio.setLatLng([lat, lon]);
    }
    if (centrar) mapa.setView([lat, lon], 15);
    limpiarRuta();
  }

  function limpiarRuta() {
    if (capaRuta) capaRuta.clearLayers();
    marcadoresParadas = [];
    $('rutaResultado').classList.add('oculto');
  }

  if (mapa) mapa.on('click', (e) => ponerInicio(e.latlng.lat, e.latlng.lng, false));
  selectMax.addEventListener('change', limpiarRuta);

  $('rutaAlameda').addEventListener('click', () => ponerInicio(SALTILLO[0], SALTILLO[1], true));
  $('rutaTec').addEventListener('click', () => ponerInicio(TECNOLOGICO[0], TECNOLOGICO[1], true));

  $('rutaMiUbicacion').addEventListener('click', () => {
    mensaje.textContent = 'Buscando tu ubicación...';
    Mapas.ubicacion(
      (lat, lon) => { ponerInicio(lat, lon, true); mensaje.textContent = ''; },
      (msg) => { mensaje.textContent = msg + ' Toca el mapa para elegir el inicio.'; }
    );
  });

  alMostrar.ruta = () => {
    if (!mapa) return;
    mapa.invalidateSize();
    if (boundsPendientes) { mapa.fitBounds(boundsPendientes, { padding: [30, 30] }); boundsPendientes = null; }
  };

  // ---------- calcular ----------
  $('rutaCalcular').addEventListener('click', async () => {
    if (!selectMax.value) { mensaje.textContent = 'Todavía no hay perritos registrados.'; return; }
    if (inLat.value === '' || inLon.value === '') ponerInicio(TECNOLOGICO[0], TECNOLOGICO[1], true);

    const params = new URLSearchParams({
      lat: inLat.value, lon: inLon.value, radio: RADIO_CIUDAD, max: selectMax.value,
    });

    mensaje.textContent = 'Calculando ruta...';
    limpiarRuta();

    try {
      const resp = await fetch('/f/ruta?' + params.toString());
      const datos = await resp.json();
      if (!resp.ok) {
        mensaje.textContent = datos.error || 'No se pudo calcular la ruta.';
        return;
      }
      await mostrar(datos);
    } catch (err) {
      mensaje.textContent = 'No se pudo conectar con el servicio de rutas.';
    }
  });

  async function mostrar(plan) {
    if (plan.paradas.length === 0) {
      mensaje.textContent = 'No hay perritos con ubicación registrados.';
      return;
    }
    $('rutaTotal').textContent =
      'Ruta para visitar ' + plan.total_perros + (plan.total_perros === 1 ? ' perrito' : ' perritos');
    listar(plan.paradas);
    $('rutaGoogle').href = enlaceGoogleMaps(plan);
    $('rutaResultado').classList.remove('oculto');
    await dibujar(plan);
  }

  async function dibujar(plan) {
    if (!mapa) return;
    const puntos = [[plan.inicio.lat, plan.inicio.lon], ...plan.paradas.map((p) => [p.perro.lat, p.perro.lon])];

    // paradas numeradas
    plan.paradas.forEach((p, i) => {
      const m = L.marker([p.perro.lat, p.perro.lon], {
        icon: L.divIcon({ className: 'pin-numero', html: '<span>' + p.orden + '</span>', iconSize: [30, 30], iconAnchor: [15, 15] }),
        title: p.orden + '. ' + p.perro.nombre,
        zIndexOffset: 500,
      }).bindPopup(popupParada(p), { maxWidth: 240 });
      m.addTo(capaRuta);
      marcadoresParadas[i] = m;
    });

    // camino por las calles
    mensaje.textContent = 'Trazando el camino por las calles...';
    const camino = await caminoPorCalles(puntos);
    if (camino) {
      L.polyline(camino, { className: 'linea-calles' }).addTo(capaRuta);
      mensaje.textContent = '';
    } else {
      L.polyline(puntos, { className: 'linea-ruta' }).addTo(capaRuta);
      mensaje.textContent = 'No se pudo trazar el camino por las calles (sin conexión al servicio de rutas); se muestra el orden con líneas rectas.';
    }

    const bounds = L.latLngBounds(camino || puntos);
    if ($('mapaRuta').offsetParent !== null) mapa.fitBounds(bounds, { padding: [30, 30] });
    else boundsPendientes = bounds;
  }

  // Pide a OSRM el camino a pie que pasa por todos los puntos en ese orden.
  // Regresa una lista de [lat, lon] o null si no se pudo.
  async function caminoPorCalles(puntos) {
    // Para muchos perritos se pide por tramos de 25 puntos (el último de un
    // tramo es el primero del siguiente) y se juntan.
    const TAM = 25;
    let camino = [];
    for (let i = 0; i < puntos.length - 1; i += TAM - 1) {
      const tramo = await pedirTramo(puntos.slice(i, i + TAM));
      if (!tramo) return null;
      camino = camino.concat(camino.length ? tramo.slice(1) : tramo);
    }
    return camino;
  }

  async function pedirTramo(puntos) {
    const coords = puntos.map(([lat, lon]) => lon + ',' + lat).join(';');
    try {
      const control = new AbortController();
      const espera = setTimeout(() => control.abort(), 12000);
      const resp = await fetch(OSRM + coords + '?overview=full&geometries=geojson', { signal: control.signal });
      clearTimeout(espera);
      if (!resp.ok) return null;
      const datos = await resp.json();
      if (datos.code !== 'Ok' || !datos.routes || !datos.routes.length) return null;
      return datos.routes[0].geometry.coordinates.map(([lon, lat]) => [lat, lon]);
    } catch (err) {
      return null;
    }
  }

  function popupParada(p) {
    const caja = document.createElement('div');
    caja.className = 'popup-perro';
    const img = document.createElement('img');
    img.src = p.perro.foto;
    img.alt = p.perro.nombre;
    const texto = document.createElement('div');
    const titulo = document.createElement('strong');
    titulo.textContent = p.orden + '. ' + p.perro.nombre;
    texto.appendChild(titulo);
    if (p.perro.calle) {
      texto.appendChild(document.createElement('br'));
      texto.appendChild(document.createTextNode('📍 ' + p.perro.calle));
    }
    caja.append(img, texto);
    return caja;
  }

  function listar(paradas) {
    const ol = $('rutaLista');
    ol.innerHTML = '';
    paradas.forEach((p, i) => {
      const li = document.createElement('li');
      li.title = 'Ver en el mapa';

      const num = document.createElement('span');
      num.className = 'num';
      num.textContent = p.orden;

      const img = document.createElement('img');
      img.src = p.perro.foto;
      img.alt = p.perro.nombre;

      const texto = document.createElement('div');
      const nombre = document.createElement('strong');
      nombre.textContent = p.perro.nombre;
      texto.appendChild(nombre);
      if (p.perro.calle) {
        texto.appendChild(document.createElement('br'));
        texto.appendChild(document.createTextNode('📍 ' + p.perro.calle));
      }

      li.append(num, img, texto);
      li.addEventListener('click', () => {
        const m = marcadoresParadas[i];
        if (!m) return;
        $('mapaRuta').scrollIntoView({ behavior: 'smooth', block: 'center' });
        mapa.flyTo(m.getLatLng(), 17, { duration: 0.7 });
        setTimeout(() => m.openPopup(), 750);
      });
      ol.appendChild(li);
    });
  }

  // Google Maps acepta hasta 9 paradas intermedias en un enlace de direcciones,
  // así que el enlace lleva los primeros 10 perritos de la ruta
  function enlaceGoogleMaps(plan) {
    const punto = (lat, lon) => lat + ',' + lon;
    const paradas = plan.paradas.slice(0, 10).map((p) => punto(p.perro.lat, p.perro.lon));
    const params = new URLSearchParams({
      api: '1',
      origin: punto(plan.inicio.lat, plan.inicio.lon),
      destination: paradas[paradas.length - 1],
      travelmode: 'walking',
    });
    const intermedias = paradas.slice(0, -1);
    if (intermedias.length) params.set('waypoints', intermedias.join('|'));
    return 'https://www.google.com/maps/dir/?' + params.toString();
  }
})();
