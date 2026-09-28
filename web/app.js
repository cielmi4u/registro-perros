// ============ PARTE 1: BUSCAR LOS ELEMENTOS DE LA PÁGINA ============

const estadoUbicacion = document.getElementById('estadoUbicacion'); // Busca en el HTML el mensaje del GPS (por su id) y lo guarda en una variable; "const" = variable que no cambia
const inputLat = document.getElementById('latitud'); // Guarda la cajita de latitud
const inputLng = document.getElementById('longitud'); // Guarda la cajita de longitud

// ============ PARTE 2: PEDIR LA UBICACIÓN (GPS) ============

if (navigator.geolocation) { // Pregunta: ¿este navegador sabe pedir la ubicación?
  navigator.geolocation.getCurrentPosition( // Le pide la ubicación al dispositivo (el usuario debe dar permiso)
    (pos) => { // Función que se ejecuta SI la ubicación se obtuvo bien; "pos" trae los datos
      inputLat.value = pos.coords.latitude; // Escribe la latitud en la cajita
      inputLng.value = pos.coords.longitude; // Escribe la longitud en la cajita
      estadoUbicacion.textContent = 'Ubicación obtenida automáticamente ✓ (puedes corregirla si quieres)'; // Cambia el mensaje a "éxito"
    },
    () => { // Función que se ejecuta SI hubo un error (permiso negado, GPS apagado...)
      estadoUbicacion.textContent = 'No se pudo obtener la ubicación automática. Escríbela tú a mano si la tienes.'; // Avisa que la escriba a mano
    },
    { enableHighAccuracy: true, timeout: 10000 } // Opciones: usar la mayor precisión posible y esperar máximo 10 segundos
  );
} else { // Si el navegador NO sabe pedir ubicación
  estadoUbicacion.textContent = 'Este navegador no soporta geolocalización automática. Escribe la ubicación a mano.'; // Avisa que la escriba a mano
}

// ============ PARTE 3: MOSTRAR LA FOTO ELEGIDA ============

const inputFoto = document.getElementById('foto'); // Guarda el campo donde se elige la foto
const previsualizacion = document.getElementById('previsualizacion'); // Guarda la imagen donde se mostrará
inputFoto.addEventListener('change', () => { // "Escucha" el momento en que el usuario elige una foto (evento "change") y ejecuta lo de adentro
  const archivo = inputFoto.files[0]; // Toma el primer archivo elegido
  if (!archivo) return; // Si no hay archivo, no hace nada y termina
  previsualizacion.src = URL.createObjectURL(archivo); // Crea una dirección temporal para la foto y se la pone a la imagen para que se vea
  previsualizacion.classList.remove('oculto'); // Quita la clase "oculto" para que la imagen aparezca
});

// ============ PARTE 4: ENVIAR EL FORMULARIO ============

const form = document.getElementById('formPerro'); // Guarda el formulario completo
const mensaje = document.getElementById('mensaje'); // Guarda el espacio de mensajes bajo el botón

form.addEventListener('submit', async (e) => { // Cuando se envía el formulario (clic en Registrar). "async" permite esperar respuestas del servidor
  e.preventDefault(); // Evita que la página se recargue (que es lo que haría normalmente)
  mensaje.textContent = 'Guardando...'; // Muestra el mensaje de espera

  const datos = new FormData(form); // Junta todos los campos del formulario (texto y foto) en un paquete listo para enviar

  try { // "try" = intenta hacer esto; si algo falla, salta al "catch" de abajo
    const resp = await fetch('/api/registrar', { method: 'POST', body: datos }); // Envía el paquete al servidor Java y ESPERA su respuesta ("await")
    const json = await resp.json(); // Convierte la respuesta del servidor en un objeto que JavaScript entiende

    if (json.ok) { // Si el servidor dijo que todo salió bien
      // A proposito no distinguimos si se guardo o si era un perro
      // duplicado: en ambos casos se muestra el mismo mensaje neutral
      // y se limpia el formulario, sin marcar nada especial.
      mensaje.textContent = 'Registro procesado.'; // Mensaje neutral (igual si se guardó o si era duplicado)
      form.reset(); // Vacía todos los campos del formulario
      previsualizacion.classList.add('oculto'); // Vuelve a esconder la foto de vista previa
      cargarPerros(); // Vuelve a pedir la lista de perritos para actualizar mapa y tarjetas
    } else { // Si el servidor dijo que hubo un problema (por ejemplo faltan datos)
      mensaje.textContent = json.mensaje || 'Ocurrio un problema, intenta de nuevo.'; // Muestra el mensaje del servidor, o uno genérico si no mandó ninguno
    }
  } catch (err) { // Si no se pudo ni comunicar con el servidor
    mensaje.textContent = 'No se pudo conectar con el servidor.'; // Avisa el problema de conexión
  }
});

