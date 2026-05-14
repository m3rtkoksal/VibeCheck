import {setGlobalOptions} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import OpenAI, {APIError} from "openai";

setGlobalOptions({maxInstances: 10});

admin.initializeApp();

const openaiApiKey = defineSecret("OPENAI_API_KEY");

type ProfileSnapshotV1 = {
  v: number;
  selections: Record<string, string>;
  ts: number;
};

type AICompatibilityInsight = {
  percent: number;
  strengths: string[];
  frictions: string[];
  summary: string;
  forecasts?: ForecastItem[];
  icebreakers?: IcebreakerItem[];
};

type IcebreakerItem = {
  topic: string;
  prompt: string;
};

type ForecastItem = {
  id: "financial" | "stress" | "social";
  title: string;
  risk: "DİKKAT" | "ORTA RİSK" | "HAFİF";
  description: string;
  tip: string;
};

type AISelfProfileInsight = {
  summary: string;
  aboutYou?: string[];
  gentleReminders: string[];
  traitBreakdown?: Array<{
    id: string;
    title: string;
    percent: number; // 0-100
    description: string;
  }>;
};

type TraitBreakdownItem = {
  id: string;
  title: string;
  percent: number;
  description: string;
};

const ORDERED_PROFILE_LABELS: Array<{id: string; title: string}> = [
  {id: "messageTempo", title: "Partner mesajına geç dönme"},
  {id: "repairAfterConflict", title: "Küçük bir tartışma çıktı"},
  {id: "boundaryStyle", title: "Bir konuda kırıldın"},
  {id: "closenessNeed", title: "Yeni biriyle tanışıyorsun"},
  {
    id: "jealousyTrigger",
    title: "Partnerin karşı cins bir arkadaşıyla sık görüşüyor",
  },
];

/**
 * Canonical option strings — must mirror iOS ProfileCategory.swift (v1).
 */
const PROFILE_AXIS_OPTIONS_V1: Record<string, readonly string[]> = {
  messageTempo: [
    "Pek umursamam, müsait değildir diye düşünürüm",
    "Biraz merak ederim ama sorun etmem",
    "Neden geç kaldığını sorgularım",
  ],
  repairAfterConflict: [
    "Konuyu kapatıp uzaklaşırım",
    "Sakinleşince konuşur çözmeye çalışırım",
    "O an konuşup halletmek isterim",
  ],
  boundaryStyle: [
    "Çok takmam, geçer",
    "Uygun zamanda söylerim",
    "İçimde kalır, kolay geçmez",
  ],
  closenessNeed: [
    "Zamanla açılırım",
    "Dengeli ilerlerim",
    "Hızlı yakınlaşırım",
  ],
  jealousyTrigger: [
    "Doğal karşılarım",
    "Sınırlar önemli olur",
    "Rahatsızlık hissederim",
  ],
};

/**
 * Formats a profile snapshot into a stable, human-readable bullet list.
 *
 * @param {ProfileSnapshotV1} snapshot Profile snapshot payload (v1).
 * @return {string} Bullet list string.
 */
function prettySelections(snapshot: ProfileSnapshotV1): string {
  return ORDERED_PROFILE_LABELS.map(({id, title}) => {
    const value = snapshot.selections[id] ?? "—";
    return `- ${title}: ${value}`;
  }).join("\n");
}

/**
 * Per-axis score matching iOS `CompatibilityEngine.categoryScore`:
 * same option = 1.0, adjacent index = 0.6, farther = 0.2.
 *
 * @param {string} axisId PROFILE_AXIS_OPTIONS_V1 key.
 * @param {string} aRaw Answer A.
 * @param {string} bRaw Answer B.
 * @return {number | null} Unit score or null if missing.
 */
function axisCompatUnit(
  axisId: string,
  aRaw: string,
  bRaw: string
): number | null {
  const options = PROFILE_AXIS_OPTIONS_V1[axisId];
  if (!options?.length) return null;
  const a = (aRaw ?? "").trim();
  const b = (bRaw ?? "").trim();
  if (!a || !b) return null;
  const ai = options.indexOf(a);
  const bi = options.indexOf(b);
  // Legacy / unknown wording: degrade to coarse equality bump.
  if (ai === -1 || bi === -1) {
    if (a === b) return 0.92;
    return 0.32;
  }
  const distance = Math.abs(ai - bi);
  if (distance === 0) return 1;
  if (distance === 1) return 0.6;
  return 0.2;
}

