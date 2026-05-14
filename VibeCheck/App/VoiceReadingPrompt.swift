import Foundation

/// Sheet’te mikrofon öncesi okunan metin; `analyzeVoiceProfile` çağrısına `readingPrompt` olarak da gider.
enum VoiceReadingPrompt {
    /// Kısaltılmış uyarı — küçük sheet yüksekliğinde de sığsın (~yarı süre okuma).
    static let paragraph =
        "Bu kayıt, o an için yumuşak bir iletişim ‘havası’ yansımasıdır — "
        + "sıfat ya da sabit kişilik etiketi sayılmaz. Merakına pencere gibi kullan;"
        + " kimliğinle özdeş görmek zorunda değilsin."
}