// ============ PARTE 5: CARGAR LA LISTA Y EL MAPA ============

const NS_SVG = 'http://www.w3.org/2000/svg'; // Dirección "oficial" del lenguaje SVG; se necesita para crear círculos dentro del mapa

async function cargarPerros() { // Función que pide al servidor todos los perritos guardados
  try { // Intenta...
    const resp = await fetch('/api/perros'); // Pide la lista al servidor y espera
    const perros = await resp.json(); // Convierte la respuesta en una lista de perritos
    renderLista(perros); // Dibuja las tarjetitas con foto y nombre
    renderMapa(perros); // Dibuja los pines en el mapa
  } catch (err) { // Si algo falla...
    console.error('No se pudo cargar la lista de perritos', err); // Escribe el error en la consola del navegador (para el programador)
  }
}

let perrosPorId = {}; // Diccionario vacío ("let" = variable que sí cambia). Guardará cada perrito buscándolo por su id

function renderLista(perros) { // Función que dibuja la lista de tarjetitas
  const cont = document.getElementById('listaPerros'); // Busca el espacio donde irán las tarjetitas
  cont.innerHTML = ''; // Lo vacía para no duplicar tarjetas al actualizar
  if (perros.length === 0) { // Si la lista está vacía (no hay perritos)
    cont.innerHTML = '<p class="ayuda">Todavía no hay perritos registrados.</p>'; // Muestra un mensaje
    return; // Termina la función aquí
  }
  perros.forEach((p) => { // Repite lo de adentro por CADA perrito "p" de la lista
    const div = document.createElement('div'); // Crea una caja nueva (div) para este perrito
    div.className = 'perro-card'; // Le pone la clase de diseño de tarjetita
    const img = document.createElement('img'); // Crea una imagen nueva
    img.src = p.foto; // Le asigna la dirección de la foto del perrito
    img.alt = p.nombre; // Texto alternativo (para lectores de pantalla o si la foto falla)
    img.title = 'Ver en el mapa'; // Texto que aparece al dejar el mouse encima
    img.addEventListener('click', () => irAlPin(p.id)); // Al hacer clic en la foto, llama a irAlPin con el id de este perrito
    const span = document.createElement('span'); // Crea un espacio de texto
    span.textContent = p.nombre; // Le escribe el nombre del perrito
    div.appendChild(img); // Mete la imagen dentro de la caja
    div.appendChild(span); // Mete el nombre dentro de la caja
    cont.appendChild(div); // Mete la caja completa dentro de la lista de la página
  });
}

// Constantes que describen qué zona del mundo cubre el dibujo del mapa
const SALTILLO_LNG_MIN = -101.20; // Longitud del borde izquierdo del mapa
const SALTILLO_LAT_MAX = 25.58; // Latitud del borde superior del mapa
const SALTILLO_ESCALA = 1000; // Cuántos puntos del dibujo equivalen a 1 grado

function coordsAPixeles(lat, lng) { // Convierte una ubicación real (lat, lng) en una posición (x, y) dentro del dibujo
  return { // Devuelve las dos posiciones juntas
    x: (lng - SALTILLO_LNG_MIN) * SALTILLO_ESCALA, // Qué tan a la derecha del borde izquierdo está
    y: (SALTILLO_LAT_MAX - lat) * SALTILLO_ESCALA, // Qué tan abajo del borde superior está (la resta va al revés porque en pantalla "y" crece hacia abajo)
  };
}

