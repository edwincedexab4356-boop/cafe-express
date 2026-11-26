window.CX_CONFIG = {
  // Datos de Supabase (Settings > API). Si se dejan vacíos, todo funciona en MODO DEMO en este navegador.
  supabaseUrl: 'https://czxcvpdzcpsetchovuuk.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6eGN2cGR6Y3BzZXRjaG92dXVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU3MTUzNjEsImV4cCI6MjExMTI5MTM2MX0.B9164sZec1HRETQPh-kWw3uiZy4e5aJigN933twLPZ8',

  negocio: 'Cafe Express',
  meta: 15,          // sellos para la bebida gratis (debe coincidir con la tabla ajustes)
  maxDia: 2,         // sellos máximos por cliente al día
  esperaMin: 20,     // minutos mínimos entre un sello y otro
  vigenciaSeg: 180,  // cuánto dura válido cada QR
  rotarSeg: 30,      // cada cuánto cambia el QR en la pantalla del puesto
  cuponSeg: 120,     // cuánto dura en pantalla el cupón de bebida gratis

  // Solo para MODO DEMO (en la versión real esto vive en la base de datos)
  demo: {
    puestos: [
      { id: 1, nombre: 'Puesto 1', clave: '1111' },
      { id: 2, nombre: 'Puesto 2', clave: '2222' },
      { id: 3, nombre: 'Puesto 3', clave: '3333' }
    ],
    claveDueno: 'dueno123'
  }
};
