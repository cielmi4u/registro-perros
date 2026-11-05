// =============================================================
// P2 · Funcionalidad 3: estadísticas
// La página sólo pide los conteos al servicio Elixir (GET /f/estadisticas)
// y los pinta. Contar, agrupar y ordenar lo hace el núcleo.
// Ruta RELATIVA (/f/...): funciona igual en localhost:8080 y en el túnel.
// =============================================================
(() => {
  const NS = 'http://www.w3.org/2000/svg';
  const $ = (id) => document.getElementById(id);

  // Colores del catálogo del P1 → color de la barra (sólo presentación)
  const PINTURA = {
    'negro': '#1f2937', 'blanco': '#f9fafb', 'café': '#7c4a1e', 'cafe': '#7c4a1e',
    'dorado': '#d4a017', 'gris': '#9ca3af', 'atigrado': '#8b5a2b', 'canela': '#c68642',
    'crema': '#f3e5ab', 'tricolor': '#b45309',
    'manchado (blanco y negro)': 'repeating-linear-gradient(90deg,#1f2937 0 10px,#f9fafb 10px 20px)',
  };

  const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  // las fechas llegan como "2026-11-05"; se arman a mano para no moverlas de zona horaria
  const fechaCorta = (iso) => {
    const [, m, d] = iso.split('-').map(Number);
    return d + ' ' + MESES[m - 1];
  };

  async function cargar() {
    const params = new URLSearchParams({ dias: $('estDias').value, n: $('estN').value });
    $('estMensaje').textContent = 'Cargando estadísticas...';

    try {
      const resp = await fetch('/f/estadisticas?' + params.toString());
      const datos = await resp.json();
      if (!resp.ok) {
        $('estMensaje').textContent = datos.error || 'No se pudieron cargar las estadísticas.';
        $('estResultado').classList.add('oculto');
        return;
      }
      mostrar(datos);
    } catch (err) {
      $('estMensaje').textContent = 'No se pudo conectar con el servicio de estadísticas.';
      $('estResultado').classList.add('oculto');
    }
  }

  function mostrar(r) {
    $('estMensaje').textContent = r.total === 0 ? 'No hay avistamientos en este periodo.' : '';
    $('estTotal').textContent =
      r.total + (r.total === 1 ? ' avistamiento' : ' avistamientos') +
      ' del ' + fechaCorta(r.desde) + ' al ' + fechaCorta(r.hasta);

    barras($('estColores'), r.por_color, true);
    barras($('estRazas'), r.por_raza, false);
    columnas($('estDiasSvg'), r.por_dia);
    $('estResultado').classList.remove('oculto');
  }

  function barras(contenedor, lista, pintarColor) {
    contenedor.innerHTML = '';
    if (lista.length === 0) {
      contenedor.innerHTML = '<p class="ayuda">Sin datos.</p>';
      return;
    }
    const maximo = Math.max(...lista.map((x) => x.total));

    lista.forEach((x) => {
      const fila = document.createElement('div');
      fila.className = 'barra';

      const etiqueta = document.createElement('span');
      etiqueta.className = 'barra-etiqueta';
      etiqueta.textContent = x.etiqueta;
      etiqueta.title = x.etiqueta;

      const fondo = document.createElement('div');
      fondo.className = 'barra-fondo';
      const relleno = document.createElement('div');
      relleno.className = 'barra-relleno';
      relleno.style.width = (100 * x.total / maximo) + '%';
      const pintura = pintarColor && PINTURA[x.etiqueta.toLowerCase()];
      if (pintura) relleno.style.background = pintura;
      fondo.appendChild(relleno);

      const total = document.createElement('span');
      total.className = 'barra-total';
      total.textContent = x.total;

      fila.append(etiqueta, fondo, total);
      contenedor.appendChild(fila);
    });
  }

  function crear(tipo, atributos, texto) {
    const el = document.createElementNS(NS, tipo);
    Object.entries(atributos).forEach(([k, v]) => el.setAttribute(k, v));
    if (texto !== undefined) el.textContent = texto;
    return el;
  }

  // Gráfica de columnas en SVG, sin bibliotecas.
  function columnas(svg, serie) {
    svg.innerHTML = '';
    const ancho = 400, alto = 190;
    const izq = 28, der = 8, arriba = 12, abajo = 26;
    const areaAncho = ancho - izq - der;
    const areaAlto = alto - arriba - abajo;
    const maximo = Math.max(1, ...serie.map((d) => d.total));
    const paso = areaAncho / serie.length;
    const grosor = Math.max(1, paso * 0.7);

    // eje y: 0 y máximo
    svg.appendChild(crear('line', { x1: izq, y1: arriba + areaAlto, x2: ancho - der, y2: arriba + areaAlto, class: 'eje' }));
    svg.appendChild(crear('text', { x: izq - 4, y: arriba + areaAlto, 'text-anchor': 'end', class: 'eje-texto' }, '0'));
    svg.appendChild(crear('text', { x: izq - 4, y: arriba + 8, 'text-anchor': 'end', class: 'eje-texto' }, maximo));

    // etiqueta del eje x más o menos cada semana
    const cadaCuantos = Math.max(1, Math.ceil(serie.length / 6));

    serie.forEach((d, i) => {
      const h = d.total === 0 ? 2 : (d.total / maximo) * areaAlto;
      const x = izq + i * paso + (paso - grosor) / 2;
      const col = crear('rect', {
        x, y: arriba + areaAlto - h, width: grosor, height: h, rx: Math.min(3, grosor / 2),
        class: d.total === 0 ? 'columna-cero' : 'columna',
      });
      col.appendChild(crear('title', {}, fechaCorta(d.fecha) + ': ' + d.total));
      svg.appendChild(col);

      if (i % cadaCuantos === 0 || i === serie.length - 1) {
        svg.appendChild(crear('text', {
          x: izq + i * paso + paso / 2, y: alto - 8, 'text-anchor': 'middle', class: 'eje-texto',
        }, fechaCorta(d.fecha)));
      }
    });
  }

  $('estDias').addEventListener('change', cargar);
  $('estN').addEventListener('change', cargar);

  // al registrar un perro nuevo, el P1 recarga la lista; aquí basta con
  // cargar al abrir la página y cada vez que cambian los filtros
  cargar();
})();
