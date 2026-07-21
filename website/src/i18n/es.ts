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
  },
  accessibility: {
    heading: "Construido de la forma en que pide ser juzgado",
    body: "Este sitio está construido con prioridad para lectores de pantalla, con el mismo estándar que promete la app: estructura semántica, cada control etiquetado, soporte completo de teclado, WCAG 2.2 AA. Si usas VoiceOver o NVDA, esta página ya debería sentirse como en casa.",
    leadIn: "¿Prefieres escuchar? Esta página puede leerse en voz alta.",
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
    notAvailable:
      "Aún no disponible en la App Store — SenseBridge está en fase previa al lanzamiento y en desarrollo abierto.",
  },
  disclaimer: {
    ariaLabel: "Aviso de seguridad",
    text: "SenseBridge te ayuda a tomar conciencia de tu entorno. No es un dispositivo de seguridad para movilidad o navegación, y sus descripciones pueden ser incorrectas — úsalo siempre junto con tu propio juicio, un bastón o un perro guía.",
  },
};