/**
 * Deterministic overlap percent from five profile axes (avg unit * 100).
 *
 * @param {ProfileSnapshotV1} me Caller profile.
 * @param {ProfileSnapshotV1} partner Partner profile.
 * @return {number} Integer percent 0–100.
 */
function selectionOverlapPercent(
  me: ProfileSnapshotV1,
  partner: ProfileSnapshotV1
): number {
  const units: number[] = [];
  for (const {id} of ORDERED_PROFILE_LABELS) {
    const u = axisCompatUnit(
      id,
      me.selections[id] ?? "",
      partner.selections[id] ?? ""
    );
    if (u === null) continue;
    units.push(u);
  }
  if (units.length === 0) return 50;
  const avgUnit = units.reduce((sum, x) => sum + x, 0) / units.length;
  return clampPercent(Math.round(avgUnit * 100));
}

/**
 * Clamps numeric percent to 0-100 integer.
 *
 * @param {number} value Any numeric value.
 * @return {number} Integer in [0, 100].
 */
function clampPercent(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

/**
 * Builds fallback forecast cards when model omits them.
 *
 * @param {string[]} frictions Compatibility friction lines.
 * @return {ForecastItem[]} Three forecast cards.
 */
function fallbackForecasts(frictions: string[]): ForecastItem[] {
  const templates: Array<{
    id: ForecastItem["id"];
    title: string;
    risk: ForecastItem["risk"];
    tip: string;
  }> = [
    {
      id: "financial",
      title: "Finansal Yaklaşım",
      risk: "DİKKAT",
      tip: "Bütçe konuşmalarını ortak hedef diliyle yapın.",
    },
    {
      id: "stress",
      title: "Stres Yönetimi",
      risk: "ORTA RİSK",
      tip: "Tansiyon yükselince kısa mola ve sakin dönüş kuralı koyun.",
    },
    {
      id: "social",
      title: "Sosyal Enerji",
      risk: "HAFİF",
      tip: "Sosyal ve sakin zamanlar arasında denge kurun.",
    },
  ];

  return templates.map((t, idx) => ({
    id: t.id,
    title: t.title,
    risk: t.risk,
    description:
      frictions[idx] ??
      "Belirgin bir sürtüşme görünmüyor; açık iletişimle denge korunabilir.",
    tip: t.tip,
  }));
}

/**
 * Builds fallback conversation starters from compatibility output.
 *
 * @param {string[]} strengths Positive overlap lines.
 * @return {IcebreakerItem[]} Conversation starter cards.
 */
function fallbackIcebreakers(strengths: string[]): IcebreakerItem[] {
  const defaults: IcebreakerItem[] = [
    {
      topic: "Hafta Sonu Planları",
      prompt:
        "Birlikte keyif alacağımız bir hafta sonu planı sence ne olur?",
    },
    {
      topic: "Günlük Rutin",
      prompt:
        "Günün en keyif aldığın kısmı hangisi ve o anı özel yapan şey ne?",
    },
    {
      topic: "Müzik / Film",
      prompt:
        "Son dönemde seni gerçekten etkileyen bir şarkı veya film neydi?",
    },
    {
      topic: "Seyahat / Keşif",
      prompt:
        "Kısa bir kaçamak şansın olsa ilk hangi rotayı seçerdin?",
    },
  ];

  if (strengths.length === 0) return defaults;

  return defaults.map((item, idx) => {
    const s = strengths[idx % strengths.length];
    return {
      topic: item.topic,
      prompt: `${item.prompt} (İkinizde öne çıkan ortak alan: ${s})`,
    };
  });
}

/**
 * Calls OpenAI Responses API and returns the first JSON text payload.
 *
 * @param {object} args Arguments.
 * @param {string} args.apiKey OpenAI API key.
 * @param {string} args.system System prompt.
 * @param {string} args.user User prompt.
 * @return {Promise<string>} JSON string from the model.
 */
async function callOpenAIJson(args: {
  apiKey: string;
  system: string;
  user: string;
}): Promise<string> {
  const body = {
    model: "gpt-4o-mini",
    input: [
      {role: "system", content: args.system},
      {role: "user", content: args.user},
    ],
    text: {format: {type: "json_object"}},
    temperature: 0.4,
  };

  const resp = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${args.apiKey}`,
    },
    body: JSON.stringify(body),
  });

  const text = await resp.text();
  if (!resp.ok) {
    logger.error("OpenAI error", {status: resp.status, body: text});

    // Try to surface actionable errors to the client (without leaking secrets).
    try {
      const errJson = JSON.parse(text) as {
        error?: {code?: string; type?: string; message?: string};
      };
      const code = errJson.error?.code ?? "";
      const type = errJson.error?.type ?? "";

      if (
        resp.status === 429 &&
        (code === "insufficient_quota" || type === "insufficient_quota")
      ) {
        throw new HttpsError(
          "resource-exhausted",
          "OpenAI kotasi yetersiz; OpenAI hesabinda billing/limiti kontrol et."
        );
      }

      if (resp.status === 401) {
        throw new HttpsError(
          "failed-precondition",
          "OpenAI anahtarı geçersiz."
        );
      }
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      // ignore JSON parse failures and fall through
    }

    throw new HttpsError("internal", "OpenAI isteği başarısız");
  }

  const parsed = JSON.parse(text) as {
    output?: Array<{content?: Array<{type?: string; text?: string}>}>;
  };

  for (const item of parsed.output ?? []) {
    for (const c of item.content ?? []) {
      if (c.type === "output_text" && c.text) return c.text;
    }
  }

  throw new HttpsError("internal", "OpenAI response missing text");
}

type AIVoiceProfileInsight = {
  transcript: string;
  summary: string;
  signals: string[];
  energyPerspective: string;
  tonePerspective: string;
  pacingPerspective: string;
};

/** Ham ses üst boyutu (~1.5 MiB); iOS ile uyumlu. */
const MAX_VOICE_UPLOAD_BYTES = 1_572_864;

/**
 * Whisper yok — Chat Completions + ham ses WAV (gpt-4o-audio multimodal giriş).
 */
const VOICE_MULTIMODAL_MODEL = "gpt-4o-audio-preview";

/**
 * OpenAI multimodal WAV girdisi: RIFF/WAVE başlığı.
 *
 * input_audio bicimi yalnizca wav/mp3 dir; uygulama PCM WAV gornderir.
 *
 * @param {Buffer} buf Ham dosya.
 * @return {boolean} WAV ise true.
 */
function bufferLooksLikeWav(buf: Buffer): boolean {
  if (buf.length < 12) return false;
  const riff = buf.toString("ascii", 0, 4);
  const wave = buf.toString("ascii", 8, 12);
  return riff === "RIFF" && wave === "WAVE";
}

/**
 * Ses profili multimodal çağrılarında OpenAI hatalarını iletiye çevirir.
 *
 * @param {APIError} e SDK hatası — bu fonksiyon asla düzgün çıkış dönmez.
 */
function voiceProfileOpenAiVoiceError(e: APIError): never {
  logger.error("OpenAI voice multimodal error", {
    status: e.status,
    message: e.message,
    code: e.code,
  });
  if (e.status === 401) {
    throw new HttpsError(
      "failed-precondition",
      "OpenAI anahtarı geçersiz."
    );
  }
  if (
    e.status === 429 &&
    (e.code === "insufficient_quota" ||
      e.message.toLowerCase().includes("quota"))
  ) {
    throw new HttpsError(
      "resource-exhausted",
      "OpenAI kotasi yetersiz; OpenAI hesabinda billing/limiti kontrol et."
    );
  }
  const openAiMsg = e.message.trim();
  const fallback =
    "Ses işlenemedi; WAV ya da multimodal erişimi kontrol edin.";
  const detail =
    openAiMsg.length > 0 && openAiMsg.length < 280 ?
      `Ses işlenemedi (${openAiMsg})` :
      fallback;
  throw new HttpsError("invalid-argument", detail);
}

/**
 * Ham WAV ile duygu/atmosfer içgörüsü (tek model çağrısı).
 *
 * Kelime dizme / Whisper / transkripsiyon yapılmıyor; model sesten turar.
 *
 * @param {object} args Parametre.
 * @param {string} args.apiKey Anahtar.
 * @param {string} args.system Sistem iletisi.
 * @param {string} args.userText Kullanıcı metni (bağlam + şema kuralları).
 * @param {Buffer} args.wavBuffer Ham WAV içeriği.
 * @return {Promise<string>} JSON metin çıktısı.
 */
async function callVoiceCharacterFromAudio(args: {
  apiKey: string;
  system: string;
  userText: string;
  wavBuffer: Buffer;
}): Promise<string> {
  const client = new OpenAI({apiKey: args.apiKey});

  try {
    const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      {role: "system", content: args.system},
      {
        role: "user",
        content: [
          {type: "text", text: args.userText},
          {
            type: "input_audio",
            input_audio: {
              data: args.wavBuffer.toString("base64"),
              format: "wav",
            },
          },
        ],
      },
    ];

    const baseBody = {
      model: VOICE_MULTIMODAL_MODEL,
      modalities: ["text"] as Array<"text" | "audio">,
      messages,
      temperature: 0.35,
      max_completion_tokens: 1200,
    };

    let completion: OpenAI.Chat.Completions.ChatCompletion;
    try {
      completion = await client.chat.completions.create({
        ...baseBody,
        response_format: {type: "json_object"},
      });
    } catch (firstErr) {
      if (firstErr instanceof APIError &&
        Number(firstErr.status) === 400) {
        logger.warn("voice multimodal json_object uyusmadi yeniden deneniyor", {
          detail: firstErr.message,
        });
        completion =
          await client.chat.completions.create(baseBody);
      } else if (firstErr instanceof APIError) {
        voiceProfileOpenAiVoiceError(firstErr);
      } else if (firstErr instanceof HttpsError) {
        throw firstErr;
      } else {
        logger.error(
          "OpenAI voice ilk deneme beklenmedik",
          {err: String(firstErr)}
        );
        throw new HttpsError(
          "internal",
          "Ses analizi beklenmedik şekilde başarısız oldu."
        );
      }
    }

    const rawContent =
      completion.choices[0]?.message?.content?.trim() ?? "";
    if (!rawContent.length) {
      throw new HttpsError(
        "internal",
        "Model ses analizi için metin çıktısı döndürmedi."
      );
    }

    return rawContent;
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof APIError) voiceProfileOpenAiVoiceError(e);

    logger.error("OpenAI voice unexpected error", {err: String(e)});
    throw new HttpsError(
      "internal",
      "Ses analizi beklenmedik şekilde başarısız oldu."
    );
  }
}

/**
 * Callable function: analyzes compatibility between two profile snapshots.
 */
export const analyzeCompatibility = onCall(
  {
    region: "europe-west1",
    secrets: [openaiApiKey],
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    const data = request.data as {
      me?: ProfileSnapshotV1;
      partner?: ProfileSnapshotV1;
      privateNote?: string;
    };

    const me = data.me;
    const partner = data.partner;
    if (!me || !partner) {
      throw new HttpsError("invalid-argument", "me ve partner zorunlu");
    }
    if (me.v !== 1 || partner.v !== 1) {
      throw new HttpsError(
        "invalid-argument",
        "Desteklenmeyen snapshot versiyonu"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OPENAI_API_KEY yok"
      );
    }

    const privateNote = (data.privateNote ?? "").trim();
    const hasPrivateNote = privateNote.length > 0;

    const systemParts = [
      "Sen bir ilişki uyumu analisti yardımcısısın.",
      "Yargılayıcı değil, kısa ve faydalı konuş.",
      "Çıktı kesin hüküm değil, eğilim analizi olsun.",
      "Türkçe yanıt ver.",
    ];
    if (hasPrivateNote) {
      systemParts.push(
        "Özel not yazıldığında: percent, strengths ve frictions bu notu " +
          "doğrudan ve belirgin yansıtmalıdır; not yok sayılamaz."
      );
    }
    const system = systemParts.join(" ");

    const privateNoteBlock =
      hasPrivateNote ?
        [
          "",
          "",
          "Benim özel notum (kimsenin görmediği, sadece benim için — " +
            "uyum yüzdesi ve maddeler bu bağlamı dikkate almalıdır):",
          privateNote,
          "",
        ].join("\n") :
        "";

    const user = [
      "İki profilin 5 sorudaki seçimleri aşağıda.",
      "",
      "Ben:",
      prettySelections(me),
      "",
      "Karşı taraf:",
      prettySelections(partner),
      privateNoteBlock,
      "",
      "JSON formatında yanıtla:",
      "{",
      "  \"percent\": 0-100,",
      "  \"strengths\": [\"...\"],",
      "  \"frictions\": [\"...\"],",
      "  \"summary\": \"2-3 cümle kısa özet\",",
      "  \"forecasts\": [",
      [
        "    {\"id\":\"financial\",\"title\":\"Finansal Yaklaşım\",",
        "\"risk\":\"DİKKAT\",\"description\":\"...\",\"tip\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"stress\",\"title\":\"Stres Yönetimi\",",
        "\"risk\":\"ORTA RİSK\",\"description\":\"...\",\"tip\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"social\",\"title\":\"Sosyal Enerji\",",
        "\"risk\":\"HAFİF\",\"description\":\"...\",\"tip\":\"...\"}",
      ].join(""),
      "  ]",
      "  \"icebreakers\": [",
      "    {\"topic\":\"...\",\"prompt\":\"...\"},",
      "    {\"topic\":\"...\",\"prompt\":\"...\"},",
      "    {\"topic\":\"...\",\"prompt\":\"...\"},",
      "    {\"topic\":\"...\",\"prompt\":\"...\"}",
      "  ]",
      "}",
      "",
      "Kurallar:",
      "- strengths ve frictions maddeleri kısa olsun (maks 6 madde).",
      "- summary yumuşak dille yazılsın, kesin teşhis/itham yok.",
      "- forecasts her zaman 3 eleman olsun: financial, stress, social.",
      "- risk sadece DİKKAT / ORTA RİSK / HAFİF olsun.",
      "- tip alanı somut, tek cümle iletişim önerisi olsun.",
      "- icebreakers alanı 4 eleman olsun.",
      [
        "- icebreakers: topic kısa başlık olsun;",
        " prompt doğrudan sorulabilir tek soru olsun.",
      ].join(""),
      "- Soru tonu doğal, tanışma aşamasına uygun ve yargısız olsun.",
      [
        "- private note varsa, sadece 'ben' tarafının içgörüsü olarak kullan;",
        " karşı taraf hakkında iddia üretme.",
      ].join(""),
      ...(hasPrivateNote ?
        [
          [
            "- ÖZEL NOT: percent yalnızca 5 sorunun 'otomatik çıkarımı' gibi ",
            "davranmasın;",
            " bu nottaki duygu, beklenen dinamik veya risk/olumluluk yüzdeyi ",
            "anlamlı şekilde yukarı VEYA aşağı çeksin;",
            " anket seçimleriyle çelişen bir not varsa yüzde ve sürtüşmeler ",
            "bunu yansıtsın.",
          ].join(""),
          [
            "- ÖZEL NOT: en az bir strength veya friction maddesi nottaki ",
            "somut bir nüansı doğrudan ifade etsin;",
            " summary notu özetlesin.",
          ].join(""),
        ] :
        []),
      [
        "- percent: farklı profil kombinasyonlarında skor yayılımı ",
        "geniş olsun;",
        " yakın seçimleri sürekli tek bir yüzdede sıkıştırma;",
        " (özellikle 68–77 arasında sık küme olarak).",
      ].join(""),
      [
        "- Seçimler neredeyse veya tamamen örtüşüyorsa, sürtüşme az ise ",
        "percent için 95–100 bandını yasaklama;",
        " çok güçlü paralellikte tam 100 de verilebilir ",
        "(abartı gerektirmeden).",
      ].join(""),
      "- percent seçimlerdeki paralellik / gerilimi yansıtsın;",
      "- strengths veya frictions daha çok ise percent bununla uyumlu olsun.",
    ].join("\n");

    const jsonText = await callOpenAIJson({apiKey, system, user});

    let insight: AICompatibilityInsight;
    try {
      insight = JSON.parse(jsonText) as AICompatibilityInsight;
    } catch (e) {
      logger.error("Failed to parse model JSON", {jsonText, e});
      throw new HttpsError("internal", "Model JSON parse failed");
    }

    if (
      typeof insight.percent !== "number" ||
      !Array.isArray(insight.strengths) ||
      !Array.isArray(insight.frictions) ||
      typeof insight.summary !== "string"
    ) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    if (!Array.isArray(insight.forecasts) || insight.forecasts.length !== 3) {
      insight.forecasts = fallbackForecasts(insight.frictions);
    }
    if (!Array.isArray(insight.icebreakers) || insight.icebreakers.length < 3) {
      insight.icebreakers = fallbackIcebreakers(insight.strengths);
    }

    // Özel not yoksa: seçimler biraz daha ağırlıklı (deterministik).
    // Not varken: model çıktısı kullanıcı bağlamını yansıtır;
    // daha yüksek ağırlık verilir.
    const overlapPercent = selectionOverlapPercent(me, partner);
    const modelPercent = clampPercent(insight.percent);
    const modelWeight =
      privateNote.length === 0 ? 0.48 :
        privateNote.length < 140 ? 0.62 :
          0.72;
    const overlapWeight = 1 - modelWeight;
    let blendedPercent = clampPercent(
      modelPercent * modelWeight + overlapPercent * overlapWeight
    );
    const strengthsCount = insight.strengths.length;
    const frictionsCount = insight.frictions.length;
    // Seçimlerde 99%+ deterministik örtüşme varsa skor seçim uyumunun
    // altına inmesin (model muhafazakar kalınca %100’a çıkamama).
    const frictionDominates =
      frictionsCount >= strengthsCount + 3 ||
      (hasPrivateNote && frictionsCount > strengthsCount + 1);
    if (overlapPercent >= 99 && !frictionDominates) {
      blendedPercent = Math.max(blendedPercent, overlapPercent);
    }

    let finalPercent = Math.round(blendedPercent);
    // Light narrative nudge ±4 from strength vs friction counts.
    const deltaSf = strengthsCount - frictionsCount;
    const narrativeNudge =
      deltaSf >= 4 ? 4 :
        deltaSf <= -4 ? -4 :
          0;
    finalPercent = clampPercent(finalPercent + narrativeNudge);

    insight.percent = finalPercent;

    logger.info("Compatibility score blended", {
      uid: request.auth.uid,
      modelPercent,
      modelWeight,
      overlapWeight,
      blendedPercent: Math.round(blendedPercent),
      narrativeNudge,
      finalPercent: insight.percent,
      strengthsCount,
      frictionsCount,
      overlapPercent,
      privateNoteChars: privateNote.length,
      hasPrivateNote,
    });

    return insight;
  }
);

/**
 * Callable: single-user profile readback from 10 “subtle” questions.
 */
export const analyzeSelfProfile = onCall(
  {
    region: "europe-west1",
    secrets: [openaiApiKey],
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    const data = request.data as {
      me?: ProfileSnapshotV1;
      privateNote?: string;
    };

    const me = data.me;
    if (!me) {
      throw new HttpsError("invalid-argument", "me zorunlu");
    }
    if (me.v !== 1) {
      throw new HttpsError(
        "invalid-argument",
        "Desteklenmeyen snapshot versiyonu"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OPENAI_API_KEY yok"
      );
    }

    const system = [
      "Sen kısa ve nazik bir ilişki-kişilik özet asistanısın.",
      "Girdi 5 maddelik kısa ankete dayanır; kesin tanı veya etiket yok.",
      "Türkçe, yargısız, destekleyici yaz.",
      "Çıktıda küçümseyici veya aşağılayıcı dil kullanma.",
    ].join(" ");

    const privateNote = (data.privateNote ?? "").trim();
    const privateNoteBlock =
      privateNote.length > 0 ?
        [
          "",
          "Kullanıcının özel notu (sadece kullanıcıya özel):",
          privateNote,
          "",
        ].join("\n") :
        "";

    const user = [
      "Aşağıda kullanıcının 5 soruya verdiği seçimler var.",
      "",
      prettySelections(me),
      privateNoteBlock,
      "",
      "Bu seçimlere dayanarak kullanıcıya özel tek bir güçlü anlatım üret.",
      "",
      "JSON formatında yanıtla:",
      "{",
      [
        "  \"summary\":",
        "\"Türkçe tek sürekli anlatım: seçimleri yansıtan özet;",
        " ilişkiye yaklaşım, iletişim, sınırlar, yakınlık ihtiyacı gibi",
        " temaları",
        " ayrı bölüm YAZMADAN bu metinde doğal tek akışta veya ",
        "kısa maddeler içinde;",
        " 5–12 cümle; yargılayıcı olma.\",",
      ].join(""),
      "  \"aboutYou\": [],",
      "  \"gentleReminders\": [\"en fazla 3 madde\"],",
      "  \"traitBreakdown\": [",
      [
        "    {\"id\":\"introversion\",\"title\":\"INTROVERSION\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"creativity\",\"title\":\"CREATIVITY\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"logic\",\"title\":\"LOGIC\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"empathy\",\"title\":\"EMPATHY\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"ambition\",\"title\":\"AMBITION\",",
        "\"percent\":0,\"description\":\"...\"}",
      ].join(""),
      "  ]",
      "}",
      "",
      "Kurallar:",
      "- aboutYou hep boş dizi (eski uyumluluk alanıdır).",
      "- Tekrarlayan ikinci blok YOK:",
      " ilişkiye dair ne söylenecekse hep summary içinde olsun.",
      "- gentleReminders isteğe bağlı; fazlaysa kısalt.",
      [
        "- traitBreakdown her zaman 5 eleman içersin",
        " (introversion, creativity, logic, empathy, ambition).",
      ].join(""),
      [
        "- percent 0-100 arası olsun; yuvarla;",
        " çok uç değerlerden kaçın (genelde 25-95 aralığı).",
      ].join(""),
      "- description 1-2 kısa cümle olsun.",
      "- Kesin kişilik etiketi kullanma (ör. narcist).",
      [
        "- Özel not varsa yalnızca kullanıcıyla ilişkili iç görü olarak",
        " kullan; üçüncü şahıs hakkında varsayım yapma.",
      ].join(""),
    ].join("\n");

    const jsonText = await callOpenAIJson({apiKey, system, user});

    let insight: AISelfProfileInsight;
    try {
      insight = JSON.parse(jsonText) as AISelfProfileInsight;
    } catch (e) {
      logger.error("Failed to parse model JSON", {jsonText, e});
      throw new HttpsError("internal", "Model JSON parse failed");
    }

    if (
      typeof insight.summary !== "string" ||
      !Array.isArray(insight.gentleReminders)
    ) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    const aboutYou = insight.aboutYou;
    if (
      aboutYou !== undefined &&
      !aboutYou.every((x: unknown) => typeof x === "string")
    ) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    const maybeTraitBreakdown = insight.traitBreakdown;
    if (Array.isArray(maybeTraitBreakdown)) {
      const tb = maybeTraitBreakdown as TraitBreakdownItem[];
      if (tb.length !== 5) {
        throw new HttpsError("internal", "Model JSON traitBreakdown invalid");
      }
      for (const t of tb) {
        if (
          typeof t?.id !== "string" ||
          typeof t?.title !== "string" ||
          typeof t?.percent !== "number" ||
          typeof t?.description !== "string"
        ) {
          throw new HttpsError("internal", "Model JSON traitBreakdown invalid");
        }
      }
    }

    return {
      summary: insight.summary,
      aboutYou: insight.aboutYou ?? [],
      gentleReminders: insight.gentleReminders,
      traitBreakdown: insight.traitBreakdown,
    };
  }
);

/**
 * Callable: WAV kaydı + çok kanallı modelden nazik ses-atmosfer içgörüsü.
 */

export const analyzeVoiceProfile = onCall(
  {
    region: "europe-west1",
    secrets: [openaiApiKey],
    enforceAppCheck: false,
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    const data = request.data as {
      audioBase64?: string;
      readingPrompt?: string;
    };

    const b64 = (data.audioBase64 ?? "").trim();
    if (!b64.length) {
      throw new HttpsError("invalid-argument", "audioBase64 zorunlu");
    }

    let buf: Buffer;
    try {
      buf = Buffer.from(b64, "base64");
    } catch (_e) {
      throw new HttpsError("invalid-argument", "Geçersiz base64");
    }
    if (buf.byteLength === 0) {
      throw new HttpsError("invalid-argument", "Boş ses verisi");
    }
    if (buf.byteLength > MAX_VOICE_UPLOAD_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "Ses kaydı çok büyük; daha kısa kayıt veya sıkıştırma dene."
      );
    }

    if (!bufferLooksLikeWav(buf)) {
      throw new HttpsError(
        "invalid-argument",
        [
          "Ses dosyası PCM WAV bekleniyor; uygulamayı güncelleyip ",
          "yeniden kayıt yap.",
        ].join("")
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OPENAI_API_KEY yok"
      );
    }

    const readingPrompt = (data.readingPrompt ?? "").trim().slice(0, 4000);

    const system = [
      "Ses kaydından doğrudan hareketle nazik iletişim hissiyatı özeti ver.",
      "Sıcaklık mesafe hissini, gevşemiş veya gergin yönleri ve ",
      "ritim durak hissini süz;",
      "yaklaşık duygu yönüdür kesin yüzölçüm bilimi iddia etme.",
      "Kelimesi kelimesine yazılı döküm üretme;",
      "`transcript` hep boş kalsın, model yazsa bile sunucu sıfırlayacaktır.",
      "Türkçe, destekleyici, yargısız ol.",
      "Kesin hastalık teşhisi veya zehirli kişilik damgası kullanma.",
    ].join(" ");

    const readingBlock =
      readingPrompt.length > 0 ?
        [
          "",
          "Kayıtta kullanıcı aşağı kalıpla okumuş olabilir;",
          "yalnızca bağlam fikri ver:",
          "",
          readingPrompt,
          "",
        ].join("\n") :
        "";

    const userText = [
      "Hareket noktan dalga içeriği; metin çıkartan Whisper gibi araç yok.",
      readingBlock.trim(),
      "",
      "Özgün olarak duyuran cümleleri tam metne çevirme.",
      "Tek JSON nesnesi döndür. Alanlar:",
      "- transcript hep bos string olarak",
      "- summary",
      "- signals",
      "- energyPerspective",
      "- tonePerspective",
      "- pacingPerspective",
      "",
      "Şema şablon:",
      "{",
      "  \"transcript\": \"\",",
      [
        "  \"summary\":\"Türkçe 2–3 cümle: duygusal/atmosferik ",
        "iletişim özeti\",",
      ].join(""),
      "  \"signals\": [\"madde 1\", \"madde 2\", \"madde 3\",",
      "\"madde 4\"],",
      [
        "  \"energyPerspective\":\"Türkçe 1–2 cümle: ritim ve enerji hissine ",
        "dair yumuşak gözlem\",",
      ].join(""),

      [
        "  \"tonePerspective\":\"Türkçe 1–2 cümle: sıcaklık ile ",
        "mesafe hissine ilişkin yumuşak gözlem\",",
      ].join(""),

      [
        "  \"pacingPerspective\":\"Türkçe 1–2 cümle: ritim;",
        " durak hissine ilişkin bir gözlem\"",
      ].join(""),

      "}",
      "",
      "signals 3 ile 8 arası tekilleştir;",
      "yargılayıcı konuşma; destek üslubu.",
    ].join("\n");

    const jsonText = await callVoiceCharacterFromAudio({
      apiKey,
      system,
      userText,
      wavBuffer: buf,
    });

    interface VoiceModelJsonShape {
      summary?: unknown;
      signals?: unknown;
      energyPerspective?: unknown;
      tonePerspective?: unknown;
      pacingPerspective?: unknown;
    }

    let parsed: VoiceModelJsonShape;
    try {
      parsed = JSON.parse(jsonText) as VoiceModelJsonShape;
    } catch (e) {
      logger.error("voice profile JSON parse failed", {jsonText, e});
      throw new HttpsError("internal", "Model JSON parse failed");
    }

    const summaryOk =
      typeof parsed.summary === "string" ?
        parsed.summary.trim() :
        "";

    let signalsArr: string[] = [];
    const rawSignals = parsed.signals;
    if (Array.isArray(rawSignals)) {
      signalsArr = rawSignals
        .filter(
          (s: unknown): s is string =>
            typeof s === "string" && s.trim().length > 0
        )
        .map((x: string) => x.trim())
        .slice(0, 12);
    }
    const ep =
      typeof parsed.energyPerspective === "string" ?
        parsed.energyPerspective.trim() :
        "";
    const tp =
      typeof parsed.tonePerspective === "string" ?
        parsed.tonePerspective.trim() :
        "";
    const pp =
      typeof parsed.pacingPerspective === "string" ?
        parsed.pacingPerspective.trim() :
        "";

    if (
      !summaryOk.length ||
      !ep.length ||
      !tp.length ||
      !pp.length
    ) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    if (signalsArr.length === 0) {
      signalsArr = ["İç görü oluşturmak için yeterince sinyal üretilemedi."];
    }
    if (signalsArr.length > 8) {
      signalsArr = signalsArr.slice(0, 8);
    }

    const out: AIVoiceProfileInsight = {
      transcript: "",
      summary: summaryOk,
      signals: signalsArr,
      energyPerspective: ep,
      tonePerspective: tp,
      pacingPerspective: pp,
    };

    logger.info("Voice profile analyzed", {
      uid: request.auth.uid,
      bytesIn: buf.byteLength,
    });

    return out;
  }
);

/**
 * Uyum puanı oluşunca hedef kullanıcıya push (FCM token gerekir).
 */
export const notifyTargetOnCompatibilityRating = onDocumentCreated(
  {
    document: "compatibilityRatings/{ratingId}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }
    const data = snap.data();
    const targetUID = data?.targetUID as string | undefined;
    const raterUID = data?.raterUID as string | undefined;
    if (!targetUID || !raterUID || targetUID === raterUID) {
      return;
    }

    const nameRaw = data?.raterPublicName;
    const name =
      typeof nameRaw === "string" && nameRaw.trim().length > 0 ?
        nameRaw.trim() :
        "Birisi";

    const tokenSnap = await admin
      .firestore()
      .doc(`userPushTokens/${targetUID}`)
      .get();
    const token = tokenSnap.get("token") as string | undefined;
    if (!token) {
      logger.info("compat rating notify: target has no FCM token", {targetUID});
      return;
    }

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: "VibeCheck",
          body: `${name} seni puanladı — sen de onu puanla.`,
        },
        data: {
          type: "compatibility_rating",
          ratingDocId: snap.id,
          pairKey: typeof data?.pairKey === "string" ? data.pairKey : "",
          raterUID,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
    } catch (e) {
      logger.error("compat rating notify FCM error", {e, targetUID});
    }
  }
);
