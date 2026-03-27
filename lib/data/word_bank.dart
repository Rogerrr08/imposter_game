import 'dart:math';

final _random = Random();

enum WordCategory {
  cosas,
  entretenimiento,
  geografia,
  deportes;

  String get displayName {
    switch (this) {
      case WordCategory.cosas:
        return 'Cosas';
      case WordCategory.entretenimiento:
        return 'Entretenimiento';
      case WordCategory.geografia:
        return 'Geografía';
      case WordCategory.deportes:
        return 'Deportes';
    }
  }

  String get icon {
    switch (this) {
      case WordCategory.cosas:
        return '📦';
      case WordCategory.entretenimiento:
        return '🎬';
      case WordCategory.geografia:
        return '🌍';
      case WordCategory.deportes:
        return '⚽';
    }
  }
}

class WordEntry {
  final String word;
  final List<String> hints;
  final WordCategory category;

  const WordEntry({
    required this.word,
    required this.hints,
    required this.category,
  });
}

class WordBank {
  static final List<WordEntry> _allWords = [
    // ============================================================
    // COSAS (50 words)
    // ============================================================
    const WordEntry(
      word: 'Paraguas',
      hints: ['Lluvia', 'Plegable', 'Mojarse'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Reloj',
      hints: ['Hora', 'Manecillas', 'Puntualidad'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Espejo',
      hints: ['Reflejo', 'Vidrio', 'Vanidad'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Vela',
      hints: ['Cera', 'Llama', 'Oscuridad'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Tijeras',
      hints: ['Cortar', 'Filo', 'Papel'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Almohada',
      hints: ['Dormir', 'Suave', 'Cama'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Llave',
      hints: ['Cerradura', 'Metal', 'Abrir'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Cuchara',
      hints: ['Sopa', 'Cubierto', 'Revolver'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Escalera',
      hints: ['Subir', 'Peldaños', 'Altura'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Sombrero',
      hints: ['Cabeza', 'Sol', 'Elegancia'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Maleta',
      hints: ['Viaje', 'Equipaje', 'Ropa'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Lámpara',
      hints: ['Iluminar', 'Bombilla', 'Noche'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Billetera',
      hints: ['Dinero', 'Bolsillo', 'Tarjetas'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Guitarra',
      hints: ['Cuerdas', 'Melodía', 'Rasgueo'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Bicicleta',
      hints: ['Pedales', 'Ruedas', 'Paseo'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Cámara',
      hints: ['Fotografía', 'Lente', 'Recuerdos'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Libro',
      hints: ['Páginas', 'Leer', 'Historia'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Teléfono',
      hints: ['Llamar', 'Pantalla', 'Contactos'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Televisor',
      hints: ['Canales', 'Pantalla', 'Control'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Silla',
      hints: ['Sentarse', 'Respaldo', 'Madera'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Cepillo de dientes',
      hints: ['Higiene', 'Pasta', 'Boca'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Gafas',
      hints: ['Vista', 'Cristales', 'Montura'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Nevera',
      hints: ['Frío', 'Alimentos', 'Cocina'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Zapatos',
      hints: ['Pies', 'Caminar', 'Cordones'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Computadora',
      hints: ['Teclado', 'Internet', 'Archivos'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Jabón',
      hints: ['Limpieza', 'Espuma', 'Manos'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Mochila',
      hints: ['Espalda', 'Escuela', 'Cargar'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Anillo',
      hints: ['Dedo', 'Joya', 'Compromiso'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Calendario',
      hints: ['Fechas', 'Meses', 'Planificar'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Globo',
      hints: ['Aire', 'Fiesta', 'Colorido'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Martillo',
      hints: ['Clavo', 'Golpear', 'Herramienta'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Bufanda',
      hints: ['Cuello', 'Invierno', 'Abrigo'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Peine',
      hints: ['Cabello', 'Desenredar', 'Dientes'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Tenedor',
      hints: ['Pinchar', 'Cubierto', 'Comer'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Corbata',
      hints: ['Cuello', 'Formal', 'Nudo'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Mapa',
      hints: ['Ubicación', 'Rutas', 'Territorio'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Batería',
      hints: ['Energía', 'Carga', 'Voltaje'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Candado',
      hints: ['Seguridad', 'Combinación', 'Cerrar'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Bolígrafo',
      hints: ['Tinta', 'Escribir', 'Papel'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Ventilador',
      hints: ['Brisa', 'Aspas', 'Calor'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Sobre',
      hints: ['Carta', 'Correo', 'Sello'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Dado',
      hints: ['Números', 'Azar', 'Cubo'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Plancha',
      hints: ['Arrugas', 'Vapor', 'Ropa'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Casco',
      hints: ['Protección', 'Cabeza', 'Seguridad'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Taza',
      hints: ['Café', 'Asa', 'Beber'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Imán',
      hints: ['Atraer', 'Metal', 'Nevera'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Moneda',
      hints: ['Valor', 'Redonda', 'Cambio'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Pegamento',
      hints: ['Pegar', 'Adhesivo', 'Unir'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Brújula',
      hints: ['Norte', 'Orientación', 'Aguja'],
      category: WordCategory.cosas,
    ),
    const WordEntry(
      word: 'Agenda',
      hints: ['Tareas', 'Organizar', 'Fechas'],
      category: WordCategory.cosas,
    ),

    // ============================================================
    // ENTRETENIMIENTO (50 words)
    // ============================================================
    const WordEntry(
      word: 'Mario Bros',
      hints: ['Fontanero', 'Nintendo', 'Princesa'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Harry Potter',
      hints: ['Magia', 'Cicatriz', 'Hogwarts'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'El Rey León',
      hints: ['Simba', 'Sabana', 'Disney'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Minecraft',
      hints: ['Bloques', 'Construir', 'Creepers'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Bob Esponja',
      hints: ['Marino', 'Amarillo', 'Hamburguesas'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Shakira',
      hints: ['Colombia', 'Caderas', 'Cantante'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Spider-Man',
      hints: ['Telarañas', 'Arácnido', 'Héroe'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Frozen',
      hints: ['Hielo', 'Hermanas', 'Canción'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Pikachu',
      hints: ['Eléctrico', 'Amarillo', 'Pokémon'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Bad Bunny',
      hints: ['Reggaetón', 'Puertorriqueño', 'Benito'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Toy Story',
      hints: ['Juguetes', 'Pixar', 'Woody'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Batman',
      hints: ['Murciélago', 'Gótica', 'Millonario'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Mickey Mouse',
      hints: ['Orejas', 'Disney', 'Ratón'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Stranger Things',
      hints: ['Netflix', 'Once', 'Paralelo'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Shrek',
      hints: ['Ogro', 'Pantano', 'Burro'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Taylor Swift',
      hints: ['Pop', 'Estadounidense', 'Eras'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Los Simpson',
      hints: ['Amarillos', 'Springfield', 'Animación'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Titanic',
      hints: ['Barco', 'Naufragio', 'Romance'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Fortnite',
      hints: ['Bailes', 'Construcción', 'Royale'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Darth Vader',
      hints: ['Oscuro', 'Casco', 'Respiración'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Encanto',
      hints: ['Madrigal', 'Colombia', 'Poderes'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Jurassic Park',
      hints: ['Dinosaurios', 'Spielberg', 'Parque'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Elsa',
      hints: ['Hielo', 'Princesa', 'Poderes'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Dragon Ball',
      hints: ['Goku', 'Esferas', 'Anime'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Monopoly',
      hints: ['Propiedades', 'Tablero', 'Billetes'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Indiana Jones',
      hints: ['Arqueólogo', 'Látigo', 'Tesoros'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'La Casa de Papel',
      hints: ['Atraco', 'Máscaras', 'Dalí'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Naruto',
      hints: ['Ninja', 'Hokage', 'Zorro'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Cenicienta',
      hints: ['Zapatilla', 'Hada', 'Medianoche'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Among Us',
      hints: ['Impostor', 'Tripulantes', 'Nave'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'El Señor de los Anillos',
      hints: ['Hobbits', 'Anillo', 'Mordor'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Rihanna',
      hints: ['Barbados', 'Umbrella', 'Cantante'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Pac-Man',
      hints: ['Laberinto', 'Fantasmas', 'Puntos'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Juego de Tronos',
      hints: ['Dragones', 'Reinos', 'HBO'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Buzz Lightyear',
      hints: ['Espacial', 'Juguete', 'Infinito'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Coco',
      hints: ['Muertos', 'Guitarra', 'Pixar'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'GTA',
      hints: ['Autos', 'Crimen', 'Abierto'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Maléfica',
      hints: ['Cuernos', 'Hechizo', 'Villana'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'El Chavo del 8',
      hints: ['Barril', 'Vecindad', 'Mexicano'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Avatar',
      hints: ['Azules', 'Pandora', 'Cameron'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Sonic',
      hints: ['Erizo', 'Velocidad', 'Anillos'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Aladdin',
      hints: ['Lámpara', 'Genio', 'Alfombra'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'The Beatles',
      hints: ['Liverpool', 'Legendarios', 'Banda'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Squid Game',
      hints: ['Coreana', 'Mortales', 'Millonario'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Rapunzel',
      hints: ['Cabello', 'Torre', 'Princesa'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Iron Man',
      hints: ['Armadura', 'Stark', 'Tecnología'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Nemo',
      hints: ['Payaso', 'Océano', 'Perdido'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Tetris',
      hints: ['Bloques', 'Líneas', 'Caer'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Wolverine',
      hints: ['Garras', 'Mutante', 'Regeneración'],
      category: WordCategory.entretenimiento,
    ),
    const WordEntry(
      word: 'Moana',
      hints: ['Océano', 'Isla', 'Navegar'],
      category: WordCategory.entretenimiento,
    ),

    // ============================================================
    // GEOGRAFÍA (50 words)
    // ============================================================
    const WordEntry(
      word: 'Brasil',
      hints: ['Carnaval', 'Samba', 'Sudamérica'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Torre Eiffel',
      hints: ['París', 'Hierro', 'Monumento'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Japón',
      hints: ['Sushi', 'Samurái', 'Oriental'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Río Amazonas',
      hints: ['Caudaloso', 'Selva', 'Sudamérica'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Egipto',
      hints: ['Pirámides', 'Faraones', 'Desierto'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Monte Everest',
      hints: ['Cumbre', 'Himalaya', 'Escaladores'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Australia',
      hints: ['Canguros', 'Oceanía', 'Koalas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Gran Muralla China',
      hints: ['Milenaria', 'Defensa', 'Inmensa'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'México',
      hints: ['Tacos', 'Aztecas', 'Norteamérica'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Océano Pacífico',
      hints: ['Inmenso', 'Profundo', 'Costas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Italia',
      hints: ['Bota', 'Pizza', 'Roma'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Machu Picchu',
      hints: ['Incas', 'Montaña', 'Ruinas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Canadá',
      hints: ['Arce', 'Frío', 'Hockey'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Sahara',
      hints: ['Dunas', 'Arena', 'Calor'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Argentina',
      hints: ['Tango', 'Pampas', 'Asado'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Cataratas del Niágara',
      hints: ['Cascadas', 'Frontera', 'Imponentes'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'India',
      hints: ['Especias', 'Bollywood', 'Poblada'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Antártida',
      hints: ['Hielo', 'Pingüinos', 'Polar'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'España',
      hints: ['Flamenco', 'Paella', 'Toros'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Río Nilo',
      hints: ['Africano', 'Egipto', 'Largo'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Colombia',
      hints: ['Café', 'Cumbia', 'Esmeraldas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Estatua de la Libertad',
      hints: ['Antorcha', 'Manhattan', 'Francia'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Grecia',
      hints: ['Filosofía', 'Islas', 'Atenas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Islandia',
      hints: ['Volcanes', 'Géiseres', 'Nórdico'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Himalaya',
      hints: ['Cordillera', 'Nieve', 'Asia'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Cuba',
      hints: ['Caribe', 'Habana', 'Salsa'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Gran Cañón',
      hints: ['Colorado', 'Erosión', 'Profundo'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Rusia',
      hints: ['Moscú', 'Extenso', 'Kremlin'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Mar Mediterráneo',
      hints: ['Europa', 'África', 'Costas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Perú',
      hints: ['Ceviche', 'Lima', 'Andino'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Coliseo Romano',
      hints: ['Gladiadores', 'Anfiteatro', 'Antiguo'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Noruega',
      hints: ['Fiordos', 'Auroras', 'Vikingos'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Lago Titicaca',
      hints: ['Altiplano', 'Navegable', 'Fronterizo'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Tokio',
      hints: ['Tecnología', 'Japón', 'Metrópoli'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Cordillera de los Andes',
      hints: ['Extensa', 'Sudamérica', 'Montañas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Alemania',
      hints: ['Berlín', 'Cerveza', 'Europa'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Galápagos',
      hints: ['Tortugas', 'Darwin', 'Islas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Francia',
      hints: ['Vino', 'Queso', 'París'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Volcán Vesubio',
      hints: ['Pompeya', 'Erupción', 'Nápoles'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Chile',
      hints: ['Angosto', 'Santiago', 'Vino'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Taj Mahal',
      hints: ['Mármol', 'India', 'Amor'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Mar Caribe',
      hints: ['Tropical', 'Turquesa', 'Islas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Venezuela',
      hints: ['Cascada', 'Petróleo', 'Caracas'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Stonehenge',
      hints: ['Piedras', 'Misterio', 'Antiguo'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Costa Rica',
      hints: ['Biodiversidad', 'Volcanes', 'Centroamérica'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Monte Fuji',
      hints: ['Japón', 'Volcán', 'Nevado'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Océano Atlántico',
      hints: ['Separación', 'Navegación', 'Vasto'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Panamá',
      hints: ['Canal', 'Istmo', 'Conexión'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Selva Amazónica',
      hints: ['Pulmón', 'Biodiversidad', 'Tropical'],
      category: WordCategory.geografia,
    ),
    const WordEntry(
      word: 'Dubái',
      hints: ['Rascacielos', 'Lujo', 'Desierto'],
      category: WordCategory.geografia,
    ),

    // ============================================================
    // DEPORTES (50 words)
    // ============================================================
    const WordEntry(
      word: 'Lionel Messi',
      hints: ['Argentina', 'Barcelona', 'Goles'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Fútbol',
      hints: ['Balón', 'Portería', 'Cancha'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'LeBron James',
      hints: ['Lakers', 'NBA', 'Rey'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Juegos Olímpicos',
      hints: ['Anillos', 'Medallas', 'Cuatrienal'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Usain Bolt',
      hints: ['Velocidad', 'Jamaica', 'Rayo'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Tenis',
      hints: ['Raqueta', 'Sets', 'Red'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Michael Jordan',
      hints: ['Bulls', 'Zapatillas', 'Leyenda'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Copa del Mundo',
      hints: ['Selecciones', 'Trofeo', 'Mundial'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Cristiano Ronaldo',
      hints: ['Portugal', 'Goleador', 'Celebración'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Baloncesto',
      hints: ['Canasta', 'Aro', 'Driblar'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Serena Williams',
      hints: ['Tenista', 'Potencia', 'Campeona'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Natación',
      hints: ['Piscina', 'Estilos', 'Acuático'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Real Madrid',
      hints: ['Blanco', 'Champions', 'España'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Boxeo',
      hints: ['Guantes', 'Ring', 'Nocaut'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Rafael Nadal',
      hints: ['Español', 'Arcilla', 'Tenista'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Super Bowl',
      hints: ['Americano', 'Espectáculo', 'Final'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Neymar',
      hints: ['Brasileño', 'Regates', 'Habilidad'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Atletismo',
      hints: ['Carreras', 'Saltos', 'Pista'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Barcelona FC',
      hints: ['Azulgrana', 'Cataluña', 'Camp'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Fórmula 1',
      hints: ['Velocidad', 'Monoplazas', 'Circuito'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Tiger Woods',
      hints: ['Golf', 'Estadounidense', 'Hoyos'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Voleibol',
      hints: ['Red', 'Remate', 'Saque'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Maradona',
      hints: ['Argentina', 'Leyenda', 'Gol'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Tour de Francia',
      hints: ['Ciclismo', 'Etapas', 'Amarillo'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Simone Biles',
      hints: ['Gimnasia', 'Olímpica', 'Acrobacias'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Béisbol',
      hints: ['Bate', 'Diamante', 'Lanzador'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Pelé',
      hints: ['Brasil', 'Rey', 'Mundiales'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Champions League',
      hints: ['Europa', 'Himno', 'Clubes'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Kylian Mbappé',
      hints: ['Francés', 'Velocidad', 'Goleador'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Golf',
      hints: ['Hoyo', 'Palos', 'Césped'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Mike Tyson',
      hints: ['Boxeador', 'Nocaut', 'Pesado'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Rugby',
      hints: ['Ovalado', 'Tackle', 'Contacto'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Lewis Hamilton',
      hints: ['Piloto', 'Británico', 'Campeonatos'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Estadio Santiago Bernabéu',
      hints: ['Madrid', 'Blanco', 'Fútbol'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Ciclismo',
      hints: ['Pedales', 'Ruedas', 'Etapas'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Stephen Curry',
      hints: ['Triples', 'Warriors', 'NBA'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Karate',
      hints: ['Cinturón', 'Patadas', 'Marcial'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Estadio Maracaná',
      hints: ['Río', 'Brasil', 'Enorme'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Skateboarding',
      hints: ['Tabla', 'Trucos', 'Rampas'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Zinedine Zidane',
      hints: ['Francés', 'Cabezazo', 'Entrenador'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Wimbledon',
      hints: ['Césped', 'Londres', 'Tenis'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Gimnasia',
      hints: ['Acrobacias', 'Aparatos', 'Flexibilidad'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Manchester United',
      hints: ['Inglés', 'Rojo', 'Trafford'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Surf',
      hints: ['Olas', 'Tabla', 'Playa'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Roger Federer',
      hints: ['Suizo', 'Elegante', 'Tenista'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Hockey',
      hints: ['Bastón', 'Hielo', 'Portería'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Muhammad Ali',
      hints: ['Mariposa', 'Campeón', 'Boxeo'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Esgrima',
      hints: ['Espada', 'Máscara', 'Duelo'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Erling Haaland',
      hints: ['Noruego', 'Goleador', 'Manchester'],
      category: WordCategory.deportes,
    ),
    const WordEntry(
      word: 'Maratón',
      hints: ['Resistencia', 'Kilómetros', 'Correr'],
      category: WordCategory.deportes,
    ),
  ];

  static List<WordEntry> getWordsByCategory(WordCategory category) {
    return _allWords.where((w) => w.category == category).toList();
  }

  static WordEntry getRandomWord(WordCategory category) {
    final words = getWordsByCategory(category);
    words.shuffle(_random);
    return words.first;
  }

  static String getRandomHint(WordEntry word) {
    final hints = List<String>.from(word.hints);
    hints.shuffle(_random);
    return hints.first;
  }
}