function renderMapa(perros) { // Función que dibuja los pines
  perrosPorId = {}; // Vacía el diccionario
  perros.forEach((p) => { perrosPorId[p.id] = p; }); // Guarda cada perrito en el diccionario usando su id como llave

  const capaPines = document.getElementById('capaPines'); // Busca el grupo vacío del mapa donde van los pines
  capaPines.innerHTML = ''; // Lo vacía para no duplicar pines
  document.getElementById('infoPin').classList.add('oculto'); // Esconde el cuadro de información al actualizar

  const conUbicacion = perros.filter((p) => p.lat !== null && p.lng !== null); // Se queda SOLO con los perritos que tienen coordenadas guardadas
  conUbicacion.forEach((p) => { // Por cada perrito con ubicación...
    const { x, y } = coordsAPixeles(p.lat, p.lng); // Calcula su posición dentro del dibujo
    const circulo = document.createElementNS(NS_SVG, 'circle'); // Crea un círculo SVG (el pin)
    circulo.setAttribute('cx', x); // Posición horizontal del centro
    circulo.setAttribute('cy', y); // Posición vertical del centro
    circulo.setAttribute('r', 9); // Radio del círculo
    circulo.setAttribute('class', 'pin'); // Le pone la clase de diseño "pin"
    circulo.setAttribute('data-id', p.id); // Guarda el id del perrito en el círculo, para encontrarlo después
    circulo.addEventListener('click', () => mostrarInfoPin(p)); // Al tocar el pin, muestra la información del perrito
    capaPines.appendChild(circulo); // Agrega el pin al mapa
  });
}

// ============ PARTE 6: CLIC EN UNA FOTO DE LA LISTA ============

/** Se llama al tocar la foto de un perrito en la lista: lleva al mapa y resalta su pin. */
function irAlPin(id) { // Recibe el id del perrito tocado
  const p = perrosPorId[id]; // Busca al perrito en el diccionario
  if (!p) return; // Si no lo encuentra, termina

  document.getElementById('seccionMapa').scrollIntoView({ behavior: 'smooth', block: 'start' }); // Desplaza la página suavemente hasta la tarjeta del mapa

  document.querySelectorAll('.pin.resaltado').forEach((el) => el.classList.remove('resaltado')); // Quita el resaltado a cualquier pin que lo tuviera antes
  const pin = document.querySelector('circle.pin[data-id="' + id + '"]'); // Busca el círculo que tiene el id de este perrito
  if (pin) pin.classList.add('resaltado'); // Si existe, lo resalta (más grande y amarillo)

  mostrarInfoPin(p, !pin); // Muestra la información; el segundo dato avisa si NO hay pin (perrito sin coordenadas)
}

// ============ PARTE 7: MOSTRAR LA INFORMACIÓN DE UN PERRITO ============

function mostrarInfoPin(p, sinUbicacion) { // Llena el cuadro de información con los datos del perrito "p"
  const panel = document.getElementById('infoPin'); // Busca el cuadro de información
  const colores = [p.colorPrincipal, p.colorSecundario, p.colorTerciario].filter(Boolean).join(', '); // Junta los colores en un texto; filter(Boolean) descarta los vacíos y join los separa con comas
  const ubicacion = [p.calle, p.entreCalle1 ? 'entre ' + p.entreCalle1 : '', p.entreCalle2 ? 'y ' + p.entreCalle2 : ''] // Arma la dirección: calle, "entre ..." y "y ..." solo si existen
    .filter(Boolean).join(' '); // Descarta los vacíos y une todo con espacios

  panel.innerHTML = ''; // Vacía el cuadro
  const img = document.createElement('img'); // Crea la foto
  img.src = p.foto; // Dirección de la foto
  img.alt = p.nombre; // Texto alternativo
  const info = document.createElement('div'); // Crea la caja de texto
  info.innerHTML = // Escribe el contenido con etiquetas HTML
    '<strong>' + escaparHtml(p.nombre) + '</strong><br>' + // Nombre en negritas y salto de línea
    (p.raza ? escaparHtml(p.raza) + '<br>' : '') + // Raza (solo si tiene)
    'Color: ' + escaparHtml(colores) + '<br>' + // Colores
    '📍 ' + escaparHtml(ubicacion) + '<br>' + // Dirección
    'Registrado: ' + escaparHtml(p.fecha) + // Fecha de registro
    (sinUbicacion ? '<br><em>Sin coordenadas GPS guardadas (no aparece con pin en el mapa)</em>' : ''); // Aviso extra solo si no tiene pin
  panel.appendChild(img); // Mete la foto en el cuadro
  panel.appendChild(info); // Mete el texto en el cuadro
  panel.classList.remove('oculto'); // Muestra el cuadro
}

function escaparHtml(texto) { // Función de seguridad: convierte caracteres especiales en texto inofensivo
  const div = document.createElement('div'); // Crea una caja temporal
  div.textContent = texto || ''; // Le pone el texto como texto plano (si viene vacío, usa "")
  return div.innerHTML; // Devuelve el texto ya "limpio" para meterlo sin riesgo en HTML
}

// ============ ARRANQUE ============

cargarPerros(); // Al abrir la página, pide la lista de perritos para llenar el mapa y las tarjetas
