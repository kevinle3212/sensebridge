import Foundation

/// Article-first noun phrases for the classifier identifiers this app is most
/// likely to speak, in each language it ships.
///
/// ## Why a curated table and not a translator
///
/// Vision ships ~1,300 identifiers and Sound Analysis ~300. Machine-translating
/// that vocabulary would produce a confidently wrong noun for the long tail,
/// and `docs/SAFETY-FRAMING.md` ranks mis-naming a physical object above a
/// crash: a user who hears the wrong object named has been given a false claim
/// about the room they are standing in. So this table is small, hand-written,
/// and covers only identifiers a walk through a home or a street actually
/// produces. Anything not listed falls back to the English phrase inside the
/// translated hedge — the behaviour that shipped before this table existed.
///
/// ## Why whole phrases and not article + noun
///
/// The entries are complete subjects, not stems. Spanish agrees the article
/// with gender (`una silla`, `un vaso`) and Vietnamese selects a classifier by
/// the kind of thing being counted (`cái` for most objects, `con` for animals,
/// `chiếc` for vehicles, `quyển` for books). Neither is derivable from an
/// English identifier, so composing one at runtime would be the same guess this
/// table exists to avoid.
///
/// ## Review status
///
/// **Seeded, not yet native-speaker reviewed.** The mechanism and the fallback
/// are complete and tested; the wording is pending the `es`/`vi` native-speaker
/// review already tracked on the repo's to-do list. A reviewer changing an entry
/// changes only that entry — nothing here is derived from anything else.
enum SpokenVocabulary {
    /// Normalized identifier (underscores as spaces, lowercased) → language
    /// code → the article-first phrase to speak.
    ///
    /// Keyed by language code alone rather than a full locale: a regional
    /// variant that needs different wording gets its own key here (`es_MX`),
    /// and `SpokenPhrase` already tries the most specific candidate first.
    static let phrases: [String: [String: String]] = [
        // MARK: Furniture and household objects

        "chair": ["es": "una silla", "vi": "một cái ghế"],
        "bench": ["es": "un banco", "vi": "một cái ghế băng"],
        "table": ["es": "una mesa", "vi": "một cái bàn"],
        "desk": ["es": "un escritorio", "vi": "một cái bàn làm việc"],
        "door": ["es": "una puerta", "vi": "một cái cửa"],
        "window": ["es": "una ventana", "vi": "một cái cửa sổ"],
        "bed": ["es": "una cama", "vi": "một cái giường"],
        "pillow": ["es": "una almohada", "vi": "một cái gối"],
        "sofa": ["es": "un sofá", "vi": "một cái ghế sofa"],
        "couch": ["es": "un sofá", "vi": "một cái ghế sofa"],
        "lamp": ["es": "una lámpara", "vi": "một cái đèn"],
        "shelf": ["es": "un estante", "vi": "một cái kệ"],
        "bookcase": ["es": "una estantería", "vi": "một cái tủ sách"],
        "mirror": ["es": "un espejo", "vi": "một cái gương"],
        "curtain": ["es": "una cortina", "vi": "một tấm rèm"],
        "carpet": ["es": "una alfombra", "vi": "một tấm thảm"],
        "rug": ["es": "una alfombra", "vi": "một tấm thảm"],
        "trash can": ["es": "un cubo de basura", "vi": "một cái thùng rác"],

        // MARK: Structure and the built environment

        "stairs": ["es": "unas escaleras", "vi": "cầu thang"],
        "staircase": ["es": "una escalera", "vi": "cầu thang"],
        "escalator": ["es": "una escalera mecánica", "vi": "thang cuốn"],
        "elevator": ["es": "un ascensor", "vi": "thang máy"],
        "ramp": ["es": "una rampa", "vi": "một cái dốc"],
        "railing": ["es": "una barandilla", "vi": "một cái lan can"],
        "fence": ["es": "una valla", "vi": "một hàng rào"],
        "gate": ["es": "una verja", "vi": "một cái cổng"],
        "wall": ["es": "una pared", "vi": "một bức tường"],
        "sidewalk": ["es": "una acera", "vi": "một vỉa hè"],
        "crosswalk": ["es": "un paso de peatones", "vi": "một vạch qua đường"],
        "traffic light": ["es": "un semáforo", "vi": "một cái đèn giao thông"],

        // MARK: People and animals

        "person": ["es": "una persona", "vi": "một người"],
        "dog": ["es": "un perro", "vi": "một con chó"],
        "cat": ["es": "un gato", "vi": "một con mèo"],
        "bird": ["es": "un pájaro", "vi": "một con chim"],

        // MARK: Vehicles

        "car": ["es": "un coche", "vi": "một chiếc xe hơi"],
        "bicycle": ["es": "una bicicleta", "vi": "một chiếc xe đạp"],
        "motorcycle": ["es": "una motocicleta", "vi": "một chiếc xe máy"],
        "bus": ["es": "un autobús", "vi": "một chiếc xe buýt"],
        "truck": ["es": "un camión", "vi": "một chiếc xe tải"],

        // MARK: Kitchen and bathroom

        "cup": ["es": "una taza", "vi": "một cái cốc"],
        "mug": ["es": "una taza", "vi": "một cái cốc"],
        "coffee mug": ["es": "una taza de café", "vi": "một cái cốc cà phê"],
        "bottle": ["es": "una botella", "vi": "một cái chai"],
        "water bottle": ["es": "una botella de agua", "vi": "một chai nước"],
        "glass": ["es": "un vaso", "vi": "một cái ly"],
        "plate": ["es": "un plato", "vi": "một cái đĩa"],
        "bowl": ["es": "un cuenco", "vi": "một cái bát"],
        "spoon": ["es": "una cuchara", "vi": "một cái thìa"],
        "fork": ["es": "un tenedor", "vi": "một cái nĩa"],
        "knife": ["es": "un cuchillo", "vi": "một con dao"],
        "refrigerator": ["es": "un refrigerador", "vi": "một cái tủ lạnh"],
        "oven": ["es": "un horno", "vi": "một cái lò nướng"],
        "microwave": ["es": "un microondas", "vi": "một cái lò vi sóng"],
        "sink": ["es": "un fregadero", "vi": "một cái bồn rửa"],
        "toilet": ["es": "un inodoro", "vi": "một cái bồn cầu"],
        "towel": ["es": "una toalla", "vi": "một cái khăn"],

        // MARK: Electronics

        "television": ["es": "un televisor", "vi": "một cái tivi"],
        "laptop": ["es": "un ordenador portátil", "vi": "một cái máy tính xách tay"],
        "keyboard": ["es": "un teclado", "vi": "một cái bàn phím"],
        "computer keyboard": ["es": "un teclado", "vi": "một cái bàn phím"],
        "computer mouse": ["es": "un ratón", "vi": "một con chuột máy tính"],
        "cell phone": ["es": "un teléfono móvil", "vi": "một cái điện thoại di động"],
        "telephone": ["es": "un teléfono", "vi": "một cái điện thoại"],
        "remote control": ["es": "un mando a distancia", "vi": "một cái điều khiển từ xa"],
        "monitor": ["es": "un monitor", "vi": "một cái màn hình"],
        "printer": ["es": "una impresora", "vi": "một cái máy in"],
        "clock": ["es": "un reloj", "vi": "một cái đồng hồ"],

        // MARK: Carried objects

        "book": ["es": "un libro", "vi": "một quyển sách"],
        "backpack": ["es": "una mochila", "vi": "một cái ba lô"],
        "handbag": ["es": "un bolso", "vi": "một cái túi xách"],
        "suitcase": ["es": "una maleta", "vi": "một cái vali"],
        "umbrella": ["es": "un paraguas", "vi": "một cái ô"],
        "shoe": ["es": "un zapato", "vi": "một chiếc giày"],
        "wallet": ["es": "una cartera", "vi": "một cái ví"],
        "key": ["es": "una llave", "vi": "một chiếc chìa khóa"],

        // MARK: Outdoors

        "tree": ["es": "un árbol", "vi": "một cái cây"],
        "flower": ["es": "una flor", "vi": "một bông hoa"],
        "plant": ["es": "una planta", "vi": "một cái cây cảnh"],

        // MARK: Sound Analysis classes

        //
        // The whole shipped set from `BuiltInSoundClassifier.targetClassNames`,
        // deliberately complete rather than sampled: several are
        // safety-adjacent, and a Spanish or Vietnamese speaker meeting "a fire
        // alarm" in English is the one case where the language gap costs the
        // most.
        "fire alarm": ["es": "una alarma de incendios", "vi": "một chuông báo cháy"],
        "smoke detector": ["es": "un detector de humo", "vi": "một máy báo khói"],
        "doorbell": ["es": "un timbre", "vi": "một chuông cửa"],
        "knock": ["es": "un golpe en la puerta", "vi": "một tiếng gõ cửa"],
        "dog bark": ["es": "un ladrido de perro", "vi": "một tiếng chó sủa"],
        "baby cry": ["es": "un llanto de bebé", "vi": "một tiếng trẻ khóc"],
        "car horn": ["es": "un claxon", "vi": "một tiếng còi xe"],
        "siren": ["es": "una sirena", "vi": "một tiếng còi hú"],
        "glass shatter": ["es": "un cristal roto", "vi": "một tiếng kính vỡ"],
        "telephone bell ringing": ["es": "un teléfono sonando", "vi": "một tiếng chuông điện thoại"]
    ]
}
