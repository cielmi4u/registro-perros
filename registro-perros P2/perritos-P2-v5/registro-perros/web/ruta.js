// =============================================================
// P2 · Funcionalidad 6: ruta de rescate
// La página sólo pide la ruta al servicio Elixir (GET /f/ruta) y la pinta.
// Todo el cálculo (zona, orden de visita, distancias) lo hace el núcleo.
// Ruta RELATIVA (/f/...): así funciona igual en localhost:8080 y en el túnel.
// =============================================================
(() => {
  const NS = 'http://www.w3.org/2000/svg';
  const ALAMEDA = { lat: 25.4232, lon: -101.0053 };

  const $ = (id) => document.getElementById(id);
  const inLat = $('rutaLat');
  const inLon = $('rutaLon');
  const mensaje = $('rutaMensaje');

  function ponerInicio(lat, lon) {
    inLat.value = Number(lat).toFixed(6);
    inLon.value = Number(lon).toFixed(6);
  }

  $('rutaAlameda').addEventListener('click', () => ponerInicio(ALAMEDA.lat, ALAMEDA.lon));

  $('rutaMiUbicacion').addEventListener('click', () => {
    if (!navigator.geolocation) {
      mensaje.textContent = 'Este navegador no da la ubicación; escríbela a mano.';
      return;
    }
    mensaje.textContent = 'Buscando tu ubicación...';
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        ponerInicio(pos.coords.latitude, pos.coords.longitude);
        mensaje.textContent = '';
      },
      () => { mensaje.textContent = 'No se pudo obtener la ubicación; escríbela a mano.'; },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  });

  $('rutaCalcular').addEventListener('click', async () => {
    if (inLat.value === '' || inLon.value === '') ponerInicio(ALAMEDA.lat, ALAMEDA.lon);

    const params = new URLSearchParams({
      lat: inLat.value,
      lon: inLon.value,
      radio: $('rutaRadio').value,
    });
    if ($('rutaMax').value) params.set('max', $('rutaMax').value);

    mensaje.textContent = 'Calculando ruta...';
    $('rutaResultado').classList.add('oculto');

    try {
      const resp = await fetch('/f/ruta?' + params.toString());
      const datos = await resp.json();
      if (!resp.ok) {
        mensaje.textContent = datos.error || 'No se pudo calcular la ruta.';
        return;
      }
      mostrar(datos);
    } catch (err) {
      mensaje.textContent = 'No se pudo conectar con el servicio de rutas.';
    }
  });

  function mostrar(plan) {
    if (plan.paradas.length === 0) {
      mensaje.textContent = 'No hay perritos con ubicación en esa zona. Prueba con un radio más grande.';
      return;
    }
    mensaje.textContent = '';
    $('rutaTotal').textContent =
      plan.total_perros + (plan.total_perros === 1 ? ' perrito' : ' perritos') +
      ' · recorrido total: ' + metros(plan.distancia_total);
    dibujar(plan);
    listar(plan.paradas);
    $('rutaResultado').classList.remove('oculto');
  }

  function metros(m) {
    return m >= 1000 ? (m / 1000).toFixed(2) + ' km' : m + ' m';
  }

  function listar(paradas) {
    const ol = $('rutaLista');
    ol.innerHTML = '';
    paradas.forEach((p) => {
      const li = document.createElement('li');

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
      texto.appendChild(document.createElement('br'));
      texto.appendChild(document.createTextNode(
        (p.perro.calle ? '📍 ' + p.perro.calle + ' · ' : '') +
        '+' + metros(p.tramo) + ' (llevas ' + metros(p.acumulada) + ')'
      ));

      li.append(num, img, texto);
      ol.appendChild(li);
    });
  }

  // Ajusta todos los puntos al cuadro del SVG (proyección simple; a escala
  // de una ciudad, multiplicar la longitud por cos(lat) basta).
  function dibujar(plan) {
    const svg = $('rutaSvg');
    svg.innerHTML = '';

    const puntos = [plan.inicio, ...plan.paradas.map((p) => ({ lat: p.perro.lat, lon: p.perro.lon }))];
    const k = Math.cos(plan.inicio.lat * Math.PI / 180);
    const xs = puntos.map((p) => p.lon * k);
    const ys = puntos.map((p) => p.lat);
    const [minX, maxX, minY, maxY] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
    const ancho = 400, alto = 300, margen = 24;
    const escala = Math.min(
      (ancho - 2 * margen) / Math.max(maxX - minX, 1e-6),
      (alto - 2 * margen) / Math.max(maxY - minY, 1e-6)
    );
    const offX = (ancho - (maxX - minX) * escala) / 2;
    const offY = (alto - (maxY - minY) * escala) / 2;
    const aPixel = (p) => ({
      x: offX + (p.lon * k - minX) * escala,
      y: offY + (maxY - p.lat) * escala,
    });

    const px = puntos.map(aPixel);

    const linea = document.createElementNS(NS, 'polyline');
    linea.setAttribute('points', px.map((p) => p.x + ',' + p.y).join(' '));
    linea.setAttribute('class', 'ruta-linea');
    svg.appendChild(linea);

    px.forEach((p, i) => {
      const c = document.createElementNS(NS, 'circle');
      c.setAttribute('cx', p.x);
      c.setAttribute('cy', p.y);
      c.setAttribute('r', i === 0 ? 10 : 9);
      c.setAttribute('class', i === 0 ? 'ruta-inicio' : 'ruta-parada');
      const titulo = document.createElementNS(NS, 'title');
      titulo.textContent = i === 0 ? 'Inicio' : i + '. ' + plan.paradas[i - 1].perro.nombre;
      c.appendChild(titulo);
      svg.appendChild(c);

      const t = document.createElementNS(NS, 'text');
      t.setAttribute('x', p.x);
      t.setAttribute('y', p.y + 4);
      t.setAttribute('text-anchor', 'middle');
      t.setAttribute('class', 'ruta-numero');
      t.textContent = i === 0 ? '★' : i;
      svg.appendChild(t);
    });
  }
})();
