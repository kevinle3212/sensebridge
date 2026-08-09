import type { ThemeMode, Translations } from "./types";

const modeName: Record<ThemeMode, string> = { system: "sistema", light: "claro", dark: "oscuro" };

export const es: Translations = {
  meta: {
    title: "SenseBridge — accesibilidad de código abierto, en el dispositivo y privada",
    description:
      "SenseBridge es una app gratuita y de código abierto para iPhone que traduce el entorno de una persona ciega o con baja visión en información hablada y clara, procesada completamente en el dispositivo.",
  },
  layout: {
    skipLink: "Saltar al contenido principal",
  },
  header: {
    nav: {
      features: "Funciones",
      privacy: "Privacidad",
      accessibility: "Accesibilidad",
      github: "GitHub",
    },
    themeToggle: {
      modeName,
      // `current`/`next` are the closed `ThemeMode` union, not arbitrary input.
      ariaLabel: (current, next) =>
        // eslint-disable-next-line security/detect-object-injection
        `Tema: ${modeName[current]}. Actívalo para el tema ${modeName[next]}.`,
    },
    languageSwitcher: {
      label: "Idioma",
    },
  },
  hero: {
    heading: "Percibe más. No compartas nada.",
    lede: "SenseBridge es una app gratuita y de código abierto para iPhone que traduce el entorno de una persona ciega o con baja visión en información hablada y clara — procesada completamente en el dispositivo, de modo que la cámara y tu entorno nunca salen de tu teléfono.",
    status:
      "SenseBridge está en desarrollo abierto y aún no está disponible para descargar. Puedes seguir su desarrollo en GitHub hoy mismo.",
    visuallyHiddenDescription:
      "Si estás escuchando esta página en lugar de verla: la imagen aquí muestra una señal que viaja desde la cámara de un teléfono, a través de un puente estilizado, y llega como una oración hablada — el mismo recorrido que describe esta página.",
    cta: "Sigue el progreso en GitHub",
  },
  features: {
    heading: "Qué hace hoy",
    intro: "Cinco capacidades, todas ejecutándose enteramente en el teléfono.",
    items: [
      "Lee en voz alta texto impreso y documentos.",
      "Identifica objetos y superficies comunes.",
      "Describe una escena en una oración natural.",
      "Ofrece conciencia cautelosa de obstáculos mediante LiDAR — nunca navegación.",
      "Anuncia eventos sonoros importantes cercanos.",
    ],
  },
  privacy: {
    heading: "Privado por arquitectura, no por política",
    body: "No hay backend, ni sistema de cuentas, ni telemetría por defecto. La percepción y el razonamiento se ejecutan en el dispositivo; nada sobre tu entorno sale de tu teléfono sin tu consentimiento explícito y revocable.",
    supporting: "Una política de privacidad puede cambiar. Una arquitectura sin servidor no puede.",
    fullNoticeLink: "Leer el aviso completo de privacidad y datos",
  },
  monitoring: {
    controlLabel: "Monitorización de errores",
    stateOn: "Activada — se envían informes cuando una página falla",
    stateOff: "Desactivada — no se envía nada",
    noScript:
      "Este control necesita JavaScript. Sin JavaScript, la monitorización de errores tampoco puede ejecutarse, así que no se recopila nada.",
    globalPrivacyControl:
      "Tu navegador envía una señal de Global Privacy Control, así que la monitorización de errores permanece desactivada y este control no se muestra. No se recopila nada.",
  },
  privacyPage: {
    title: "Privacidad y datos — SenseBridge",
    description:
      "Qué recopila este sitio, qué no recopila y cómo activar o desactivar la monitorización de errores. Sin cookies, sin analíticas, sin publicidad.",
    heading: "Privacidad y datos",
    lede: "Este sitio no recopila nada sobre ti por defecto. Aquí está exactamente qué significa eso, qué cambia si eliges lo contrario y cómo cambiar de opinión.",
    updated: "Última actualización",
    authoritative:
      "Este aviso se publica en varios idiomas. En caso de discrepancia, prevalece la versión en inglés.",
    choiceHeading: "Tu elección",
    choiceBody:
      "La monitorización de errores está desactivada hasta que la actives. Activada, envía un informe cuando una página de este sitio falla: qué salió mal y en qué parte de nuestro código, nunca quién eres. Desactivarla la detiene de inmediato.",
    choiceUnconfigured:
      "Esta instalación no tiene configurada ninguna monitorización de errores, así que no hay nada que activar y no se recopila nada.",
    sections: [
      {
        heading: "La versión corta",
        body: [
          "Sin cookies. Sin analíticas. Sin publicidad. Sin píxeles de seguimiento. Sin perfilado. No se vende nada y no se comparte nada para el marketing de terceros.",
          "Lo único que este sitio puede enviar sobre tu visita es un informe de que una página falló, y solo si lo activas arriba.",
        ],
      },
      {
        heading: "Qué se guarda en tu dispositivo",
        body: [
          "Solo preferencias que tú misma o tú mismo estableces. Ninguna es un identificador, ninguna es legible por otro sitio y ninguna se transmite a ningún lugar:",
        ],
        bullets: [
          "Si activaste o desactivaste la monitorización de errores, una vez que hayas usado el control de arriba.",
          "Tu tema claro u oscuro, si lo cambias respecto al del sistema.",
          "Una marca de depuración para desarrollo, solo si la estableces a mano.",
        ],
      },
      {
        heading: "Qué ve el servidor web",
        body: [
          "Como todo servidor web de internet, el host que sirve estas páginas procesa tu dirección IP, la página que pediste, la cadena de agente de usuario de tu navegador y la hora, porque sin ellas no se puede entregar una página. Este sitio está alojado en Vercel.",
          "Esos datos se usan para servir la página y para defender el sitio de abusos. No se combinan con nada más, no se usan para construir un perfil sobre ti y nosotros no conservamos ninguna copia.",
        ],
      },
      {
        heading: "Si activas la monitorización de errores",
        body: [
          "Solo entonces este sitio carga Sentry, un servicio de informes de errores. Hasta que digas que sí, ese código nunca se descarga: ni cargado y desactivado, ni presente e inactivo. Ausente.",
        ],
        bullets: [
          "Se envía cuando una página falla: el mensaje de error, el punto de nuestro código del que vino, la ruta de la página sin su cadena de consulta, la versión de tu navegador y sistema operativo, y el tamaño de tu pantalla.",
          "Nunca se envía: tu nombre, tu correo electrónico, tu dirección IP, tus cookies, tu ubicación, el contenido de nada que hayas escrito, ni ninguna grabación de tu pantalla o de lo que pulsaste.",
          "Session Replay, el rastreo de rendimiento, las migas de pan y el widget de comentarios están desactivados en el código, no simplemente sin usar.",
        ],
      },
      {
        heading: "Por qué y con qué base jurídica",
        body: [
          "Para quienes visitan desde el Reino Unido, el EEE y Suiza, el RGPD y el RGPD del Reino Unido exigen nombrar una base jurídica para cada finalidad:",
        ],
        bullets: [
          "Monitorización de errores — tu consentimiento, según el artículo 6(1)(a). Puedes retirarlo en cualquier momento con el control de arriba, con la misma facilidad con la que lo diste. Retirarlo no deshace el tratamiento que ya ocurrió.",
          "Servir estas páginas y mantener el sitio disponible — nuestro interés legítimo en tener un sitio web que funcione y no sufra abusos, según el artículo 6(1)(f).",
          "Recordar tu preferencia en tu dispositivo — estrictamente necesario para prestar algo que pediste, así que el almacenamiento en sí no requiere consentimiento aparte según el artículo 5(3) de la Directiva de privacidad electrónica.",
        ],
      },
      {
        heading: "Quién más interviene",
        body: [
          "Dos empresas, ambas en Estados Unidos, ambas actuando solo según nuestras instrucciones bajo un acuerdo de tratamiento de datos:",
        ],
        bullets: [
          "Vercel Inc. — alojamiento y entrega de estas páginas.",
          "Functional Software, Inc., que opera como Sentry — informes de errores, y solo si los activaste.",
        ],
      },
      {
        heading: "Salida del Reino Unido y el EEE",
        body: [
          "Ambos proveedores están en Estados Unidos, así que cualquier dato personal que traten sale del Reino Unido y del EEE. Esas transferencias se amparan en las Cláusulas Contractuales Tipo de la Comisión Europea y en su Adenda del Reino Unido.",
          "Nadie más recibe nada. No vendemos información personal y no la compartimos para publicidad conductual entre contextos, tal como definen esos términos la CCPA y la CPRA de California.",
        ],
      },
      {
        heading: "Cuánto tiempo se conserva",
        bullets: [
          "Informes de errores: 90 días en Sentry, y luego se eliminan automáticamente.",
          "La preferencia en tu dispositivo: hasta que la cambies o borres los datos de este sitio en tu navegador.",
          "Registros del servidor web: los conserva el host durante un breve periodo operativo, y nosotros nunca los copiamos a ningún sitio.",
        ],
        body: [],
      },
      {
        heading: "Tus derechos",
        body: [
          "Si estás en el Reino Unido, el EEE o Suiza, puedes preguntar qué tenemos sobre ti, hacer que se corrija o se borre, limitar u oponerte a su uso, recibirlo en un formato portátil y retirar tu consentimiento en cualquier momento. También puedes reclamar ante tu autoridad nacional de protección de datos: en España, la Agencia Española de Protección de Datos.",
          "Si estás en California, Colorado, Connecticut, Virginia, Texas u otro estado de EE. UU. con una ley de privacidad del consumidor, tienes los derechos equivalentes a saber, borrar, corregir y excluirte. Respetamos la señal Global Privacy Control: si tu navegador la envía, la monitorización de errores permanece desactivada diga lo que diga el control.",
          "En la práctica, casi nunca hay nada que entregar. Los informes de errores no llevan ningún identificador con el que pudiéramos localizarte, que es justamente el motivo de recopilarlos así. Escribe a la dirección de abajo y tendrás respuesta en 30 días, incluida, con honestidad, la de que no tenemos nada.",
        ],
      },
      {
        heading: "Menores",
        body: [
          "Este sitio no está dirigido a menores y no recopila de nadie nada que pudiera identificarle, a ninguna edad.",
        ],
      },
      {
        heading: "La app SenseBridge",
        body: [
          "La app es algo aparte y todavía no se ha publicado. Procesa los datos de cámara, micrófono y profundidad enteramente en tu dispositivo y no envía ninguno a ningún sitio.",
          "Tiene su propio informe de fallos, desactivado por defecto, tras el mismo tipo de control en Ajustes y luego Diagnóstico. Activado, envía un informe si la app se bloquea o se congela: en qué parte del código ocurrió, tu modelo de iPhone y las versiones de iOS y de la app. Nunca una imagen, nunca lo que leyó la cámara, nunca audio, nunca tu ubicación.",
        ],
      },
      {
        heading: "Cambios en este aviso",
        body: [
          "Si alguna vez cambia lo que se recopila, esta página cambia primero. El consentimiento dado bajo una descripción más estrecha se vuelve a pedir en lugar de trasladarse en silencio a una más amplia.",
        ],
      },
      {
        heading: "Contacto",
        body: [
          "Kevin K. Le, responsable del proyecto, es el responsable del tratamiento. Escribe a kevinle3212@gmail.com sobre cualquier cosa de esta página.",
        ],
      },
    ],
  },
  accessibility: {
    heading: "Construido de la forma en que pide ser juzgado",
    body: "Este sitio está construido con prioridad para lectores de pantalla, con el mismo estándar que promete la app: estructura semántica, cada control etiquetado, soporte completo de teclado, WCAG 2.2 AA. Si usas VoiceOver o NVDA, esta página ya debería sentirse como en casa.",
    leadIn: "¿Prefieres escuchar? Esta página puede leerse en voz alta.",
  },
  accessibilityPage: {
    title: "Declaración de accesibilidad — SenseBridge",
    description:
      "Qué está verificado, qué no lo está y cómo informar de una barrera. Escrita para poder comprobarse, no para tranquilizar.",
    heading: "Declaración de accesibilidad",
    lede: "SenseBridge es un producto de accesibilidad. Eso eleva el estándar al que debe someterse este sitio, no lo rebaja: por eso esta declaración está escrita para comprobarse, no para creerse. Donde algo está verificado, se dice qué lo verificó. Donde no lo está, se dice también.",
    updated: "Última revisión",
    authoritative:
      "Esta declaración se publica en varios idiomas. En caso de discrepancia, prevalece la versión en inglés.",
    sections: [
      {
        heading: "Los estándares que seguimos",
        body: [
          "WCAG 2.2 nivel AA es la base vinculante para este sitio y para la app. Todas las comprobaciones automáticas descritas más abajo lo exigen.",
          "EN 301 549 v3.2.1 — la norma armonizada europea, y la referencia con la que se evalúa la Ley Europea de Accesibilidad — incorpora esa misma base de nivel AA para el contenido web.",
          "El nivel AAA es una aspiración, cumplida en puntos concretos y no reclamada como conformidad. El propio W3C advierte que el nivel AAA no es alcanzable para sitios completos como política general, y estamos de acuerdo.",
        ],
      },
      {
        heading: "Estado de conformidad",
        body: [
          "Este sitio es parcialmente conforme con WCAG 2.2 nivel AA y con EN 301 549 v3.2.1, en el sentido concreto en que esas plantillas usan la expresión: las pruebas automáticas no encuentran incumplimientos y ninguna parte independiente ha hecho una auditoría manual. Esa distancia se describe en «Lo que no se ha hecho», porque es la parte útil de una declaración como esta.",
        ],
      },
      {
        heading: "Lo que se comprueba en cada cambio",
        body: [
          "Ninguna de estas comprobaciones es un informe puntual. Cada una se ejecuta antes de que un cambio pueda publicarse, y un fallo lo detiene:",
        ],
        bullets: [
          "Cada página publicada se prueba contra el conjunto de reglas WCAG 2.2 nivel AA con dos motores independientes — HTML CodeSniffer y axe-core — en un navegador forzado a movimiento reducido. Un solo error hace fallar la compilación.",
          "Cada página publicada se prueba además contra el conjunto de reglas de nivel AAA. Esa pasada informa, no bloquea, por el motivo que se explica más abajo.",
          "Cada página es un documento completo y legible con JavaScript desactivado. El movimiento es opcional y no se instancia nada en absoluto cuando tu sistema pide movimiento reducido.",
          "La Content-Security-Policy de producción se ejercita contra el sitio ya compilado, para que una política que elimine silenciosamente una hoja de estilos no pueda publicarse y dejar estas páginas sin estilo e ilegibles.",
          "El audio narrado se contrasta con el texto de la página, de modo que un cambio de redacción no pueda dejar una narración obsoleta sin avisar.",
        ],
      },
      {
        heading: "Dónde superamos el nivel AA",
        body: [
          "Se nombran uno a uno en lugar de reclamar un nivel, porque un criterio de nivel AAA cumplido en una página no es conformidad de nivel AAA:",
        ],
        bullets: [
          "1.4.6 Contraste (mejorado) — todos los colores que llevan texto en este sitio cumplen la relación 7:1 del nivel AAA, no el mínimo 4.5:1 del nivel AA, y la cumplen frente al fondo más oscuro sobre el que llegan a colocarse, no solo frente al fondo de la página.",
          "2.2.3 Sin tiempo — aquí nada tiene límite de tiempo.",
          "2.3.2 Tres destellos — no hay ningún destello.",
          "2.4.9 Propósito del enlace (solo el enlace) — los enlaces están redactados para entenderse fuera de contexto, que es como los presenta el rotor de un lector de pantalla.",
          "3.3.5 Ayuda — la vía para informar de una barrera está en el pie de cada página, no escondida en una sección de soporte.",
        ],
      },
      {
        heading: "Por qué no reclamamos el nivel AAA",
        body: [
          "Reclamarlo para todo el sitio sería exactamente el tipo de exageración que esta declaración existe para evitar. En concreto: no existe una versión en lengua de signos del audio narrado (1.2.6), y los criterios de nivel de lectura y pronunciación (del 3.1.3 al 3.1.6) imponen obligaciones sobre el contenido traducido que un sitio en tres idiomas mantenido por una sola persona no puede garantizar con honestidad en cada cambio.",
          "Cuando un criterio de nivel AAA es barato y duradero, lo tomamos. Cuando cumplirlo exigiría una promesa que no podemos sostener en cada cambio, lo decimos aquí en lugar de reclamarlo.",
        ],
      },
      {
        heading: "Lo que no se ha hecho",
        body: [
          "Dicho sin rodeos, porque una declaración de accesibilidad que solo enumera sus aciertos es publicidad:",
        ],
        bullets: [
          "No se ha realizado ninguna auditoría de accesibilidad independiente por parte de un tercero, ni en este sitio ni en la app.",
          "No se ha completado ninguna validación formal con personas ciegas o con baja visión. Las comprobaciones automáticas no pueden decirte si una página tiene sentido para quien la recorre de oído; solo esas personas pueden. Este es el mayor riesgo abierto de accesibilidad del proyecto y se registra como tal.",
          "Las pruebas automáticas tienen límites. Las herramientas de este tipo detectan una minoría de las barreras reales — se cita habitualmente alrededor de un tercio. Una página puede pasar todas las reglas automáticas y seguir siendo confusa, mal etiquetada o inservible en la práctica.",
          "No se ha elaborado ningún VPAT ni informe de conformidad de accesibilidad.",
        ],
      },
      {
        heading: "Limitaciones conocidas",
        bullets: [
          "El audio narrado cubre el contenido principal de la página de inicio, no la navegación ni el pie.",
          "Las páginas en español y en vietnamita se revisan por exactitud de significado, pero no se han probado con un lector de pantalla funcionando en esos idiomas.",
          "Cuando aparece un control del navegador o del sistema operativo, su accesibilidad depende de quien lo fabrica, no de nosotros.",
          "La representación en alto contraste y en colores forzados está implementada según los ajustes de la propia plataforma, pero no ha sido auditada por una parte externa.",
        ],
        body: [],
      },
      {
        heading: "La app SenseBridge",
        body: [
          "Todavía no se reclama conformidad para la app. No se ha publicado y esta declaración no va a fingir que una versión previa al lanzamiento ha sido auditada.",
          "Su control interno es más estricto que un porcentaje — cero elementos interactivos sin etiqueta en cada pantalla, con una revisión con VoiceOver obligatoria sobre cualquier interfaz modificada antes de que el cambio pueda integrarse — pero un control de desarrollo no es una auditoría de conformidad.",
        ],
      },
      {
        heading: "Cuéntanos una barrera",
        body: [
          "Si alguna parte de SenseBridge no te resulta utilizable, eso es un defecto, y se trata con la misma prioridad que un fallo grave, no como una petición de función.",
          "Escribe a kevinle3212@gmail.com. Describe qué intentabas hacer, qué tecnología de apoyo usabas y su versión si la conoces, y qué ocurrió en su lugar. No necesitas conocer la causa técnica ni expresarlo en terminología de accesibilidad.",
          "Nuestro objetivo es confirmar la recepción en 5 días laborables y dar una respuesta sustantiva — una corrección, o un plazo para ella — en 30 días. Este es el mecanismo de retroalimentación que la Ley Europea de Accesibilidad y la EN 301 549 exigen nombrar en una declaración, y lo lee directamente el responsable del proyecto.",
        ],
      },
      {
        heading: "Si no lo arreglamos",
        body: [
          "Este proyecto es previo al lanzamiento, gratuito y mantenido por una sola persona. No hay ningún organismo de control formal implicado. Si no resolvemos tu aviso, conservas todas las vías de reclamación que te da la ley de tu lugar de residencia: la autoridad de vigilancia del mercado designada por tu Estado miembro de la UE, la vía de la Equality Act en el Reino Unido, una denuncia ante el Departamento de Justicia bajo la ADA en Estados Unidos, el Comisionado de Accesibilidad en Canadá o la Comisión Australiana de Derechos Humanos.",
          "Nada en esta declaración, ni en nuestros términos, limita ninguna de esas vías.",
        ],
      },
      {
        heading: "Cómo se mantiene honesta esta declaración",
        body: [
          "Se revisa siempre que un cambio afecta a una comprobación de accesibilidad y, como mínimo, una vez cada doce meses. La versión completa, con las leyes concretas frente a las que está escrita, se publica en el repositorio del proyecto como legal/ACCESSIBILITY_STATEMENT.md. Ninguno de los dos documentos puede reclamar una comprobación que el otro no haga.",
        ],
      },
    ],
  },
  readAloud: {
    deviceIdleLabel: "Escuchar (voz del dispositivo)",
    naturalIdleLabel: "Escuchar (voz natural)",
    stopLabel: "Detener lectura",
    readingPage: "Leyendo la página…",
    finishedReading: "Lectura finalizada.",
    readingStopped: "Lectura detenida.",
    stopped: "Detenido.",
    readingPageNatural: "Leyendo la página con voz natural…",
    naturalPlaybackError: "No se pudo reproducir la narración con voz natural.",
  },
  bridge: {
    heading: "Construido como su nombre",
    body: "SenseBridge existe para conectar dos cosas: la señal en bruto de una cámara y la oración sencilla que una persona intenta escuchar. Todo lo que hay entre ellas — percepción, razonamiento, renderizado — es el tramo de ese puente, ensamblado enteramente en tu teléfono.",
    supporting:
      "Sin cruce por la nube. Sin barrera de cuenta. Solo el camino más corto de la percepción a la comprensión.",
    replay: "Repetir la animación del puente",
  },
  phone: {
    heading: "Todo el sistema es el teléfono en tu bolsillo",
    lede: "Sin hardware adicional, sin nube. SenseBridge se está construyendo para ejecutarse enteramente en los propios sensores y el silicio del iPhone — así es como cada parte transporta la señal.",
    diagramDescription:
      "Diagrama: un iPhone dibujado como una estructura de alambre se separa en tres capas. La cámara y el escáner LiDAR en la parte trasera capturan la escena. El Neural Engine en el medio ejecuta modelos de percepción y razonamiento en el dispositivo. El altavoz y el Taptic Engine en la parte frontal convierten la comprensión en voz y vibraciones suaves.",
    annotations: [
      {
        label: "01 · CAPTURA",
        title: "Cámara + LiDAR",
        body: "Aquí entran la luz y la profundidad. La cámara y el escáner LiDAR muestrean la forma de la escena para que la app tenga algo verídico que describir. En la arquitectura, esta es la costura SensingSource — la única puerta por la que entra el mundo.",
      },
      {
        label: "02 · RAZONAMIENTO",
        title: "Neural Engine",
        body: "Los modelos en el dispositivo convierten píxeles y profundidad en una descripción cautelosa y en lenguaje sencillo. La percepción y el razonamiento se ejecutan enteramente en el propio silicio del teléfono — nada se sube, nada sale de tu mano.",
      },
      {
        label: "03 · RENDERIZADO",
        title: "Altavoz + Taptic Engine",
        body: "Lo que el teléfono comprende regresa como voz y vibraciones suaves — la costura RenderTarget. Siempre expresado como conciencia, nunca como una promesa de seguridad.",
      },
    ],
  },
  future: {
    kicker: "Una dirección futura — no un producto",
    heading: "Hacia dónde podría ir el puente después",
    lede: "SenseBridge se está construyendo primero para el teléfono. Pero el mismo flujo en el dispositivo — sentir, razonar, renderizar — podría algún día funcionar en hardware más ligero, más cerca de los sentidos a los que sirve.",
    body: "Dispositivos vestibles como gafas con cámara podrían permitir que las mismas descripciones cautelosas y privadas lleguen sin usar las manos. Nada de ese futuro está prometido; las costuras del protocolo simplemente se están diseñando para que siga siendo posible.",
    illustrationDescription:
      "Ilustración: un par de gafas dibujadas como una estructura de alambre translúcida gira lentamente. Cada pocos segundos, un pequeño punto de luz azul recorre el armazón — baja por una patilla, rodea su lente, cruza el puente, rodea la otra lente y baja por la patilla lejana — calentándose a ámbar al llegar.",
  },
  followProgress: {
    heading: "Desarrollado abiertamente",
    body: "Todo lo sustancial que acabas de leer es verificable: el código, las decisiones de arquitectura y la distancia que aún queda por recorrer son públicos. Si SenseBridge despertó tu interés, la manera de actuar hoy es observar cómo se construye.",
    link: "Observa el desarrollo en GitHub",
  },
  footer: {
    tagline: "SenseBridge es gratuito y de código abierto. Sin suscripción, nunca.",
    githubLink: "SenseBridge en GitHub",
    privacyLink: "Privacidad y datos",
    accessibilityLink: "Declaración de accesibilidad",
    notAvailable:
      "Aún no disponible en la App Store — SenseBridge está en fase previa al lanzamiento y en desarrollo abierto.",
    voiceCredit: "Narración con voz natural generada con elevenlabs.io.",
    monitoringCredit:
      "Monitorización de errores disponible mediante sentry.io, desactivada hasta que la actives.",
    poweredBy: "Desarrollado con",
    makerPhotoAlt: "Kevin K. Le, actualmente el único desarrollador del proyecto",
  },
  disclaimer: {
    ariaLabel: "Aviso de seguridad",
    text: "SenseBridge te ayuda a tomar conciencia de tu entorno. No es un dispositivo de seguridad para movilidad o navegación, y sus descripciones pueden ser incorrectas — úsalo siempre junto con tu propio juicio, un bastón o un perro guía.",
  },
  errorPages: {
    backHome: "Volver al inicio",
    notFound: {
      heading: "Esta página se cayó en un hoyo.",
      body: "En algún punto entre aquí y allá, esta página se desvió y terminó en un hoyo. Le pasa a los mejores — el resto del sitio sigue en terreno firme.",
    },
    badRequest: {
      heading: "Algo en esa solicitud no estaba del todo bien.",
      body: "Esta vez la página no cayó en un hoyo — la solicitud tomó un desvío antes de llegar aquí.",
    },
    serverError: {
      heading: "Algo falló de nuestro lado. Lo sentimos.",
      body: "Hasta una vaca bien dibujada tiene un mal día. Esto no fue algo que hiciste tú — intenta de nuevo en un momento.",
    },
    statusLabel: "HTTP {code} · {phrase}",
    classes: {
      informational: {
        heading: "Este es el protocolo pensando en voz alta.",
        body: "Un estado 1xx es una respuesta provisional: el servidor avisando que todavía trabaja en la definitiva. Casi nunca lo verás en un navegador, pero aun así tiene su página aquí.",
      },
      success: {
        heading: "Aquí no salió nada mal.",
        body: "Un estado 2xx significa que la solicitud funcionó. La vaca se cae por sus propios motivos — esta página existe para que cada código del registro tenga la suya.",
      },
      redirect: {
        heading: "Este apunta a otro lugar.",
        body: "Un estado 3xx significa que lo que pediste vive en otra dirección. Normalmente tu navegador la sigue sin mostrarte nunca esta página.",
      },
      client: {
        heading: "Esa solicitud no llegó del todo bien.",
        body: "Un estado 4xx significa que algo en la solicitud misma no encajaba: la dirección, el método o lo que venía con ella. El resto del sitio sigue en terreno firme.",
      },
      server: {
        heading: "Algo falló de nuestro lado.",
        body: "Un estado 5xx significa que la solicitud estaba bien y el servidor no. Esto no fue algo que hiciste tú — intenta de nuevo en un momento.",
      },
    },
  },
};
